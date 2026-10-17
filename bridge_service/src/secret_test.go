package main

import (
	"fmt"
	"os"
	"path/filepath"
	"runtime"
	"testing"
)

func TestValidBridgeSecret(t *testing.T) {
	valid := "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
	for _, secret := range []string{valid} {
		if !validBridgeSecret(secret) {
			t.Fatalf("expected valid secret to pass validation")
		}
	}
	for _, secret := range []string{"", "replace-me", "short", valid + "0", "zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz"} {
		if validBridgeSecret(secret) {
			t.Fatalf("expected invalid secret to fail validation: %q", secret)
		}
	}
}

func TestLoadOrCreateSecretRejectsInvalidConfiguredKey(t *testing.T) {
	t.Setenv("HWCONTROL_KEY", "short")
	t.Setenv("HWCONTROL_KEY_FILE", filepath.Join(t.TempDir(), "bridge.key"))
	if _, err := loadOrCreateSecret(); err == nil {
		t.Fatal("expected invalid HWCONTROL_KEY to be rejected")
	}
}

func TestLoadOrCreateSecretRejectsUnsafeKeyFile(t *testing.T) {
	if runtime.GOOS == "windows" {
		t.Skip("file mode checks are POSIX-specific")
	}
	secret := "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
	for _, mode := range []os.FileMode{0640, 0644, 0660, 0666} {
		t.Run(fmt.Sprintf("%04o", mode.Perm()), func(t *testing.T) {
			path := filepath.Join(t.TempDir(), "bridge.key")
			if err := os.WriteFile(path, []byte(secret+"\n"), 0600); err != nil {
				t.Fatalf("write test key: %v", err)
			}
			if err := os.Chmod(path, mode); err != nil {
				t.Fatalf("chmod test key: %v", err)
			}
			t.Setenv("HWCONTROL_KEY", "")
			t.Setenv("HWCONTROL_KEY_FILE", path)
			if _, err := loadOrCreateSecret(); err == nil {
				t.Fatalf("expected key file with mode %04o to be rejected", mode.Perm())
			}
		})
	}
}

func TestValidateKeyFilePathRejectsNonRegularFile(t *testing.T) {
	path := filepath.Join(t.TempDir(), "key-directory")
	if err := os.Mkdir(path, 0700); err != nil {
		t.Fatal(err)
	}
	if err := validateKeyFilePath(path); err == nil {
		t.Fatal("expected a directory to be rejected as a bridge key file")
	}
}
