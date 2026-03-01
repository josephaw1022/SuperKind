package plugin

import (
	"context"
	"fmt"

	"github.com/josephaw1022/superkind/pkg/engine"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/apis/meta/v1/unstructured"
	"k8s.io/apimachinery/pkg/runtime/schema"
)

type ArgoCDPlugin struct {
	Namespace      string
	Host           string
	IngressClass   string
	TLSSecret      string
	Issuer         string
	ChartVersion   string
}

func (p *ArgoCDPlugin) Name() string {
	return "argocd"
}

func (p *ArgoCDPlugin) Install() error {
	fmt.Println("🚀 Installing Argo CD (Go SDK)...")

	// 1. Create Namespace
	_, dynClient, err := engine.GetClients()
	if err != nil {
		return err
	}

	// 2. Create Certificate (Custom Resource)
	certGVR := schema.GroupVersionResource{Group: "cert-manager.io", Version: "v1", Resource: "certificates"}
	cert := &unstructured.Unstructured{
		Object: map[string]interface{}{
			"apiVersion": "cert-manager.io/v1",
			"kind":       "Certificate",
			"metadata": map[string]interface{}{
				"name":      "argocd-cert",
				"namespace": p.Namespace,
			},
			"spec": map[string]interface{}{
				"secretName": p.TLSSecret,
				"dnsNames":   []string{p.Host},
				"issuerRef": map[string]interface{}{
					"name": p.Issuer,
					"kind": "ClusterIssuer",
				},
			},
		},
	}

	_, err = dynClient.Resource(certGVR).Namespace(p.Namespace).Get(context.TODO(), "argocd-cert", metav1.GetOptions{})
	if err != nil {
		fmt.Println("📦 creating Argo CD certificate...")
		_, err = dynClient.Resource(certGVR).Namespace(p.Namespace).Create(context.TODO(), cert, metav1.CreateOptions{})
	} else {
		fmt.Println("✅ Argo CD certificate already exists.")
	}

	// 3. Helm Install
	values := map[string]interface{}{
		"global": map[string]interface{}{
			"domain": p.Host,
		},
		"configs": map[string]interface{}{
			"params": map[string]interface{}{
				"server.insecure": "true",
			},
			"cm": map[string]interface{}{
				"timeout.reconciliation": "30s",
			},
		},
		"server": map[string]interface{}{
			"service": map[string]interface{}{
				"type": "ClusterIP",
			},
			"ingress": map[string]interface{}{
				"enabled":          true,
				"ingressClassName": p.IngressClass,
				"annotations": map[string]interface{}{
					"cert-manager.io/cluster-issuer": p.Issuer,
				},
				"hosts": []string{p.Host},
				"tls": []map[string]interface{}{
					{
						"secretName": p.TLSSecret,
						"hosts":      []string{p.Host},
					},
				},
			},
		},
		"controller": map[string]interface{}{
			"env": []map[string]interface{}{
				{
					"name":  "ARGOCD_SYNC_WAVE_DELAY",
					"value": "15",
				},
			},
		},
	}

	err = engine.RunHelmInstall(
		"argocd",
		"argo-cd",
		"https://argoproj.github.io/argo-helm",
		p.ChartVersion,
		p.Namespace,
		values,
	)
	if err != nil {
		return err
	}

	fmt.Printf("✅ Argo CD ready at https://%s\n", p.Host)
	return nil
}

func (p *ArgoCDPlugin) Status() error {
	fmt.Println("🔎 Checking Argo CD status...")
	return nil
}

func (p *ArgoCDPlugin) Uninstall() error {
	fmt.Println("🧹 Uninstalling Argo CD...")
	return nil
}

func (p *ArgoCDPlugin) Help() string {
	return `Argo CD plugin (Go)
  install     Install Argo CD
  status      Show status
  uninstall   Remove the Helm release
  help        Show this help`
}

func NewArgoCDPlugin() *ArgoCDPlugin {
	return &ArgoCDPlugin{
		Namespace:    "argocd",
		Host:         "argocd.localhost",
		IngressClass: "nginx",
		TLSSecret:    "argocd-tls-secret",
		Issuer:       "quick-kind-ca", // Updated to match SuperKind default
		ChartVersion: "",               // latest
	}
}
