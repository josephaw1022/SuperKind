package engine

import (
	"context"
	"fmt"
	"os"
	"path/filepath"

	appsv1 "k8s.io/api/apps/v1"
	corev1 "k8s.io/api/core/v1"
	networkingv1 "k8s.io/api/networking/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/util/intstr"
	"k8s.io/client-go/util/homedir"
)

func int32Ptr(i int32) *int32 { return &i }
func stringPtr(s string) *string { return &s }

func EnsureFallbackUI(cfg K8sConfig) error {
	clientset, _, err := GetClients()
	if err != nil {
		return err
	}

	ns := "fallback-ui"
	_, err = clientset.CoreV1().Namespaces().Get(context.TODO(), ns, metav1.GetOptions{})
	if err != nil {
		fmt.Printf("📦 creating namespace %s...\n", ns)
		_, err = clientset.CoreV1().Namespaces().Create(context.TODO(), &corev1.Namespace{ObjectMeta: metav1.ObjectMeta{Name: ns}}, metav1.CreateOptions{})
		if err != nil {
			return err
		}
	}

	// Read index.html
	indexFile := filepath.Join(homedir.HomeDir(), ".kind", "index.html")
	indexBytes, err := os.ReadFile(indexFile)
	if err != nil {
		return fmt.Errorf("failed to read %s: %w", indexFile, err)
	}

	cm := &corev1.ConfigMap{
		ObjectMeta: metav1.ObjectMeta{Name: "fallback-ui-html", Namespace: ns},
		Data:       map[string]string{"index.html": string(indexBytes)},
	}
	_, err = clientset.CoreV1().ConfigMaps(ns).Get(context.TODO(), cm.Name, metav1.GetOptions{})
	if err != nil {
		fmt.Printf("📦 creating configmap %s...\n", cm.Name)
		_, err = clientset.CoreV1().ConfigMaps(ns).Create(context.TODO(), cm, metav1.CreateOptions{})
	} else {
		fmt.Printf("✅ configmap '%s' already exists; updating...\n", cm.Name)
		_, err = clientset.CoreV1().ConfigMaps(ns).Update(context.TODO(), cm, metav1.UpdateOptions{})
	}
	if err != nil {
		return err
	}

	deploy := &appsv1.Deployment{
		ObjectMeta: metav1.ObjectMeta{Name: "fallback-ui", Namespace: ns, Labels: map[string]string{"app": "fallback-ui"}},
		Spec: appsv1.DeploymentSpec{
			Replicas: int32Ptr(1),
			Selector: &metav1.LabelSelector{MatchLabels: map[string]string{"app": "fallback-ui"}},
			Template: corev1.PodTemplateSpec{
				ObjectMeta: metav1.ObjectMeta{Labels: map[string]string{"app": "fallback-ui"}},
				Spec: corev1.PodSpec{
					Containers: []corev1.Container{
						{
							Name:  "nginx",
							Image: "nginx:1.27-alpine",
							Ports: []corev1.ContainerPort{{ContainerPort: 80}},
							VolumeMounts: []corev1.VolumeMount{
								{Name: "site", MountPath: "/usr/share/nginx/html"},
							},
						},
					},
					Volumes: []corev1.Volume{
						{
							Name: "site",
							VolumeSource: corev1.VolumeSource{
								ConfigMap: &corev1.ConfigMapVolumeSource{
									LocalObjectReference: corev1.LocalObjectReference{Name: "fallback-ui-html"},
									Items: []corev1.KeyToPath{{Key: "index.html", Path: "index.html"}},
								},
							},
						},
					},
				},
			},
		},
	}

	_, err = clientset.AppsV1().Deployments(ns).Get(context.TODO(), deploy.Name, metav1.GetOptions{})
	if err != nil {
		fmt.Printf("📦 creating deployment %s...\n", deploy.Name)
		_, err = clientset.AppsV1().Deployments(ns).Create(context.TODO(), deploy, metav1.CreateOptions{})
	} else {
		fmt.Printf("✅ deployment '%s' already exists; updating...\n", deploy.Name)
		_, err = clientset.AppsV1().Deployments(ns).Update(context.TODO(), deploy, metav1.UpdateOptions{})
	}
	if err != nil {
		return err
	}

	svc := &corev1.Service{
		ObjectMeta: metav1.ObjectMeta{Name: "fallback-ui", Namespace: ns},
		Spec: corev1.ServiceSpec{
			Type:     corev1.ServiceTypeClusterIP,
			Selector: map[string]string{"app": "fallback-ui"},
			Ports: []corev1.ServicePort{
				{Name: "http", Port: 80, TargetPort: intstr.FromInt(80)},
			},
		},
	}

	existingSvc, err := clientset.CoreV1().Services(ns).Get(context.TODO(), svc.Name, metav1.GetOptions{})
	if err != nil {
		fmt.Printf("📦 creating service %s...\n", svc.Name)
		_, err = clientset.CoreV1().Services(ns).Create(context.TODO(), svc, metav1.CreateOptions{})
	} else {
		fmt.Printf("✅ service '%s' already exists; updating...\n", svc.Name)
		svc.ResourceVersion = existingSvc.ResourceVersion
		svc.Spec.ClusterIP = existingSvc.Spec.ClusterIP
		svc.Spec.ClusterIPs = existingSvc.Spec.ClusterIPs
		_, err = clientset.CoreV1().Services(ns).Update(context.TODO(), svc, metav1.UpdateOptions{})
	}
	if err != nil {
		return err
	}

	pathTypePrefix := networkingv1.PathTypePrefix
	ing := &networkingv1.Ingress{
		ObjectMeta: metav1.ObjectMeta{
			Name:      "fallback-ui",
			Namespace: ns,
			Annotations: map[string]string{
				"cert-manager.io/cluster-issuer": cfg.CAIssuerName,
			},
		},
		Spec: networkingv1.IngressSpec{
			IngressClassName: stringPtr("nginx"),
			Rules: []networkingv1.IngressRule{
				{
					IngressRuleValue: networkingv1.IngressRuleValue{
						HTTP: &networkingv1.HTTPIngressRuleValue{
							Paths: []networkingv1.HTTPIngressPath{
								{
									Path:     "/",
									PathType: &pathTypePrefix,
									Backend: networkingv1.IngressBackend{
										Service: &networkingv1.IngressServiceBackend{
											Name: "fallback-ui",
											Port: networkingv1.ServiceBackendPort{Number: 80},
										},
									},
								},
							},
						},
					},
				},
			},
		},
	}

	_, err = clientset.NetworkingV1().Ingresses(ns).Get(context.TODO(), ing.Name, metav1.GetOptions{})
	if err != nil {
		fmt.Printf("📦 creating ingress %s...\n", ing.Name)
		_, err = clientset.NetworkingV1().Ingresses(ns).Create(context.TODO(), ing, metav1.CreateOptions{})
	} else {
		fmt.Printf("✅ ingress '%s' already exists; updating...\n", ing.Name)
		_, err = clientset.NetworkingV1().Ingresses(ns).Update(context.TODO(), ing, metav1.UpdateOptions{})
	}
	return err
}
