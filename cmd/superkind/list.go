package main

import (
	"fmt"
	"strings"

	"github.com/josephaw1022/superkind/pkg/config"
	"github.com/josephaw1022/superkind/pkg/engine"
	"github.com/spf13/cobra"
	"sigs.k8s.io/kind/pkg/cluster"
)

var listCmd = &cobra.Command{
	Use:     "list",
	Aliases: []string{"ls"},
	Short:   "List SuperKind clusters",
	RunE: func(cmd *cobra.Command, args []string) error {
		cfg := config.DefaultConfig()
		prefix := cfg.NamePrefix

		provider := cluster.NewProvider(engine.GetKindProvider())
		clusters, err := provider.List()
		if err != nil {
			return fmt.Errorf("failed to list Kind clusters: %w", err)
		}

		fmt.Fprintf(cmd.OutOrStdout(), "📚 SuperKind clusters (prefixed '%s'):\n", prefix)
		
		found := false
		for _, c := range clusters {
			if strings.HasPrefix(c, prefix) {
				fmt.Fprintf(cmd.OutOrStdout(), "  - %s\n", c)
				found = true
			}
		}

		if !found {
			fmt.Fprintln(cmd.OutOrStdout(), "  (none found)")
		}
		return nil
	},
}

func init() {
	rootCmd.AddCommand(listCmd)
}
