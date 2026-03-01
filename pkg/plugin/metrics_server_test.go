package plugin

import (
	"testing"
)

func TestMetricsServerPlugin_Metadata(t *testing.T) {
	p := &MetricsServerPlugin{}
	if p.Name() != "metrics-server" {
		t.Errorf("Expected name metrics-server, got %s", p.Name())
	}
	if p.Help() == "" {
		t.Error("Help message should not be empty")
	}
}
