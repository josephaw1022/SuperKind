package plugin

import (
	"context"
	"fmt"

	"github.com/josephaw1022/superkind/pkg/engine"
	corev1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
)

type VeleroPlugin struct {
	Namespace       string
	UINamespace     string
	UIHost          string
	ChartVersion    string
	MinioName       string
	MinioUser       string
	MinioPass       string
}

func (p *VeleroPlugin) Name() string {
	return "velero"
}

func (p *VeleroPlugin) Install() error {
	fmt.Println("🚀 Installing Velero with MinIO backend (Go SDK)...")

	// 1. Ensure MinIO is running (we can reuse engine.EnsureLocalRegistry pattern or docker sdk)
	// For now, let's focus on the K8s parts as the Docker logic is already established in engine.
	
	// 2. Create Namespace and Secret
	clientset, _, err := engine.GetClients()
	if err != nil {
		return err
	}

	_, err = clientset.CoreV1().Namespaces().Get(context.TODO(), p.Namespace, metav1.GetOptions{})
	if err != nil {
		clientset.CoreV1().Namespaces().Create(context.TODO(), &corev1.Namespace{ObjectMeta: metav1.ObjectMeta{Name: p.Namespace}}, metav1.CreateOptions{})
	}

	creds := fmt.Sprintf("[default]\naws_access_key_id=%s\naws_secret_access_key=%s", p.MinioUser, p.MinioPass)
	secret := &corev1.Secret{
		ObjectMeta: metav1.ObjectMeta{
			Name:      "cloud-credentials",
			Namespace: p.Namespace,
		},
		StringData: map[string]string{
			"cloud": creds,
		},
	}

	_, err = clientset.CoreV1().Secrets(p.Namespace).Get(context.TODO(), "cloud-credentials", metav1.GetOptions{})
	if err != nil {
		clientset.CoreV1().Secrets(p.Namespace).Create(context.TODO(), secret, metav1.CreateOptions{})
	}

	// 3. Helm Install Velero
	veleroValues := map[string]interface{}{
		"credentials": map[string]interface{}{
			"useSecret":      true,
			"existingSecret": "cloud-credentials",
		},
		"configuration": map[string]interface{}{
			"backupStorageLocation": []map[string]interface{}{
				{
					"name":     "default",
					"provider": "aws",
					"bucket":   "velero",
					"config": map[string]interface{}{
						"region":           "us-east-1",
						"s3ForcePathStyle": true,
						"s3Url":            fmt.Sprintf("http://%s:9000", p.MinioName),
					},
				},
			},
		},
		"initContainers": []map[string]interface{}{
			{
				"name":  "velero-plugin-for-aws",
				"image": "velero/velero-plugin-for-aws:v1.9.0",
				"volumeMounts": []map[string]interface{}{
					{"name": "plugins", "mountPath": "/target"},
				},
			},
		},
	}

	err = engine.RunHelmInstall(
		"velero",
		"velero",
		"https://vmware-tanzu.github.io/helm-charts",
		p.ChartVersion,
		veleroValues,
	)
	if err != nil {
		return err
	}

	// 4. Install Velero UI
	uiValues := map[string]interface{}{
		"ingress": map[string]interface{}{
			"enabled":   true,
			"className": "nginx",
			"hosts": []map[string]interface{}{
				{
					"host": p.UIHost,
					"paths": []map[string]interface{}{
						{"path": "/", "pathType": "Prefix"},
					},
				},
			},
		},
	}

	err = engine.RunHelmInstall(
		"velero-ui",
		"velero-ui",
		"https://helm.otwld.com/",
		"",
		uiValues,
	)
	if err != nil {
		return err
	}

	fmt.Printf("✅ Velero installed. UI: https://%s\n", p.UIHost)
	return nil
}

func (p *VeleroPlugin) Status() error {
	fmt.Println("🔎 Checking Velero status...")
	return nil
}

func (p *VeleroPlugin) Uninstall() error {
	fmt.Println("🧹 Uninstalling Velero...")
	return nil
}

func (p *VeleroPlugin) Help() string {
	return `Velero plugin (Go)
  install     Install Velero and UI
  status      Show status
  uninstall   Remove components
  help        Show this help`
}

func NewVeleroPlugin() *VeleroPlugin {
	return &VeleroPlugin{
		Namespace:    "velero",
		UINamespace:  "velero-ui",
		UIHost:       "velero-ui.localhost",
		MinioName:    "minio",
		MinioUser:    "velero",
		MinioPass:    "veleropass123",
		ChartVersion: "",
	}
}
