package main

import (
	"fmt"
	"os"

	"github.com/josephaw1022/superkind/pkg/config"
	"github.com/josephaw1022/superkind/pkg/engine"
	"github.com/spf13/cobra"
)

var upCmd = &cobra.Command{
	Use:   "up [name]",
	Short: "Create a SuperKind cluster",
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

		fmt.Printf("🚀 Starting SuperKind for cluster: %s\n", clusterName)

		if err := engine.EnsureLocalCA(cfg.ToPKIConfig()); err != nil {
			fmt.Printf("❌ %v\n", err)
			os.Exit(1)
		}

		if err := engine.EnsureLocalRegistry(cfg.ToDockerConfig()); err != nil {
			fmt.Printf("❌ %v\n", err)
			os.Exit(1)
		}

		if err := engine.EnsurePullThroughCaches(cfg.ToDockerConfig()); err != nil {
			fmt.Printf("❌ %v\n", err)
			os.Exit(1)
		}

		if err := engine.EnsureKindCluster(cfg.ToKindConfig(clusterName)); err != nil {
			fmt.Printf("❌ %v\n", err)
			os.Exit(1)
		}

		if err := engine.ConfigureKindNodes(cfg.ToKindConfig(clusterName)); err != nil {
			fmt.Printf("❌ %v\n", err)
			os.Exit(1)
		}

		if err := engine.EnsureRegistryConfigMap(cfg.ToK8sConfig(clusterName)); err != nil {
			fmt.Printf("❌ %v\n", err)
			os.Exit(1)
		}

		if err := engine.EnsureCertManager(); err != nil {
			fmt.Printf("❌ %v\n", err)
			os.Exit(1)
		}

		if err := engine.EnsureCASecretAndIssuer(cfg.ToK8sConfig(clusterName)); err != nil {
			fmt.Printf("❌ %v\n", err)
			os.Exit(1)
		}

		if err := engine.EnsureIngressNginx(); err != nil {
			fmt.Printf("❌ %v\n", err)
			os.Exit(1)
		}

		if err := engine.EnsurePrometheusStack(); err != nil {
			fmt.Printf("❌ %v\n", err)
			os.Exit(1)
		}

		fmt.Println("✅ SuperKind cluster is ready!")
	},
}

func init() {
	upCmd.Flags().StringP("name", "n", "", "Cluster name (will be prefixed with qk-)")
	rootCmd.AddCommand(upCmd)
}
