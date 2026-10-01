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
	if err := os.MkdirAll(filepath.Dir(canaryPath()), 0750); err != nil { t.Fatal(err) }
	target := filepath.Join(dir, "target")
	if err := os.WriteFile(target, []byte("not the canary"), 0600); err != nil {
		t.Fatal(err)
	}
	if err := os.Symlink(target, canaryPath()); err != nil {
		t.Fatal(err)
	}
	if _, err := digest(canaryPath()); err == nil {
		t.Fatal("expected symlink canary to be rejected")
	}
}
