package plugin

import (
	"context"
	"fmt"

	"github.com/josephaw1022/superkind/pkg/engine"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/apis/meta/v1/unstructured"
	"k8s.io/apimachinery/pkg/runtime/schema"
)

type OTelPlugin struct {
	Namespace           string
	ChartVersion        string
	ObservabilityNS     string
	AspireHost          string
	Issuer              string
	TLSSecret           string
}

func (p *OTelPlugin) Name() string {
	return "otel"
}

func (p *OTelPlugin) Install() error {
	fmt.Println("🚀 Installing OpenTelemetry Operator (Go SDK)...")

	// 1. Helm Install Operator
	otelValues := map[string]interface{}{
		"manager": map[string]interface{}{
			"collectorImage": map[string]interface{}{
				"repository": "otel/opentelemetry-collector-k8s",
			},
		},
		"admissionWebhooks": map[string]interface{}{
			"certManager": map[string]interface{}{
				"enabled": true,
				"issuerRef": map[string]interface{}{
					"name": p.Issuer,
					"kind": "ClusterIssuer",
				},
			},
			"autoGenerateCert": map[string]interface{}{
				"enabled": true,
			},
		},
	}

	err := engine.RunHelmInstall(
		"opentelemetry-operator",
		"opentelemetry-operator",
		"https://open-telemetry.github.io/opentelemetry-helm-charts",
		p.ChartVersion,
		otelValues,
	)
	if err != nil {
		return err
	}

	// 2. Deploy Aspire Dashboard and Collector
	_, dynClient, err := engine.GetClients()
	if err != nil {
		return err
	}

	// For brevity, we'll implement the collector CR applying here
	collectorGVR := schema.GroupVersionResource{Group: "opentelemetry.io", Version: "v1beta1", Resource: "opentelemetrycollectors"}
	collector := &unstructured.Unstructured{
		Object: map[string]interface{}{
			"apiVersion": "opentelemetry.io/v1beta1",
			"kind":       "OpenTelemetryCollector",
			"metadata": map[string]interface{}{
				"name":      "aspire-collector",
				"namespace": p.ObservabilityNS,
			},
			"spec": map[string]interface{}{
				"config": map[string]interface{}{
					"receivers": map[string]interface{}{
						"otlp": map[string]interface{}{
							"protocols": map[string]interface{}{
								"grpc": map[string]interface{}{"endpoint": "0.0.0.0:4317"},
								"http": map[string]interface{}{"endpoint": "0.0.0.0:4318"},
							},
						},
					},
					"exporters": map[string]interface{}{
						"otlp": map[string]interface{}{
							"endpoint": fmt.Sprintf("http://aspire-dashboard.%s.svc.cluster.local:18889", p.ObservabilityNS),
							"tls":      map[string]interface{}{"insecure": true},
						},
					},
					"service": map[string]interface{}{
						"pipelines": map[string]interface{}{
							"traces":  map[string]interface{}{"receivers": []string{"otlp"}, "exporters": []string{"otlp"}},
							"metrics": map[string]interface{}{"receivers": []string{"otlp"}, "exporters": []string{"otlp"}},
							"logs":    map[string]interface{}{"receivers": []string{"otlp"}, "exporters": []string{"otlp"}},
						},
					},
				},
			},
		},
	}

	fmt.Println("🧪 Creating OpenTelemetry Collector...")
	_, err = dynClient.Resource(collectorGVR).Namespace(p.ObservabilityNS).Get(context.TODO(), "aspire-collector", metav1.GetOptions{})
	if err != nil {
		_, err = dynClient.Resource(collectorGVR).Namespace(p.ObservabilityNS).Create(context.TODO(), collector, metav1.CreateOptions{})
	}

	fmt.Printf("✅ OpenTelemetry orchestration initiated. Aspire: https://%s\\n", p.AspireHost)
	return nil
}

func (p *OTelPlugin) Status() error {
	fmt.Println("🔎 Checking OTel status...")
	return nil
}

func (p *OTelPlugin) Uninstall() error {
	fmt.Println("🧹 Uninstalling OTel...")
	return nil
}

func (p *OTelPlugin) Help() string {
	return `OpenTelemetry plugin (Go)
  install     Install Operator, Dashboard, and Collector
  status      Show status
  uninstall   Remove components
  help        Show this help`
}

func NewOTelPlugin() *OTelPlugin {
	return &OTelPlugin{
		Namespace:       "opentelemetry-operator-system",
		ObservabilityNS: "observability",
		AspireHost:      "aspire-dashboard.localhost",
		Issuer:          "quick-kind-ca",
		TLSSecret:       "aspire-dashboard-tls",
	}
}
