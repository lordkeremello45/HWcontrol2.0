// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 HWcontrol2.0 contributors

package main

import (
	"os"
	"path/filepath"
	"testing"
)

func TestAuditFileAcceptsExpectedDigest(t *testing.T) {
	root := t.TempDir()
	target := filepath.Join(root, "bridge-service")
	if err := os.WriteFile(target, []byte("trusted"), 0600); err != nil { t.Fatal(err) }
	result := auditFile(root, ManifestFile{
		Path: "bridge-service",
		SHA256: "a9a089195c68d2adeee23beaa2c3a93b1d4cdf09046e7a9e520b3b166dff3e6a",
	})
	if result.Status != "PASS" { t.Fatalf("expected digest verification to pass, got %+v", result) }
}

func TestAuditFileRejectsSymlink(t *testing.T) {
	root := t.TempDir()
	target := filepath.Join(root, "target")
	link := filepath.Join(root, "link")
	if err := os.WriteFile(target, []byte("content"), 0600); err != nil { t.Fatal(err) }
	if err := os.Symlink(target, link); err != nil { t.Skip("symlinks unavailable") }
	result := auditFile(root, ManifestFile{Path: "link"})
	if result.Status != "FAIL" { t.Fatalf("expected symlink rejection, got %+v", result) }
}

func TestAuditFileRejectsPathEscape(t *testing.T) {
	root := t.TempDir()
	result := auditFile(root, ManifestFile{Path: "../outside"})
	if result.Status != "FAIL" { t.Fatalf("expected path escape rejection, got %+v", result) }
}
