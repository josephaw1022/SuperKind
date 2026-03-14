package plugin

import (
	"fmt"

	"github.com/josephaw1022/superkind/pkg/engine"
)

type VPAPlugin struct{}

func NewVPAPlugin() *VPAPlugin {
	return &VPAPlugin{}
}

func (p *VPAPlugin) Name() string {
	return "vpa"
}

func (p *VPAPlugin) Install() error {
	fmt.Println("📈 Installing Vertical Pod Autoscaler (VPA)...")
	values := map[string]interface{}{}

	return engine.RunHelmInstall(
		"vpa",
		"vpa",
		"https://kubernetes.github.io/autoscaler",
		"0.8.0",
		"kube-system",
		values,
	)
}

func (p *VPAPlugin) Status() error {
	fmt.Println("🔎 Checking VPA status...")
	// We can add more detailed check here later
	return nil
}

func (p *VPAPlugin) Uninstall() error {
	return engine.RunHelmUninstall("vpa", "kube-system")
}

func (p *VPAPlugin) Help() string {
	return `vpa plugin (Go)
  install     Install Vertical Pod Autoscaler
  status      Show status
  uninstall   Remove the Helm release
  help        Show this help`
}
