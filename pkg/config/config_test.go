package config

import (
	"strings"
	"testing"
)

func TestDefaultConfig(t *testing.T) {
	cfg := DefaultConfig()

	if cfg.NamePrefix != "sk-" {
		t.Errorf("Expected NamePrefix sk-, got %s", cfg.NamePrefix)
	}

	if cfg.DefaultBaseName != "cluster" {
		t.Errorf("Expected DefaultBaseName cluster, got %s", cfg.DefaultBaseName)
	}

	if cfg.LocalRegistryHostPort != "5001" {
		t.Errorf("Expected LocalRegistryHostPort 5001, got %s", cfg.LocalRegistryHostPort)
	}
}

func TestConfigToEngineConfigs(t *testing.T) {
	cfg := DefaultConfig()
	clusterName := "sk-test"

	pkiCfg := cfg.ToPKIConfig()
	if !strings.HasSuffix(pkiCfg.CAKey, "rootCA.key") {
		t.Errorf("Unexpected CAKey path: %s", pkiCfg.CAKey)
	}

	dockerCfg := cfg.ToDockerConfig()
	if dockerCfg.LocalRegistryName != cfg.LocalRegistryName {
		t.Errorf("DockerConfig mismatch")
	}

	kindCfg := cfg.ToKindConfig(clusterName)
	if kindCfg.ClusterName != clusterName {
		t.Errorf("KindConfig mismatch")
	}

	k8sCfg := cfg.ToK8sConfig(clusterName)
	if k8sCfg.ClusterName != clusterName {
		t.Errorf("K8sConfig mismatch")
	}
}
