package engine

import (
	"fmt"
	"os"
	"os/exec"
	"strings"
)

type DockerConfig struct {
	LocalRegistryName      string
	LocalRegistryHostPort  string
	DockerHubCacheName     string
	QuayCacheName          string
	GHCRCacheName          string
	MCRCacheName           string
}

type ContainerEngine interface {
	EnsureLocalRegistry(cfg DockerConfig) error
	EnsurePullThroughCaches(cfg DockerConfig) error
	IsContainerRunning(name string) bool
}

func GetContainerEngine() (ContainerEngine, error) {
	cmd := GetContainerCommand()
	if cmd == "" {
		return nil, fmt.Errorf("neither podman nor docker CLI found or functional")
	}
	return &cliEngine{command: cmd}, nil
}

func GetContainerCommand() string {
	// 1. Respect explicit environment variable first
	if env := os.Getenv("KIND_EXPERIMENTAL_PROVIDER"); env != "" {
		if isCommandFunctional(env) {
			return env
		}
	}

	// 2. Check Podman
	if isCommandFunctional("podman") {
		return "podman"
	}

	// 3. Check Docker
	if isCommandFunctional("docker") {
		return "docker"
	}

	return ""
}

func isCommandAvailable(cmd string) bool {
	_, err := exec.LookPath(cmd)
	return err == nil
}

func isCommandFunctional(cmd string) bool {
	if !isCommandAvailable(cmd) {
		return false
	}
	// Run a simple command to verify the daemon is reachable and functional
	err := exec.Command(cmd, "info").Run()
	return err == nil
}

type cliEngine struct {
	command string
}

func (e *cliEngine) EnsureLocalRegistry(cfg DockerConfig) error {
	if e.IsContainerRunning(cfg.LocalRegistryName) {
		fmt.Printf("🗄️  local Zot registry already running.\n")
		return nil
	}

	fmt.Printf("🗄️  creating local Zot registry on localhost:%s...\n", cfg.LocalRegistryHostPort)
	imageName := "ghcr.io/project-zot/zot-linux-amd64:latest"
	
	args := []string{"run", "-d", "--restart=always",
		"--name", cfg.LocalRegistryName,
		"-p", fmt.Sprintf("%s:5000", cfg.LocalRegistryHostPort),
		imageName}
	
	return exec.Command(e.command, args...).Run()
}

func (e *cliEngine) EnsurePullThroughCaches(cfg DockerConfig) error {
	// Ensure network 'kind'
	exec.Command(e.command, "network", "create", "kind").Run()

	caches := []struct{ name, remote string }{
		{cfg.DockerHubCacheName, "https://registry-1.docker.io"},
		{cfg.QuayCacheName, "https://quay.io"},
		{cfg.GHCRCacheName, "https://ghcr.io"},
		{cfg.MCRCacheName, "https://mcr.microsoft.com"},
	}

	for _, c := range caches {
		if e.IsContainerRunning(c.name) {
			fmt.Printf("📦 %s already running.\n", c.name)
			continue
		}

		fmt.Printf("📦 creating %s pull-through cache...\n", c.name)
		args := []string{"run", "-d", "--restart=always", "--name", c.name,
			"-e", fmt.Sprintf("REGISTRY_PROXY_REMOTEURL=%s", c.remote),
			"--network", "kind", "registry:2"}
		
		if err := exec.Command(e.command, args...).Run(); err != nil {
			fmt.Printf("⚠️  failed to start cache %s: %v\n", c.name, err)
		} else {
			fmt.Printf("✅ %s created.\n", c.name)
		}
	}
	return nil
}

func (e *cliEngine) IsContainerRunning(name string) bool {
	cmd := exec.Command(e.command, "inspect", "-f", "{{.State.Running}}", name)
	output, err := cmd.Output()
	if err != nil {
		return false
	}
	return strings.TrimSpace(string(output)) == "true"
}

// Wrapper functions for backward compatibility in internal calls
func EnsureLocalRegistry(cfg DockerConfig) error {
	engine, err := GetContainerEngine()
	if err != nil { return err }
	return engine.EnsureLocalRegistry(cfg)
}

func EnsurePullThroughCaches(cfg DockerConfig) error {
	engine, err := GetContainerEngine()
	if err != nil { return err }
	return engine.EnsurePullThroughCaches(cfg)
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
