package plugin

import (
	"testing"
)

func TestVPAPlugin_Metadata(t *testing.T) {
	p := NewVPAPlugin()
	if p.Name() != "vpa" {
		t.Errorf("Expected name vpa, got %s", p.Name())
	}
	if p.Help() == "" {
		t.Error("Help message should not be empty")
	}
}
