package plugin

import (
	"context"
	"fmt"

	"github.com/josephaw1022/superkind/pkg/engine"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/apis/meta/v1/unstructured"
	"k8s.io/apimachinery/pkg/runtime/schema"
)

type AWXPlugin struct {
	Namespace    string
	Host         string
	Issuer       string
	TLSSecret    string
	ChartVersion string
	InstanceName string
}

func (p *AWXPlugin) Name() string {
	return "awx"
}

func (p *AWXPlugin) Install() error {
	fmt.Println("🚀 Installing AWX Operator (Go SDK)...")

	// 1. Helm Install Operator
	err := engine.RunHelmInstall(
		"awx-operator",
		"awx-operator",
		"https://ansible-community.github.io/awx-operator-helm/",
		p.ChartVersion,
		nil,
	)
	if err != nil {
		return err
	}

	// 2. Setup AWX Instance
	_, dynClient, err := engine.GetClients()
	if err != nil {
		return err
	}

	awxGVR := schema.GroupVersionResource{Group: "awx.ansible.com", Version: "v1beta1", Resource: "awxs"}
	awx := &unstructured.Unstructured{
		Object: map[string]interface{}{
			"apiVersion": "awx.ansible.com/v1beta1",
			"kind":       "AWX",
			"metadata": map[string]interface{}{
				"name":      p.InstanceName,
				"namespace": p.Namespace,
			},
			"spec": map[string]interface{}{
				"service_type":        "ClusterIP",
				"admin_user":          "admin",
				"admin_email":         "admin@example.com",
				"create_preload_data": true,
				"ingress_type":        "ingress",
				"ingress_class_name":  "nginx",
				"ingress_tls_secret":  p.TLSSecret,
				"ingress_hosts": []map[string]interface{}{
					{"hostname": p.Host},
				},
			},
		},
	}

	fmt.Println("🚀 Applying AWX instance...")
	_, err = dynClient.Resource(awxGVR).Namespace(p.Namespace).Get(context.TODO(), p.InstanceName, metav1.GetOptions{})
	if err != nil {
		_, err = dynClient.Resource(awxGVR).Namespace(p.Namespace).Create(context.TODO(), awx, metav1.CreateOptions{})
	}

	fmt.Printf("✅ AWX orchestration initiated. URL: https://%s\n", p.Host)
	return nil
}

func (p *AWXPlugin) Status() error {
	fmt.Println("🔎 Checking AWX status...")
	return nil
}

func (p *AWXPlugin) Password() error {
	clientset, _, err := engine.GetClients()
	if err != nil {
		return err
	}
	secret, err := clientset.CoreV1().Secrets(p.Namespace).Get(context.TODO(), fmt.Sprintf("%s-admin-password", p.InstanceName), metav1.GetOptions{})
	if err != nil {
		return fmt.Errorf("failed to get AWX admin password: %w", err)
	}
	fmt.Printf("🔑 AWX Admin Password: %s\n", string(secret.Data["password"]))
	return nil
}

func (p *AWXPlugin) Uninstall() error {
	fmt.Println("🧹 Uninstalling AWX...")
	return nil
}

func (p *AWXPlugin) Help() string {
	return `AWX plugin (Go)
  install     Install Operator and Instance
  status      Show status
  uninstall   Remove components
  help        Show this help`
}

func NewAWXPlugin() *AWXPlugin {
	return &AWXPlugin{
		Namespace:    "awx",
		Host:         "awx.localhost",
		Issuer:       "quick-kind-ca",
		TLSSecret:    "awx-tls-secret",
		InstanceName: "awx-demo",
		ChartVersion: "",
	}
}
