package plugin

import (
	"fmt"

	"github.com/josephaw1022/superkind/pkg/engine"
)

type ESOPlugin struct {
	Namespace    string
	ChartVersion string
}

func (p *ESOPlugin) Name() string {
	return "eso"
}

func (p *ESOPlugin) Install() error {
	fmt.Printf("🚀 Installing External Secrets Operator v%s (Go SDK)...\\n", p.ChartVersion)
	values := map[string]interface{}{
		"installCRDs": true,
	}
	return engine.RunHelmInstall(
		"external-secrets",
		"external-secrets",
		"https://charts.external-secrets.io",
		p.ChartVersion,
		values,
	)
}

func (p *ESOPlugin) Status() error {
	fmt.Println("🔎 Checking ESO status...")
	return nil
}

func (p *ESOPlugin) Uninstall() error {
	fmt.Println("🧹 Uninstalling ESO...")
	return nil
}

func (p *ESOPlugin) Help() string {
	return `External Secrets Operator plugin (Go)
  install     Install ESO
  status      Show status
  uninstall   Remove the Helm release
  help        Show this help`
}

func NewESOPlugin() *ESOPlugin {
	return &ESOPlugin{
		Namespace:    "external-secrets",
		ChartVersion: "0.10.4",
	}
}
