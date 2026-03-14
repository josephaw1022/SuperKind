package plugin

import (
	"fmt"
	"sort"
)

type PluginManager struct {
	goPlugins map[string]Plugin
}

func (m *PluginManager) RegisterGoPlugin(p Plugin) {
	if m.goPlugins == nil {
		m.goPlugins = make(map[string]Plugin)
	}
	m.goPlugins[p.Name()] = p
}

func (m *PluginManager) ListPlugins() ([]string, error) {
	var plugins []string
	for name := range m.goPlugins {
		plugins = append(plugins, name)
	}
	sort.Strings(plugins)
	return plugins, nil
}

func (m *PluginManager) RunPlugin(name string, args []string) error {
	p, ok := m.goPlugins[name]
	if !ok {
		return fmt.Errorf("plugin not found: %s", name)
	}

	action := "install"
	if len(args) > 0 {
		action = args[0]
	}

	switch action {
	case "install":
		return p.Install()
	case "status":
		return p.Status()
	case "uninstall":
		return p.Uninstall()
	case "help":
		fmt.Println(p.Help())
		return nil
	case "password":
		if ap, ok := p.(interface{ Password() error }); ok {
			return ap.Password()
		}
		fallthrough
	default:
		fmt.Printf("Unknown action: %s\n", action)
		fmt.Println(p.Help())
		return nil
	}
}

func DefaultPluginManager() *PluginManager {
	m := &PluginManager{
		goPlugins: make(map[string]Plugin),
	}
	m.RegisterGoPlugin(&MetricsServerPlugin{})
	m.RegisterGoPlugin(NewArgoCDPlugin())
	m.RegisterGoPlugin(NewKEDAPlugin())
	m.RegisterGoPlugin(NewKyvernoPlugin())
	m.RegisterGoPlugin(NewTektonPlugin())
	m.RegisterGoPlugin(NewESOPlugin())
	m.RegisterGoPlugin(NewOLMPlugin())
	m.RegisterGoPlugin(NewOTelPlugin())
	m.RegisterGoPlugin(NewVeleroPlugin())
	m.RegisterGoPlugin(NewEpinioPlugin())
	m.RegisterGoPlugin(NewAWXPlugin())
	m.RegisterGoPlugin(NewGatewayAPIPlugin())
	m.RegisterGoPlugin(NewVPAPlugin())
	// We will register other plugins here as we implement them
	return m
}
