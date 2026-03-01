package plugin

import (
	"context"
	"fmt"

	"github.com/josephaw1022/superkind/pkg/engine"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/apis/meta/v1/unstructured"
	"k8s.io/apimachinery/pkg/runtime/schema"
)

type KyvernoPlugin struct {
	Namespace               string
	ChartVersion            string
	PoliciesVersion         string
	PolicyReporterNamespace string
	PolicyReporterHost      string
	Issuer                  string
	TLSSecret               string
}

func (p *KyvernoPlugin) Name() string {
	return "kyverno"
}

func (p *KyvernoPlugin) Install() error {
	fmt.Println("🚀 Installing Kyverno (Go SDK)...")

	// 1. Install Kyverno
	err := engine.RunHelmInstall(
		"kyverno",
		"kyverno",
		"https://kyverno.github.io/kyverno",
		p.ChartVersion,
		p.Namespace,
		nil,
	)
	if err != nil {
		return err
	}

	// 2. Install Kyverno Policies
	fmt.Println("🛡️  Installing Kyverno Policies...")
	err = engine.RunHelmInstall(
		"kyverno-policies",
		"kyverno-policies",
		"https://kyverno.github.io/kyverno",
		p.PoliciesVersion,
		p.Namespace,
		nil,
	)
	if err != nil {
		return err
	}

	// 3. Setup Policy Reporter Certificate
	_, dynClient, err := engine.GetClients()
	if err != nil {
		return err
	}

	certGVR := schema.GroupVersionResource{Group: "cert-manager.io", Version: "v1", Resource: "certificates"}
	cert := &unstructured.Unstructured{
		Object: map[string]interface{}{
			"apiVersion": "cert-manager.io/v1",
			"kind":       "Certificate",
			"metadata": map[string]interface{}{
				"name":      "policy-reporter-cert",
				"namespace": p.PolicyReporterNamespace,
			},
			"spec": map[string]interface{}{
				"secretName": p.TLSSecret,
				"dnsNames":   []string{p.PolicyReporterHost},
				"issuerRef": map[string]interface{}{
					"name": p.Issuer,
					"kind": "ClusterIssuer",
				},
			},
		},
	}

	fmt.Println("🔐 Ensuring TLS Certificate for Policy Reporter...")
	_, err = dynClient.Resource(certGVR).Namespace(p.PolicyReporterNamespace).Get(context.TODO(), "policy-reporter-cert", metav1.GetOptions{})
	if err != nil {
		_, err = dynClient.Resource(certGVR).Namespace(p.PolicyReporterNamespace).Create(context.TODO(), cert, metav1.CreateOptions{})
	}

	// 4. Install Policy Reporter
	fmt.Println("📊 Installing Policy Reporter...")
	prValues := map[string]interface{}{
		"ui": map[string]interface{}{
			"enabled": true,
			"ingress": map[string]interface{}{
				"enabled":   true,
				"className": "nginx",
				"hosts": []map[string]interface{}{
					{
						"host": p.PolicyReporterHost,
						"paths": []map[string]interface{}{
							{
								"path":     "/",
								"pathType": "Prefix",
							},
						},
					},
				},
				"tls": []map[string]interface{}{
					{
						"secretName": p.TLSSecret,
						"hosts":      []string{p.PolicyReporterHost},
					},
				},
			},
		},
	}

	err = engine.RunHelmInstall(
		"policy-reporter",
		"policy-reporter",
		"https://kyverno.github.io/policy-reporter",
		"",
		p.PolicyReporterNamespace,
		prValues,
	)
	if err != nil {
		return err
	}

	fmt.Printf("✅ Kyverno installed. Policy Reporter: https://%s\n", p.PolicyReporterHost)
	return nil
}

func (p *KyvernoPlugin) Status() error {
	fmt.Println("🔎 Checking Kyverno status...")
	return nil
}

func (p *KyvernoPlugin) Uninstall() error {
	fmt.Println("🧹 Uninstalling Kyverno components...")
	return nil
}

func (p *KyvernoPlugin) Help() string {
	return `Kyverno plugin (Go)
  install     Install Kyverno, policies, and Policy Reporter
  status      Show status
  uninstall   Remove components
  help        Show this help`
}

func NewKyvernoPlugin() *KyvernoPlugin {
	return &KyvernoPlugin{
		Namespace:               "kyverno",
		PolicyReporterNamespace: "policy-reporter",
		PolicyReporterHost:      "policy-reporter.localhost",
		Issuer:                  "quick-kind-ca",
		TLSSecret:               "policy-reporter-tls",
	}
}
