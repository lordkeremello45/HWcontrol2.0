package main

import (
	"os"
	"path/filepath"
	"testing"
	"time"
)

func TestBridgeKeyIntegrityDetectsModification(t *testing.T) {
	path := filepath.Join(t.TempDir(), "bridge.key")
	secret := "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef\n"
	if err := os.WriteFile(path, []byte(secret), 0600); err != nil {
		t.Fatalf("write key: %v", err)
	}

	critical := filepath.Join(t.TempDir(), "ai_engine")
	if err := os.WriteFile(critical, []byte("trusted-engine"), 0600); err != nil {
		t.Fatalf("write critical file: %v", err)
	}

	t.Setenv("HWCONTROL_KEY", "")
	t.Setenv("HWCONTROL_KEY_FILE", path)
	t.Setenv("HWCONTROL_INTEGRITY_FILES", critical)
	m, err := newBridgeIntegrityMonitor()
	if err != nil {
		t.Fatalf("create integrity monitor: %v", err)
	}
	defer m.stop()
	defer bridgeIntegrityState.Store(true)

	done := make(chan struct{})
	m.start(done, nil)

	if err := os.WriteFile(critical, []byte("tampered"), 0600); err != nil {
		t.Fatalf("modify critical file: %v", err)
	}

	deadline := time.Now().Add(bridgeIntegrityPollInterval + time.Second)
	for time.Now().Before(deadline) {
		if !m.healthy.Load() {
			close(done)
			return
		}
		time.Sleep(20 * time.Millisecond)
	}
	close(done)
	t.Fatal("expected critical integrity monitor to detect modification")
}

func TestBridgeKeyDigestRejectsSymlink(t *testing.T) {
	dir := t.TempDir()
	target := filepath.Join(dir, "target")
	link := filepath.Join(dir, "bridge.key")
	secret := "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef\n"
	if err := os.WriteFile(target, []byte(secret), 0600); err != nil {
		t.Fatalf("write target: %v", err)
	}
	if err := os.Symlink(target, link); err != nil {
		t.Skipf("symlink unavailable: %v", err)
	}
	if _, err := bridgeKeyDigest(link); err == nil {
		t.Fatal("expected symlink bridge key to be rejected")
	}
}

func TestIntegrityFileDigestRejectsSymlink(t *testing.T) {
	dir := t.TempDir()
	target := filepath.Join(dir, "engine")
	link := filepath.Join(dir, "critical")
	if err := os.WriteFile(target, []byte("trusted"), 0600); err != nil {
		t.Fatalf("write target: %v", err)
	}
	if err := os.Symlink(target, link); err != nil {
		t.Skipf("symlink unavailable: %v", err)
	}
	if _, err := integrityFileDigest(link); err == nil {
		t.Fatal("expected critical integrity target symlink to be rejected")
	}
}
