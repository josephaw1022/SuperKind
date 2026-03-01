package main

import (
	"fmt"

	"github.com/josephaw1022/superkind/pkg/plugin"
	"github.com/spf13/cobra"
)

var pluginCmd = &cobra.Command{
	Use:   "plugin <name> [command]",
	Short: "Manage SuperKind plugins",
	RunE: func(cmd *cobra.Command, args []string) error {
		manager := plugin.DefaultPluginManager()

		if len(args) == 0 {
			fmt.Fprintln(cmd.OutOrStdout(), "Available plugins:")
			plugins, err := manager.ListPlugins()
			if err != nil {
				return fmt.Errorf("failed to list plugins: %w", err)
			}
			for _, p := range plugins {
				fmt.Fprintf(cmd.OutOrStdout(), "  - %s\\n", p)
			}
			fmt.Fprintln(cmd.OutOrStdout(), "\\nExamples:")
			fmt.Fprintln(cmd.OutOrStdout(), "  superkind plugin epinio install")
			fmt.Fprintln(cmd.OutOrStdout(), "  superkind plugin olm status")
			return nil
		}

		pluginName := args[0]
		pluginArgs := args[1:]
		if err := manager.RunPlugin(pluginName, pluginArgs); err != nil {
			return err
		}
		return nil
	},
}

func init() {
	rootCmd.AddCommand(pluginCmd)
}
