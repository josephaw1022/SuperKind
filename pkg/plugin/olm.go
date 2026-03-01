package plugin

import (
	"fmt"
	"os/exec"
)

type OLMPlugin struct {
	Version   string
	Namespace string
}

func (p *OLMPlugin) Name() string {
	return "olm"
}

func (p *OLMPlugin) Install() error {
	fmt.Printf("🚀 Installing OLM %s (Go SDK)...\\n", p.Version)
	
	// For OLM, we'll use the quickstart YAMLs as it's the most reliable way in Go
	// without re-implementing their install script logic.
	urls := []string{
		"https://raw.githubusercontent.com/operator-framework/operator-lifecycle-manager/master/deploy/upstream/quickstart/crds.yaml",
		"https://raw.githubusercontent.com/operator-framework/operator-lifecycle-manager/master/deploy/upstream/quickstart/olm.yaml",
	}

	for _, url := range urls {
		cmd := exec.Command("kubectl", "apply", "-f", url)
		if err := cmd.Run(); err != nil {
			return fmt.Errorf("failed to apply OLM manifest %s: %w", url, err)
		}
	}

	fmt.Println("✅ OLM installed.")
	return nil
}

func (p *OLMPlugin) Status() error {
	fmt.Println("🔎 Checking OLM status...")
	return nil
}

func (p *OLMPlugin) Uninstall() error {
	fmt.Println("🧹 Uninstalling OLM...")
	return nil
}

func (p *OLMPlugin) Help() string {
	return `OLM plugin (Go)
  install     Install/upgrade OLM
  status      Show status
  uninstall   Remove OLM
  help        Show this help`
}

func NewOLMPlugin() *OLMPlugin {
	return &OLMPlugin{
		Version:   "v0.34.0",
		Namespace: "olm",
	}
}
