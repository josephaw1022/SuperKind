package plugin

import (
	"testing"
)

func TestPlugins_Metadata(t *testing.T) {
	plugins := []Plugin{
		NewArgoCDPlugin(),
		NewAWXPlugin(),
		NewEpinioPlugin(),
		NewESOPlugin(),
		NewGatewayAPIPlugin(),
		NewKEDAPlugin(),
		NewKyvernoPlugin(),
		NewOLMPlugin(),
		NewOTelPlugin(),
		NewTektonPlugin(),
		NewVeleroPlugin(),
	}

	for _, p := range plugins {
		t.Run(p.Name(), func(t *testing.T) {
			if p.Name() == "" {
				t.Error("Plugin name should not be empty")
			}
			if p.Help() == "" {
				t.Error("Plugin help should not be empty")
			}
		})
	}
}
