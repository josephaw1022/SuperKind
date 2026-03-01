package main

import (
	"context"
	"fmt"
	"log"
	"os"

	"github.com/docker/docker/api/types"
	"github.com/docker/docker/client"
	"github.com/josephaw1022/superkind/pkg/config"
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

		fmt.Printf("🔍 Checking status for: %s\\n", clusterName)

		// Kind check
		provider := cluster.NewProvider(cluster.ProviderWithDocker())
		clusters, _ := provider.List()
		running := false
		for _, c := range clusters {
			if c == clusterName {
				running = true
				break
			}
		}

		if !running {
			fmt.Printf("❌ Kind cluster '%s' not found.\\n", clusterName)
			return
		}
		fmt.Printf("✅ Kind cluster '%s' is running.\\n", clusterName)

		// Docker check
		ctx := context.Background()
		cliDocker, err := client.NewClientWithOpts(client.FromEnv, client.WithAPIVersionNegotiation())
		if err == nil {
			defer cliDocker.Close()
			fmt.Printf("\\n🗄️  Local registry & caches (docker ps):\\n")
			containers := map[string]bool{
				cfg.LocalRegistryName:  true,
				cfg.DockerHubCacheName: true,
				cfg.QuayCacheName:      true,
				cfg.GHCRCacheName:      true,
				cfg.MCRCacheName:       true,
			}
			
			list, _ := cliDocker.ContainerList(ctx, types.ContainerListOptions{All: true})
			fmt.Printf("%-25s %-20s %-30s\\n", "NAMES", "STATUS", "PORTS")
			for _, ctr := range list {
				for _, name := range ctr.Names {
					trimmedName := name[1:] // Remove leading slash
					if containers[trimmedName] {
						fmt.Printf("%-25s %-20s %-30v\\n", trimmedName, ctr.Status, ctr.Ports)
						break
					}
				}
			}
		}

		// Helm check
		fmt.Printf("\\n🔍 Helm releases:\\n")
		settings := cli.New()
		actionConfig := new(action.Configuration)
		if err := actionConfig.Init(settings.RESTClientGetter(), settings.Namespace(), os.Getenv("HELM_DRIVER"), log.Printf); err == nil {
			listAction := action.NewList(actionConfig)
			listAction.AllNamespaces = true
			releases, _ := listAction.Run()
			fmt.Printf("%-25s %-20s %-25s %-15s\\n", "NAME", "NAMESPACE", "CHART", "STATUS")
			for _, rel := range releases {
				fmt.Printf("%-25s %-20s %-25s %-15s\\n", rel.Name, rel.Namespace, rel.Chart.Metadata.Name, rel.Info.Status)
			}
		}
	},
}

func init() {
	statusCmd.Flags().StringP("name", "n", "", "Cluster name")
	rootCmd.AddCommand(statusCmd)
}
