package engine

import (
	"context"
	"fmt"
	"log"
	"os"
	"path/filepath"

	"helm.sh/helm/v3/pkg/action"
	"helm.sh/helm/v3/pkg/chart/loader"
	"helm.sh/helm/v3/pkg/cli"
	"helm.sh/helm/v3/pkg/storage/driver"
	corev1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/apis/meta/v1/unstructured"
	"k8s.io/apimachinery/pkg/runtime/schema"
	"k8s.io/client-go/dynamic"
	"k8s.io/client-go/kubernetes"
	"k8s.io/client-go/tools/clientcmd"
	"k8s.io/client-go/util/homedir"
)

type K8sConfig struct {
	ClusterName           string
	LocalRegistryHostPort string
	CASecretName          string
	CAIssuerName          string
	CACrtPath             string
	CAKeyPath             string
}

func GetKubeConfig() (string, error) {
	if kubeconfig := os.Getenv("KUBECONFIG"); kubeconfig != "" {
		return kubeconfig, nil
	}
	if home := homedir.HomeDir(); home != "" {
		return filepath.Join(home, ".kube", "config"), nil
	}
	return "", fmt.Errorf("could not find kubeconfig")
}

func GetClients() (*kubernetes.Clientset, dynamic.Interface, error) {
	kubeconfig, err := GetKubeConfig()
	if err != nil {
		return nil, nil, err
	}
	config, err := clientcmd.BuildConfigFromFlags("", kubeconfig)
	if err != nil {
		return nil, nil, err
	}
	clientset, err := kubernetes.NewForConfig(config)
	if err != nil {
		return nil, nil, err
	}
	dynClient, err := dynamic.NewForConfig(config)
	if err != nil {
		return nil, nil, err
	}
	return clientset, dynClient, nil
}

func EnsureRegistryConfigMap(cfg K8sConfig) error {
	clientset, _, err := GetClients()
	if err != nil {
		return err
	}

	cm := &corev1.ConfigMap{
		ObjectMeta: metav1.ObjectMeta{
			Name:      "local-registry-hosting",
			Namespace: "kube-public",
		},
		Data: map[string]string{
			"localRegistryHosting.v1": fmt.Sprintf("host: \"localhost:%s\"\nhelp: \"https://kind.sigs.k8s.io/docs/user/local-registry/\"\n", cfg.LocalRegistryHostPort),
		},
	}

	_, err = clientset.CoreV1().ConfigMaps("kube-public").Get(context.TODO(), cm.Name, metav1.GetOptions{})
	if err != nil {
		fmt.Println("📦 creating registry configmap...")
		_, err = clientset.CoreV1().ConfigMaps("kube-public").Create(context.TODO(), cm, metav1.CreateOptions{})
	} else {
		fmt.Println("✅ registry configmap already exists; updating...")
		_, err = clientset.CoreV1().ConfigMaps("kube-public").Update(context.TODO(), cm, metav1.UpdateOptions{})
	}
	return err
}

func EnsureCertManager() error {
	return RunHelmInstall(
		"cert-manager",
		"cert-manager",
		"https://charts.jetstack.io",
		"v1.15.3",
		"cert-manager",
		map[string]interface{}{
			"installCRDs": true,
		},
	)
}

func EnsureIngressNginx() error {
	return RunHelmInstall(
		"ingress-nginx",
		"ingress-nginx",
		"https://kubernetes.github.io/ingress-nginx",
		"4.11.2",
		"ingress-nginx",
		map[string]interface{}{
			"controller": map[string]interface{}{
				"ingressClassResource": map[string]interface{}{
					"default": true,
				},
				"service": map[string]interface{}{
					"type": "NodePort",
					"nodePorts": map[string]interface{}{
						"http":  30080,
						"https": 30443,
					},
				},
			},
		},
	)
}

func EnsurePrometheusStack() error {
	return RunHelmInstall(
		"prometheus",
		"kube-prometheus-stack",
		"https://prometheus-community.github.io/helm-charts",
		"61.7.0",
		"kube-system",
		map[string]interface{}{
			"prometheus": map[string]interface{}{
				"prometheusSpec": map[string]interface{}{},
			},
			"alertmanager": map[string]interface{}{
				"alertmanagerSpec": map[string]interface{}{},
			},
		},
	)
}

