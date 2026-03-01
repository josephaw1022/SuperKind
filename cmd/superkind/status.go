package main

import (
	"fmt"
	"log"
	"os"

	"github.com/josephaw1022/superkind/pkg/config"
	"github.com/josephaw1022/superkind/pkg/engine"
	"github.com/spf13/cobra"
	"helm.sh/helm/v3/pkg/action"
	"helm.sh/helm/v3/pkg/cli"
	"sigs.k8s.io/kind/pkg/cluster"
)

var statusCmd = &cobra.Command{
	Use:   "status [name]",
	Short: "Show status of a SuperKind cluster",
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

		fmt.Printf("🔍 Checking status for: %s\n", clusterName)

		// Kind check
		provider := cluster.NewProvider(engine.GetKindProvider())
		clusters, _ := provider.List()
		running := false
		for _, c := range clusters {
			if c == clusterName {
				running = true
				break
			}
		}

		if !running {
			fmt.Printf("❌ Kind cluster '%s' not found.\n", clusterName)
		} else {
			fmt.Printf("✅ Kind cluster '%s' is running.\n", clusterName)
		}

		// Docker/Podman check
		engineInstance, err := engine.GetContainerEngine()
		if err == nil {
			fmt.Printf("\n🗄️  Local registry & caches status:\n")
			containers := []string{
				cfg.LocalRegistryName,
				cfg.DockerHubCacheName,
				cfg.QuayCacheName,
				cfg.GHCRCacheName,
				cfg.MCRCacheName,
			}
			
			fmt.Printf("%-25s %-20s\n", "NAMES", "STATUS")
			for _, name := range containers {
				status := "Stopped/Missing"
				if engineInstance.IsContainerRunning(name) {
					status = "Running"
				}
				fmt.Printf("%-25s %-20s\n", name, status)
			}
		}

		// Helm check
		fmt.Printf("\n🔍 Helm releases:\n")
		settings := cli.New()
		actionConfig := new(action.Configuration)
		if err := actionConfig.Init(settings.RESTClientGetter(), settings.Namespace(), os.Getenv("HELM_DRIVER"), log.Printf); err == nil {
			listAction := action.NewList(actionConfig)
			listAction.AllNamespaces = true
			releases, _ := listAction.Run()
			fmt.Printf("%-25s %-20s %-25s %-15s\n", "NAME", "NAMESPACE", "CHART", "STATUS")
			for _, rel := range releases {
				fmt.Printf("%-25s %-20s %-25s %-15s\n", rel.Name, rel.Namespace, rel.Chart.Metadata.Name, rel.Info.Status)
			}
		}
	},
}

func init() {
	statusCmd.Flags().StringP("name", "n", "", "Cluster name")
	rootCmd.AddCommand(statusCmd)
}
