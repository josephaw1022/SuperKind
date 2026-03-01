package main

import (
	"bytes"
	"testing"
)

func TestPluginCommand_Help(t *testing.T) {
	cmd := pluginCmd
	b := bytes.NewBufferString("")
	cmd.SetOut(b)
	cmd.SetErr(b)
	
	// Test help output (no args)
	cmd.SetArgs([]string{})
	// We need to execute the root command if we want to test subcommands with args,
	// or just call RunE directly if we want to isolate.
	// Let's use the root command to ensure full integration.
	rootCmd.SetOut(b)
	rootCmd.SetArgs([]string{"plugin"})
	err := rootCmd.Execute()
	if err != nil {
		t.Fatalf("pluginCmd failed: %v", err)
	}
	
	output := b.String()
	// We should see some registered plugins in the help output
	if output == "" {
		t.Error("Expected plugin list output, got empty string")
	}
}
