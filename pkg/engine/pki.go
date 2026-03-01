package engine

import (
	"crypto/rand"
	"crypto/rsa"
	"crypto/x509"
	"crypto/x509/pkix"
	"encoding/pem"
	"fmt"
	"math/big"
	"os"
	"path/filepath"
	"time"
)

type PKIConfig struct {
	CADir      string
	CAKey      string
	CACrt      string
	CACN       string
	CAOrg      string
	CAOU       string
	CADays     int
}

func EnsureLocalCA(cfg PKIConfig) error {
	// Check if CA files exist and are not empty
	if _, err := os.Stat(cfg.CAKey); err == nil {
		if _, err := os.Stat(cfg.CACrt); err == nil {
			fmt.Printf("🔐 Reusing existing local CA at %s\n", cfg.CADir)
			return nil
		}
	}

	fmt.Println("🔐 Generating local Root CA...")
	if err := os.MkdirAll(cfg.CADir, 0755); err != nil {
		return fmt.Errorf("failed to create CA directory: %w", err)
	}

	// Generate Private Key
	priv, err := rsa.GenerateKey(rand.Reader, 4096)
	if err != nil {
		return fmt.Errorf("failed to generate private key: %w", err)
	}

	// Setup CA certificate template
	serialNumber, err := rand.Int(rand.Reader, new(big.Int).Lsh(big.NewInt(1), 128))
	if err != nil {
		return fmt.Errorf("failed to generate serial number: %w", err)
	}

	notBefore := time.Now()
	notAfter := notBefore.Add(time.Duration(cfg.CADays) * 24 * time.Hour)

	template := x509.Certificate{
		SerialNumber: serialNumber,
		Subject: pkix.Name{
			CommonName:         cfg.CACN,
			Organization:       []string{cfg.CAOrg},
			OrganizationalUnit: []string{cfg.CAOU},
		},
		NotBefore:             notBefore,
		NotAfter:              notAfter,
		KeyUsage:              x509.KeyUsageCertSign | x509.KeyUsageCRLSign,
		BasicConstraintsValid: true,
		IsCA:                  true,
	}

	// Create Certificate
	derBytes, err := x509.CreateCertificate(rand.Reader, &template, &template, &priv.PublicKey, priv)
	if err != nil {
		return fmt.Errorf("failed to create certificate: %w", err)
	}

	// Write Private Key (PEM)
	keyOut, err := os.OpenFile(cfg.CAKey, os.O_WRONLY|os.O_CREATE|os.O_TRUNC, 0600)
	if err != nil {
		return fmt.Errorf("failed to open key file for writing: %w", err)
	}
	defer keyOut.Close()
	if err := pem.Encode(keyOut, &pem.Block{Type: "RSA PRIVATE KEY", Bytes: x509.MarshalPKCS1PrivateKey(priv)}); err != nil {
		return fmt.Errorf("failed to encode private key: %w", err)
	}

	// Write Certificate (PEM)
	certOut, err := os.Create(cfg.CACrt)
	if err != nil {
		return fmt.Errorf("failed to open cert file for writing: %w", err)
	}
	defer certOut.Close()
	if err := pem.Encode(certOut, &pem.Block{Type: "CERTIFICATE", Bytes: derBytes}); err != nil {
		return fmt.Errorf("failed to encode certificate: %w", err)
	}

	fmt.Printf("✅ Root CA created: %s\n", cfg.CACrt)
	return nil
}

func DefaultPKIConfig() PKIConfig {
	home, _ := os.UserHomeDir()
	caDir := filepath.Join(home, ".local/share/quick-kind/ca")
	return PKIConfig{
		CADir:  caDir,
		CAKey:  filepath.Join(caDir, "rootCA.key"),
		CACrt:  filepath.Join(caDir, "rootCA.crt"),
		CACN:   "Quick Kind Local CA",
		CAOrg:  "Quick Kind",
		CAOU:   "Dev",
		CADays: 3650,
	}
}
