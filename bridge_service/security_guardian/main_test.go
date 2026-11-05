package main

import (
	"os"
	"path/filepath"
	"testing"
)

func TestGuardianAcceptsCanonicalCanary(t *testing.T) {
	dir := t.TempDir()
	t.Setenv("HWCONTROL_DECOY_DIR", dir)
	path := filepath.Join(dir, canaryName)
	if err := os.WriteFile(path, []byte("0526be8dc7adb18bc4e82119046c9a9fc8625571311060208a8d0744d71ff671\n"), 0440); err != nil {
		t.Fatal(err)
	}
	got, err := digest(path)
	if err != nil {
		t.Fatal(err)
	}
	if got != expectedCanaryDigest {
		t.Fatalf("digest = %s, want %s", got, expectedCanaryDigest)
	}
}

func TestGuardianRejectsSymlinkCanary(t *testing.T) {
	dir := t.TempDir()
	t.Setenv("HWCONTROL_DECOY_DIR", dir)
	if err := os.MkdirAll(filepath.Dir(canaryPath()), 0750); err != nil {
		t.Fatal(err)
	}
	target := filepath.Join(dir, "target")
	if err := os.WriteFile(target, []byte("not the canary"), 0600); err != nil {
		t.Fatal(err)
	}
	if err := os.Symlink(target, canaryPath()); err != nil {
		t.Skipf("symlink creation unavailable on this platform: %v", err)
	}
	if _, err := digest(canaryPath()); err == nil {
		t.Fatal("expected symlink canary to be rejected")
	}
}

func TestGuardianDetectsModifiedCanary(t *testing.T) {
	dir := t.TempDir()
	securityDir := filepath.Join(dir, "security")
	t.Setenv("HWCONTROL_DECOY_DIR", securityDir)
	t.Setenv("HWCONTROL_PANIC_FILE", filepath.Join(securityDir, "state", "panic-mode.json"))
	if err := os.MkdirAll(filepath.Dir(canaryPath()), 0750); err != nil {
		t.Fatal(err)
	}
	canonical := []byte("0526be8dc7adb18bc4e82119046c9a9fc8625571311060208a8d0744d71ff671\n")
	if err := os.WriteFile(canaryPath(), canonical, 0440); err != nil {
		t.Fatal(err)
	}
	baseline, err := initializeGuardian()
	if err != nil {
		t.Fatal(err)
	}
	if err := os.Chmod(canaryPath(), 0600); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(canaryPath(), []byte("tampered\n"), 0600); err != nil {
		t.Fatal(err)
	}
	if err := checkGuardianCanary(baseline); err == nil {
		t.Fatal("expected modified canary to fail integrity verification")
	}
	if _, err := os.Stat(panicPath()); err != nil {
		t.Fatalf("expected panic state to be written: %v", err)
	}
}
