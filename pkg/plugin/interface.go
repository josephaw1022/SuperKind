package plugin

type Plugin interface {
	Name() string
	Install() error
	Status() error
	Uninstall() error
	Help() string
}
