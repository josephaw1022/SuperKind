package main

import (
	"fmt"
	"os"

	"github.com/spf13/cobra"
)

var rootCmd = &cobra.Command{
	Use:   "superkind",
	Short: "SuperKind is a super-charged Kind wrapper with local registries and CA.",
	Long: `SuperKind is an opinionated, plugin-based wrapper for kind (Kubernetes in Docker). 
It automates the setup of essential infrastructure like Ingress, Cert-Manager, Registries, and Caching.`,
	Run: func(cmd *cobra.Command, args []string) {
		// Default behavior: show help or status
		if len(args) == 0 {
			cmd.Help()
		}
	},
}

func main() {
	if err := rootCmd.Execute(); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}
