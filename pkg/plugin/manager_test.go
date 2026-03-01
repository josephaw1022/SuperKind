package plugin

import (
	"testing"
)

type mockPlugin struct {
	name string
}

func (p *mockPlugin) Name() string     { return p.name }
func (p *mockPlugin) Install() error   { return nil }
func (p *mockPlugin) Status() error    { return nil }
func (p *mockPlugin) Uninstall() error { return nil }
func (p *mockPlugin) Help() string     { return "mock help" }

func TestPluginManager_RegisterAndList(t *testing.T) {
	m := &PluginManager{
		goPlugins: make(map[string]Plugin),
	}

	p1 := &mockPlugin{name: "plugin1"}
	p2 := &mockPlugin{name: "plugin2"}

	m.RegisterGoPlugin(p1)
	m.RegisterGoPlugin(p2)

	plugins, err := m.ListPlugins()
	if err != nil {
		t.Fatalf("ListPlugins failed: %v", err)
	}

	if len(plugins) != 2 {
		t.Errorf("Expected 2 plugins, got %d", len(plugins))
	}

	if plugins[0] != "plugin1" || plugins[1] != "plugin2" {
		t.Errorf("Unexpected plugin list: %v", plugins)
	}
}

func TestPluginManager_RunPlugin(t *testing.T) {
	m := &PluginManager{
		goPlugins: make(map[string]Plugin),
	}

	p := &mockPlugin{name: "test"}
	m.RegisterGoPlugin(p)

	err := m.RunPlugin("test", []string{"install"})
	if err != nil {
		t.Errorf("RunPlugin failed: %v", err)
	}

	err = m.RunPlugin("nonexistent", []string{"install"})
	if err == nil {
		t.Error("Expected error for nonexistent plugin, got nil")
	}
}
