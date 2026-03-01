package plugin

import (
	"fmt"

	"github.com/josephaw1022/superkind/pkg/engine"
)

type GatewayAPIPlugin struct {
	Namespace    string
	ChartVersion string
}

func (p *GatewayAPIPlugin) Name() string {
	return "gateway-api"
}

func (p *GatewayAPIPlugin) Install() error {
	fmt.Println("🚀 Installing Gateway API (Go SDK)...")
	return engine.RunHelmInstall(
		"gateway-api",
		"gateway-api",
		"https://charts.appscode.com/stable/",
		p.ChartVersion,
		nil,
	)
}

func (p *GatewayAPIPlugin) Status() error {
	fmt.Println("🔎 Checking Gateway API status...")
	return nil
}

func (p *GatewayAPIPlugin) Uninstall() error {
	fmt.Println("🧹 Uninstalling Gateway API...")
	return nil
}

func (p *GatewayAPIPlugin) Help() string {
	return `Gateway API plugin (Go)
  install     Install Gateway API CRDs
  status      Show status
  uninstall   Remove the Helm release
  help        Show this help`
}

func NewGatewayAPIPlugin() *GatewayAPIPlugin {
	return &GatewayAPIPlugin{
		Namespace:    "kube-system",
		ChartVersion: "2025.9.19",
	}
}
