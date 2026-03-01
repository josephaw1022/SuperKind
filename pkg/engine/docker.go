package engine

import (
	"context"
	"fmt"
	"io"
	"os"

	"github.com/docker/docker/api/types"
	"github.com/docker/docker/api/types/container"
	"github.com/docker/docker/client"
	"github.com/docker/go-connections/nat"
)

type DockerConfig struct {
	LocalRegistryName      string
	LocalRegistryHostPort  string
	DockerHubCacheName     string
	QuayCacheName          string
	GHCRCacheName          string
	MCRCacheName           string
}

func EnsureLocalRegistry(cfg DockerConfig) error {
	ctx := context.Background()
	cli, err := client.NewClientWithOpts(client.FromEnv, client.WithAPIVersionNegotiation())
	if err != nil {
		return fmt.Errorf("failed to create docker client: %w", err)
	}
	defer cli.Close()

	if isContainerRunning(ctx, cli, cfg.LocalRegistryName) {
		fmt.Printf("🗄️  local Zot registry already running.\\n")
		return nil
	}

	fmt.Printf("🗄️  creating local Zot registry (push/pull + ORAS) on localhost:%s...\\n", cfg.LocalRegistryHostPort)

	imageName := "ghcr.io/project-zot/zot-linux-amd64:latest"
	if _, _, err := cli.ImageInspectWithRaw(ctx, imageName); err != nil {
		fmt.Printf("📥 pulling image %s...\\n", imageName)
		out, err := cli.ImagePull(ctx, imageName, types.ImagePullOptions{})
		if err != nil {
			return fmt.Errorf("failed to pull Zot image: %w", err)
		}
		defer out.Close()
		io.Copy(os.Stdout, out)
	}

	portMap := nat.PortMap{
		"5000/tcp": []nat.PortBinding{
			{HostIP: "0.0.0.0", HostPort: cfg.LocalRegistryHostPort},
		},
	}

	resp, err := cli.ContainerCreate(ctx, &container.Config{
		Image: imageName,
		ExposedPorts: nat.PortSet{
			"5000/tcp": struct{}{},
		},
	}, &container.HostConfig{
		RestartPolicy: container.RestartPolicy{Name: "always"},
		PortBindings:  portMap,
	}, nil, nil, cfg.LocalRegistryName)
	if err != nil {
		return fmt.Errorf("failed to create Zot registry container: %w", err)
	}

	if err := cli.ContainerStart(ctx, resp.ID, types.ContainerStartOptions{}); err != nil {
		return fmt.Errorf("failed to start Zot registry container: %w", err)
	}

	fmt.Printf("✅ Zot registry started as '%s' (localhost:%s)\\n", cfg.LocalRegistryName, cfg.LocalRegistryHostPort)
	return nil
}

func EnsurePullThroughCaches(cfg DockerConfig) error {
	ctx := context.Background()
	cli, err := client.NewClientWithOpts(client.FromEnv, client.WithAPIVersionNegotiation())
	if err != nil {
		return fmt.Errorf("failed to create docker client: %w", err)
	}
	defer cli.Close()

	if !networkExists(ctx, cli, "kind") {
		fmt.Println("🌐 creating docker network 'kind'...")
		_, err := cli.NetworkCreate(ctx, "kind", types.NetworkCreate{
			Driver: "bridge",
		})
		if err != nil {
			return fmt.Errorf("failed to create kind network: %w", err)
		}
	}

	caches := []struct {
		name      string
		remoteURL string
		hostPort  string
	}{
		{cfg.DockerHubCacheName, "https://registry-1.docker.io", "5000"},
		{cfg.QuayCacheName, "https://quay.io", ""},
		{cfg.GHCRCacheName, "https://ghcr.io", ""},
		{cfg.MCRCacheName, "https://mcr.microsoft.com", ""},
	}

	imageName := "registry:2"
	if _, _, err := cli.ImageInspectWithRaw(ctx, imageName); err != nil {
		fmt.Printf("📥 pulling image %s...\\n", imageName)
		out, err := cli.ImagePull(ctx, imageName, types.ImagePullOptions{})
		if err != nil {
			return fmt.Errorf("failed to pull registry image: %w", err)
		}
		defer out.Close()
		io.Copy(os.Stdout, out)
	}

	for _, c := range caches {
		if isContainerRunning(ctx, cli, c.name) {
			fmt.Printf("📦 %s already running.\\n", c.name)
			continue
		}

		fmt.Printf("📦 creating %s pull-through cache...\\n", c.name)
		
		var portBindings nat.PortMap
		if c.hostPort != "" {
			portBindings = nat.PortMap{
				"5000/tcp": []nat.PortBinding{
					{HostIP: "0.0.0.0", HostPort: c.hostPort},
				},
			}
		}

		resp, err := cli.ContainerCreate(ctx, &container.Config{
			Image: imageName,
			Env: []string{
				fmt.Sprintf("REGISTRY_PROXY_REMOTEURL=%s", c.remoteURL),
			},
		}, &container.HostConfig{
			RestartPolicy: container.RestartPolicy{Name: "always"},
			PortBindings:  portBindings,
			NetworkMode:   "kind",
		}, nil, nil, c.name)
		if err != nil {
			return fmt.Errorf("failed to create cache %s: %w", c.name, err)
		}

		if err := cli.ContainerStart(ctx, resp.ID, types.ContainerStartOptions{}); err != nil {
			return fmt.Errorf("failed to start cache %s: %w", c.name, err)
		}
		fmt.Printf("✅ %s created.\\n", c.name)
	}

	return nil
}

func isContainerRunning(ctx context.Context, cli *client.Client, name string) bool {
	inspect, err := cli.ContainerInspect(ctx, name)
	if err != nil {
		return false
	}
	return inspect.State.Running
}

func networkExists(ctx context.Context, cli *client.Client, name string) bool {
	networks, err := cli.NetworkList(ctx, types.NetworkListOptions{})
	if err != nil {
		return false
	}
	for _, n := range networks {
		if n.Name == name {
			return true
		}
	}
	return false
}

func DefaultDockerConfig() DockerConfig {
	return DockerConfig{
		LocalRegistryName:     "local-registry",
		LocalRegistryHostPort: "5001",
		DockerHubCacheName:    "dockerhub-proxy-cache",
		QuayCacheName:         "quay-proxy-cache",
		GHCRCacheName:         "ghcr-proxy-cache",
		MCRCacheName:          "mcr-proxy-cache",
	}
}
