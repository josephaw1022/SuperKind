package engine

import (
	"fmt"

	"sigs.k8s.io/kind/pkg/cluster"
)

type KindConfig struct {
	ClusterName           string
	LocalRegistryName     string
	LocalRegistryHostPort string
	DockerHubCacheName    string
	QuayCacheName         string
	GHCRCacheName         string
	MCRCacheName          string
}

func GetKindProvider() cluster.ProviderOption {
	if isCommandAvailable("podman") {
		return cluster.ProviderWithPodman()
	}
	if isCommandAvailable("docker") {
		return cluster.ProviderWithDocker()
	}
	return cluster.ProviderWithDocker()
}

func EnsureKindCluster(cfg KindConfig) error {
	fmt.Printf("▶ creating kind cluster '%s' (if needed)...\n", cfg.ClusterName)

	provider := cluster.NewProvider(GetKindProvider())

	clusters, err := provider.List()
	if err != nil {
		return fmt.Errorf("failed to list kind clusters: %w", err)
	}

	for _, c := range clusters {
		if c == cfg.ClusterName {
			fmt.Printf("… cluster already exists; skipping create.\n")
			return nil
		}
	}

	config := generateKindConfig(cfg)
	if err := provider.Create(
		cfg.ClusterName,
		cluster.CreateWithRawConfig([]byte(config)),
	); err != nil {
		return fmt.Errorf("failed to create kind cluster: %w", err)
	}

	return nil
}

func generateKindConfig(cfg KindConfig) string {
	return fmt.Sprintf(`kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4

containerdConfigPatches:
  - |-
    [plugins."io.containerd.grpc.v1.cri".registry.mirrors."localhost:%s"]
      endpoint = ["http://%s:5000"]
  - |-
    [plugins."io.containerd.grpc.v1.cri".registry.mirrors."docker.io"]
      endpoint = ["http://%s:5000"]
  - |-
    [plugins."io.containerd.grpc.v1.cri".registry.mirrors."quay.io"]
      endpoint = ["http://%s:5000"]
  - |-
    [plugins."io.containerd.grpc.v1.cri".registry.mirrors."ghcr.io"]
      endpoint = ["http://%s:5000"]
  - |-
    [plugins."io.containerd.grpc.v1.cri".registry.mirrors."mcr.microsoft.com"]
      endpoint = ["http://%s:5000"]

nodes:
- role: control-plane
  extraPortMappings:
  - containerPort: 30080
    hostPort: 80
    protocol: TCP
  - containerPort: 30443
    hostPort: 443
    protocol: TCP
- role: worker
- role: worker
- role: worker
`, cfg.LocalRegistryHostPort, cfg.LocalRegistryName,
		cfg.DockerHubCacheName, cfg.QuayCacheName, cfg.GHCRCacheName, cfg.MCRCacheName)
}

func ConfigureKindNodes(cfg KindConfig) error {
	provider := cluster.NewProvider(GetKindProvider())
	nodes, err := provider.ListNodes(cfg.ClusterName)
	if err != nil {
		return fmt.Errorf("failed to list kind nodes: %w", err)
	}

	for _, node := range nodes {
		fmt.Printf("🔧 patching containerd mirrors on %s\n", node.String())

		dirs := []string{
			fmt.Sprintf("localhost:%s", cfg.LocalRegistryHostPort),
			"docker.io",
			"quay.io",
			"ghcr.io",
			"mcr.microsoft.com",
		}

		for _, d := range dirs {
			if err := node.Command("mkdir", "-p", fmt.Sprintf("/etc/containerd/certs.d/%s", d)).Run(); err != nil {
				return fmt.Errorf("failed to create directory on node: %w", err)
			}
		}

		patchCmd := fmt.Sprintf(`cat > /etc/containerd/certs.d/localhost:%s/hosts.toml <<EON
[host."http://%s:5000"]
EON`, cfg.LocalRegistryHostPort, cfg.LocalRegistryName)
		if err := node.Command("bash", "-c", patchCmd).Run(); err != nil {
			return fmt.Errorf("failed to patch local registry on node: %w", err)
		}

		mirrors := []struct {
			host  string
			cache string
		}{
			{"docker.io", cfg.DockerHubCacheName},
			{"quay.io", cfg.QuayCacheName},
			{"ghcr.io", cfg.GHCRCacheName},
			{"mcr.microsoft.com", cfg.MCRCacheName},
		}

		for _, m := range mirrors {
			patchCmd := fmt.Sprintf(`cat > /etc/containerd/certs.d/%s/hosts.toml <<EON
[host."http://%s:5000"]
EON`, m.host, m.cache)
			if err := node.Command("bash", "-c", patchCmd).Run(); err != nil {
				return fmt.Errorf("failed to patch mirror %s on node: %w", m.host, err)
			}
		}
	}

	return nil
}