func RunHelmInstall(releaseName, chartName, repoURL, version string, namespace string, values map[string]interface{}) error {
	settings := cli.New()

	actionConfig := new(action.Configuration)
	if err := actionConfig.Init(settings.RESTClientGetter(), namespace, os.Getenv("HELM_DRIVER"), log.Printf); err != nil {
		return err
	}

	// Ensure namespace exists
	clientset, _, err := GetClients()
	if err == nil {
		_, err = clientset.CoreV1().Namespaces().Get(context.TODO(), namespace, metav1.GetOptions{})
		if err != nil {
			clientset.CoreV1().Namespaces().Create(context.TODO(), &corev1.Namespace{ObjectMeta: metav1.ObjectMeta{Name: namespace}}, metav1.CreateOptions{})
		}
	}

	// Check if already installed
	histClient := action.NewHistory(actionConfig)
	histClient.Max = 1
	if _, err := histClient.Run(releaseName); err == driver.ErrReleaseNotFound {
		fmt.Printf("📦 installing helm release %s in %s...\n", releaseName, namespace)
		client := action.NewInstall(actionConfig)
		client.ReleaseName = releaseName
		client.Namespace = namespace
		client.RepoURL = repoURL
		client.Version = version
		client.CreateNamespace = false // Handled above

		cp, err := client.LocateChart(chartName, settings)
		if err != nil { return err }
		chartRequested, err := loader.Load(cp)
		if err != nil { return err }
		_, err = client.Run(chartRequested, values)
		return err
	}

	fmt.Printf("📦 updating helm release %s in %s...\n", releaseName, namespace)
	client := action.NewUpgrade(actionConfig)
	client.Namespace = namespace
	client.RepoURL = repoURL
	client.Version = version
	client.Install = true

	cp, err := client.LocateChart(chartName, settings)
	if err != nil { return err }
	chartRequested, err := loader.Load(cp)
	if err != nil { return err }
	_, err = client.Run(releaseName, chartRequested, values)
	return err
}

func EnsureCASecretAndIssuer(cfg K8sConfig) error {
	clientset, dynClient, err := GetClients()
	if err != nil {
		return err
	}

	// Ensure namespace cert-manager exists
	_, err = clientset.CoreV1().Namespaces().Get(context.TODO(), "cert-manager", metav1.GetOptions{})
	if err != nil {
		clientset.CoreV1().Namespaces().Create(context.TODO(), &corev1.Namespace{ObjectMeta: metav1.ObjectMeta{Name: "cert-manager"}}, metav1.CreateOptions{})
	}

	// Read cert and key
	certData, err := os.ReadFile(cfg.CACrtPath)
	if err != nil {
		return err
	}
	keyData, err := os.ReadFile(cfg.CAKeyPath)
	if err != nil {
		return err
	}

	secret := &corev1.Secret{
		ObjectMeta: metav1.ObjectMeta{
			Name:      cfg.CASecretName,
			Namespace: "cert-manager",
		},
		Type: corev1.SecretTypeTLS,
		Data: map[string][]byte{
			"tls.crt": certData,
			"tls.key": keyData,
		},
	}

	_, err = clientset.CoreV1().Secrets("cert-manager").Get(context.TODO(), cfg.CASecretName, metav1.GetOptions{})
	if err != nil {
		fmt.Printf("📦 creating CA secret %s...\n", cfg.CASecretName)
		_, err = clientset.CoreV1().Secrets("cert-manager").Create(context.TODO(), secret, metav1.CreateOptions{})
	} else {
		fmt.Printf("✅ CA secret '%s' already exists; updating...\n", cfg.CASecretName)
		_, err = clientset.CoreV1().Secrets("cert-manager").Update(context.TODO(), secret, metav1.UpdateOptions{})
	}
	if err != nil {
		return err
	}

	// Apply ClusterIssuer using dynamic client
	issuerGVR := schema.GroupVersionResource{Group: "cert-manager.io", Version: "v1", Resource: "clusterissuers"}
	issuer := &unstructured.Unstructured{
		Object: map[string]interface{}{
			"apiVersion": "cert-manager.io/v1",
			"kind":       "ClusterIssuer",
			"metadata": map[string]interface{}{
				"name": cfg.CAIssuerName,
			},
			"spec": map[string]interface{}{
				"ca": map[string]interface{}{
					"secretName": cfg.CASecretName,
				},
			},
		},
	}

	_, err = dynClient.Resource(issuerGVR).Get(context.TODO(), cfg.CAIssuerName, metav1.GetOptions{})
	if err != nil {
		fmt.Printf("📦 creating ClusterIssuer %s...\n", cfg.CAIssuerName)
		_, err = dynClient.Resource(issuerGVR).Create(context.TODO(), issuer, metav1.CreateOptions{})
	} else {
		fmt.Printf("✅ ClusterIssuer '%s' already exists; updating...\n", cfg.CAIssuerName)
		res, _ := dynClient.Resource(issuerGVR).Get(context.TODO(), cfg.CAIssuerName, metav1.GetOptions{})
		issuer.SetResourceVersion(res.GetResourceVersion())
		_, err = dynClient.Resource(issuerGVR).Update(context.TODO(), issuer, metav1.UpdateOptions{})
	}

	return err
}
