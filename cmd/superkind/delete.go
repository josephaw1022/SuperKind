package main

import (
	"fmt"

	"github.com/josephaw1022/superkind/pkg/config"
	"github.com/josephaw1022/superkind/pkg/engine"
	"github.com/spf13/cobra"
	"sigs.k8s.io/kind/pkg/cluster"
)

var deleteCmd = &cobra.Command{
	Use:     "delete [name]",
	Aliases: []string{"teardown", "down"},
	Short:   "Delete a SuperKind cluster",
	Run: func(cmd *cobra.Command, args []string) {
		cfg := config.DefaultConfig()
		clusterName := cfg.NamePrefix + cfg.DefaultBaseName
		if len(args) > 0 {
			clusterName = cfg.NamePrefix + args[0]
		}
		nameFlag, _ := cmd.Flags().GetString("name")
		if nameFlag != "" {
			clusterName = cfg.NamePrefix + nameFlag
		}

		fmt.Printf("🧹 Deleting kind cluster '%s'...\n", clusterName)
		provider := cluster.NewProvider(engine.GetKindProvider())
		if err := provider.Delete(clusterName, ""); err != nil {
			fmt.Printf("⚠️  Cluster not found or deletion failed: %v\n", err)
		} else {
			fmt.Printf("✅ Cluster '%s' deleted.\n", clusterName)
		}
		fmt.Printf("ℹ️  Leaving local registry & caches running (for speed).\n")
	},
}

func init() {
	deleteCmd.Flags().StringP("name", "n", "", "Cluster name")
	rootCmd.AddCommand(deleteCmd)
}
