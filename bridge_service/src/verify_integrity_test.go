package main

import (
	"os"
	"path/filepath"
	"testing"
)

func TestVerifyRecordsDetectUnexpectedFile(t *testing.T) {
	dir := t.TempDir()
	first := filepath.Join(dir, "bridge-service.exe")
	second := filepath.Join(dir, "security-guardian.exe")
	if err := os.WriteFile(first, []byte("trusted"), 0600); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(second, []byte("trusted"), 0600); err != nil {
		t.Fatal(err)
	}
	expected, err := collectVerifyInventory(dir)
	if err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(dir, "unexpected.bin"), []byte("unexpected"), 0600); err != nil {
		t.Fatal(err)
	}
	actual, err := collectVerifyInventory(dir)
	if err != nil {
		t.Fatal(err)
	}
	if verifyRecordsEqual(expected, actual) {
		t.Fatal("expected unexpected file to change installation inventory")
	}
}

func TestVerifyRecordsDetectModification(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "bridge-service.exe")
	if err := os.WriteFile(path, []byte("trusted"), 0600); err != nil {
		t.Fatal(err)
	}
	expected, err := collectVerifyInventory(dir)
	if err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(path, []byte("tampered"), 0600); err != nil {
		t.Fatal(err)
	}
	actual, err := collectVerifyInventory(dir)
	if err != nil {
		t.Fatal(err)
	}
	if verifyRecordsEqual(expected, actual) {
		t.Fatal("expected modified file to change installation inventory")
	}
}
