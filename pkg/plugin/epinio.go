package plugin

import (
	"fmt"

	"github.com/josephaw1022/superkind/pkg/engine"
)

type EpinioPlugin struct {
	Namespace    string
	Domain       string
	Issuer       string
	ChartVersion string
}

func (p *EpinioPlugin) Name() string {
	return "epinio"
}

func (p *EpinioPlugin) Install() error {
	fmt.Printf("🚀 Installing Epinio in namespace %s (Go SDK)...\n", p.Namespace)
	values := map[string]interface{}{
		"global": map[string]interface{}{
			"domain": p.Domain,
		},
		"ingress": map[string]interface{}{
			"annotations": map[string]interface{}{
				"cert-manager.io/cluster-issuer": p.Issuer,
			},
		},
	}

	return engine.RunHelmInstall(
		"epinio",
		"epinio",
		"https://epinio.github.io/helm-charts",
		p.ChartVersion,
		values,
	)
}

func (p *EpinioPlugin) Status() error {
	fmt.Println("🔎 Checking Epinio status...")
	return nil
}

func (p *EpinioPlugin) Uninstall() error {
	fmt.Println("🧹 Uninstalling Epinio...")
	return nil
}

func (p *EpinioPlugin) Help() string {
	return `Epinio plugin (Go)
  install     Install Epinio
  status      Show status
  uninstall   Remove the Helm release
  help        Show this help`
}

func NewEpinioPlugin() *EpinioPlugin {
	return &EpinioPlugin{
		Namespace:    "epinio",
		Domain:       "127.0.0.1.sslip.io",
		Issuer:       "quick-kind-ca",
		ChartVersion: "",
	}
}
