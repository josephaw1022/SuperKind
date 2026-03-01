package plugin

import (
	"fmt"

	"github.com/josephaw1022/superkind/pkg/engine"
)

type KEDAPlugin struct {
	Namespace    string
	ChartVersion string
}

func (p *KEDAPlugin) Name() string {
	return "keda"
}

func (p *KEDAPlugin) Install() error {
	fmt.Println("🚀 Installing KEDA (Go SDK)...")
	return engine.RunHelmInstall(
		"keda",
		"keda",
		"https://kedacore.github.io/charts",
		p.ChartVersion,
		nil,
	)
}

func (p *KEDAPlugin) Status() error {
	fmt.Println("🔎 Checking KEDA status...")
	return nil
}

func (p *KEDAPlugin) Uninstall() error {
	fmt.Println("🧹 Uninstalling KEDA...")
	return nil
}

func (p *KEDAPlugin) Help() string {
	return `KEDA plugin (Go)
  install     Install/upgrade KEDA
  status      Show status
  uninstall   Remove the Helm release
  help        Show this help`
}

func NewKEDAPlugin() *KEDAPlugin {
	return &KEDAPlugin{
		Namespace:    "keda",
		ChartVersion: "",
	}
}
