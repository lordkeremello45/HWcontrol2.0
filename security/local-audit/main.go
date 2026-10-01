// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 HWcontrol2.0 contributors

package main

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"
)

type Manifest struct {
	Files []ManifestFile `json:"files"`
}
type ManifestFile struct {
	Path string `json:"path"`
	SHA256 string `json:"sha256,omitempty"`
}
type Result struct {
	Path string `json:"path"`
	Status string `json:"status"`
	SHA256 string `json:"sha256,omitempty"`
	Issue string `json:"issue,omitempty"`
}

func withinRoot(root, target string) bool {
	rootAbs, err := filepath.Abs(root); if err != nil { return false }
	targetAbs, err := filepath.Abs(target); if err != nil { return false }
	rel, err := filepath.Rel(rootAbs, targetAbs)
	return err == nil && rel != ".." && !strings.HasPrefix(rel, ".."+string(os.PathSeparator))
}

func digestFile(path string) (string, error) {
	info, err := os.Lstat(path)
	if err != nil { return "", err }
	if info.Mode()&os.ModeSymlink != 0 { return "", errors.New("symlink is not accepted") }
	if !info.Mode().IsRegular() { return "", errors.New("target is not a regular file") }
	file, err := os.Open(path); if err != nil { return "", err }
	defer file.Close()
	hash := sha256.New()
	if _, err := io.Copy(hash, file); err != nil { return "", err }
	return hex.EncodeToString(hash.Sum(nil)), nil
}

func auditFile(root string, entry ManifestFile) Result {
	if strings.TrimSpace(entry.Path) == "" {
		return Result{Path: entry.Path, Status: "FAIL", Issue: "empty path"}
	}
	target := filepath.Join(root, filepath.FromSlash(entry.Path))
	if !withinRoot(root, target) {
		return Result{Path: entry.Path, Status: "FAIL", Issue: "path escapes audit root"}
	}
	digest, err := digestFile(target)
	if err != nil {
		return Result{Path: entry.Path, Status: "FAIL", Issue: err.Error()}
	}
	if expected := strings.ToLower(strings.TrimSpace(entry.SHA256)); expected != "" && digest != expected {
		return Result{Path: entry.Path, Status: "FAIL", SHA256: digest, Issue: "SHA-256 mismatch"}
	}
	return Result{Path: entry.Path, Status: "PASS", SHA256: digest}
}

func loadManifest(path string) (Manifest, error) {
	data, err := os.ReadFile(path); if err != nil { return Manifest{}, err }
	var manifest Manifest
	if err := json.Unmarshal(data, &manifest); err != nil { return Manifest{}, err }
	if len(manifest.Files) == 0 { return Manifest{}, errors.New("manifest contains no files") }
	return manifest, nil
}

func main() {
	root := flag.String("root", ".", "installation or source root to audit")
	manifestPath := flag.String("manifest", "", "JSON manifest containing files and optional SHA-256 values")
	jsonOutput := flag.Bool("json", false, "emit machine-readable JSON results")
	flag.Parse()

	if strings.TrimSpace(*manifestPath) == "" {
		fmt.Fprintln(os.Stderr, "manifest is required")
		os.Exit(2)
	}
	rootAbs, err := filepath.Abs(*root)
	if err != nil { fmt.Fprintln(os.Stderr, "invalid root:", err); os.Exit(2) }
	manifest, err := loadManifest(*manifestPath)
	if err != nil { fmt.Fprintln(os.Stderr, "invalid manifest:", err); os.Exit(2) }

	results := make([]Result, 0, len(manifest.Files))
	failed := false
	for _, entry := range manifest.Files {
		result := auditFile(rootAbs, entry)
		results = append(results, result)
		if result.Status != "PASS" { failed = true }
	}

	if *jsonOutput {
		encoder := json.NewEncoder(os.Stdout)
		encoder.SetIndent("", "  ")
		if err := encoder.Encode(results); err != nil { os.Exit(2) }
	} else {
		for _, result := range results {
			fmt.Printf("[%s] %s", result.Status, result.Path)
			if result.SHA256 != "" { fmt.Printf(" sha256=%s", result.SHA256) }
			if result.Issue != "" { fmt.Printf(" issue=%s", result.Issue) }
			fmt.Println()
		}
	}
	if failed { os.Exit(1) }
}
