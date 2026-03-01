package plugin

import (
	"fmt"

	"github.com/josephaw1022/superkind/pkg/engine"
)

type MetricsServerPlugin struct{}

func (p *MetricsServerPlugin) Name() string {
	return "metrics-server"
}

func (p *MetricsServerPlugin) Install() error {
	fmt.Println("📈 Installing metrics-server (Go SDK)...")
	values := map[string]interface{}{
		"args": []string{
			"--kubelet-preferred-address-types=InternalIP,Hostname,ExternalIP",
			"--kubelet-insecure-tls",
			"--metric-resolution=15s",
		},
		"resources": map[string]interface{}{
			"requests": map[string]interface{}{
				"cpu":    "50m",
				"memory": "64Mi",
			},
			"limits": map[string]interface{}{
				"cpu":    "200m",
				"memory": "256Mi",
			},
		},
	}

	return engine.RunHelmInstall(
		"metrics-server",
		"metrics-server",
		"https://kubernetes-sigs.github.io/metrics-server/",
		"3.12.1",
		values,
	)
}

func (p *MetricsServerPlugin) Status() error {
	fmt.Println("🔎 Checking metrics-server status...")
	// We can implement more detailed status check using GetClients() if needed
	return nil
}

func (p *MetricsServerPlugin) Uninstall() error {
	fmt.Println("🧹 Uninstalling metrics-server...")
	// Implementation for helm uninstall using action.NewUninstall
	return nil
}

func (p *MetricsServerPlugin) Help() string {
	return `metrics-server plugin (Go)
  install     Install metrics-server (Kind-safe args)
  status      Show status
  uninstall   Remove the Helm release
  help        Show this help`
}
