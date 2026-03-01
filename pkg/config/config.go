package config

import (
	"os"
	"path/filepath"

	"github.com/josephaw1022/superkind/pkg/engine"
)

type Config struct {
	NamePrefix            string
	DefaultBaseName       string
	LocalRegistryName     string
	LocalRegistryHostPort string
	DockerHubCacheName    string
	QuayCacheName         string
	GHCRCacheName         string
	MCRCacheName          string
	CASecretName          string
	CAIssuerName          string
	CADir                 string
	CAKey                 string
	CACrt                 string
	CACN                  string
	CAOrg                 string
	CAOU                  string
	CADays                int
	PluginDir             string
}

func DefaultConfig() *Config {
	home, _ := os.UserHomeDir()
	caDir := filepath.Join(home, ".local/share/quick-kind/ca")

	return &Config{
		NamePrefix:            "qk-",
		DefaultBaseName:       "quick-cluster",
		LocalRegistryName:     "local-registry",
		LocalRegistryHostPort: "5001",
		DockerHubCacheName:    "dockerhub-proxy-cache",
		QuayCacheName:         "quay-proxy-cache",
		GHCRCacheName:         "ghcr-proxy-cache",
		MCRCacheName:          "mcr-proxy-cache",
		CASecretName:          "quick-kind-ca",
		CAIssuerName:          "quick-kind-ca",
		CADir:                 caDir,
		CAKey:                 filepath.Join(caDir, "rootCA.key"),
		CACrt:                 filepath.Join(caDir, "rootCA.crt"),
		CACN:                  "Quick Kind Local CA",
		CAOrg:                 "Quick Kind",
		CAOU:                  "Dev",
		CADays:                3650,
		PluginDir:             filepath.Join(home, ".kind/plugin"),
	}
}

func (c *Config) ToPKIConfig() engine.PKIConfig {
	return engine.PKIConfig{
		CADir:  c.CADir,
		CAKey:  c.CAKey,
		CACrt:  c.CACrt,
		CACN:   c.CACN,
		CAOrg:  c.CAOrg,
		CAOU:   c.CAOU,
		CADays: c.CADays,
	}
}

func (c *Config) ToDockerConfig() engine.DockerConfig {
	return engine.DockerConfig{
		LocalRegistryName:     c.LocalRegistryName,
		LocalRegistryHostPort: c.LocalRegistryHostPort,
		DockerHubCacheName:    c.DockerHubCacheName,
		QuayCacheName:         c.QuayCacheName,
		GHCRCacheName:         c.GHCRCacheName,
		MCRCacheName:          c.MCRCacheName,
	}
}

func (c *Config) ToKindConfig(clusterName string) engine.KindConfig {
	return engine.KindConfig{
		ClusterName:           clusterName,
		LocalRegistryName:     c.LocalRegistryName,
		LocalRegistryHostPort: c.LocalRegistryHostPort,
		DockerHubCacheName:    c.DockerHubCacheName,
		QuayCacheName:         c.QuayCacheName,
		GHCRCacheName:         c.GHCRCacheName,
		MCRCacheName:          c.MCRCacheName,
	}
}

func (c *Config) ToK8sConfig(clusterName string) engine.K8sConfig {
	return engine.K8sConfig{
		ClusterName:           clusterName,
		LocalRegistryHostPort: c.LocalRegistryHostPort,
		CASecretName:          c.CASecretName,
		CAIssuerName:          c.CAIssuerName,
		CACrtPath:             c.CACrt,
		CAKeyPath:             c.CAKey,
	}
}
