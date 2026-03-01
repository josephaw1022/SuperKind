package engine

import (
	"os"
	"path/filepath"
	"testing"
)

func TestEnsureLocalCA(t *testing.T) {
	tmpDir, err := os.MkdirTemp("", "superkind-test-*")
	if err != nil {
		t.Fatal(err)
	}
	defer os.RemoveAll(tmpDir)

	cfg := PKIConfig{
		CADir:  tmpDir,
		CAKey:  filepath.Join(tmpDir, "rootCA.key"),
		CACrt:  filepath.Join(tmpDir, "rootCA.crt"),
		CACN:   "Test CA",
		CAOrg:  "Test Org",
		CAOU:   "Test OU",
		CADays: 1,
	}

	err = EnsureLocalCA(cfg)
	if err != nil {
		t.Fatalf("EnsureLocalCA failed: %v", err)
	}

	if _, err := os.Stat(cfg.CAKey); os.IsNotExist(err) {
		t.Error("CA key file not created")
	}
	if _, err := os.Stat(cfg.CACrt); os.IsNotExist(err) {
		t.Error("CA cert file not created")
	}

	// Test reuse
	err = EnsureLocalCA(cfg)
	if err != nil {
		t.Fatalf("EnsureLocalCA failed on reuse: %v", err)
	}
}
