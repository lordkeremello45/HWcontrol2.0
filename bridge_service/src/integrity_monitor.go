package main

import (
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"runtime"
	"strings"
	"sync"
	"sync/atomic"
	"time"
)

const bridgeIntegrityPollInterval = 2 * time.Second

type integrityTarget struct {
	path     string
	baseline string
}

type bridgeIntegrityMonitor struct {
	targets  []integrityTarget
	stopCh   chan struct{}
	stopOnce sync.Once
	healthy  atomic.Bool
}

func newBridgeIntegrityMonitor() (*bridgeIntegrityMonitor, error) {
	// Explicit environment provisioning is outside the file-integrity model.
	// There is no authoritative file to monitor in this mode.
	if secret := os.Getenv("HWCONTROL_KEY"); secret != "" && secret != "replace-me" {
		return nil, nil
	}

	keyPath := defaultKeyFile()
	if err := validateKeyFilePath(keyPath); err != nil {
		return nil, err
	}
	keyDigest, err := bridgeKeyDigest(keyPath)
	if err != nil {
		return nil, fmt.Errorf("establish bridge key integrity baseline: %w", err)
	}

	paths := []string{keyPath}
	paths = append(paths, criticalIntegrityPaths()...)

	targets := make([]integrityTarget, 0, len(paths))
	seen := make(map[string]struct{}, len(paths))
	for _, path := range paths {
		path = filepath.Clean(strings.TrimSpace(path))
		if path == "" {
			continue
		}
		if _, ok := seen[path]; ok {
			continue
		}
		seen[path] = struct{}{}

		var digest string
		if path == keyPath {
			digest = keyDigest
		} else {
			var err error
			digest, err = integrityFileDigest(path)
			if err != nil {
				return nil, fmt.Errorf("establish integrity baseline for %s: %w", filepath.Base(path), err)
			}
		}
		targets = append(targets, integrityTarget{path: path, baseline: digest})
	}

	bridgeIntegrityState.Store(true)
	m := &bridgeIntegrityMonitor{
		targets: targets,
		stopCh: make(chan struct{}),
	}
	m.healthy.Store(true)
	return m, nil
}

// criticalIntegrityPaths returns executable/library paths that are part of the
// local runtime. The bridge itself is always included. Additional critical
// binaries/libraries can be supplied by the installer through
// HWCONTROL_INTEGRITY_FILES using the platform path-list separator.
//
// This is intentionally an allow-list: the monitor never recursively hashes an
// installation directory, which would make updates noisy and could introduce
// denial-of-service behavior from unexpectedly large trees.
func criticalIntegrityPaths() []string {
	paths := make([]string, 0, 4)
	if executable, err := os.Executable(); err == nil {
		if resolved, err := filepath.EvalSymlinks(executable); err == nil {
			paths = append(paths, resolved)
		} else {
			paths = append(paths, executable)
		}
	}

	base := ""
	if len(paths) > 0 {
		base = filepath.Dir(paths[0])
	}
	if base != "" {
		aiName := "ai_engine"
		if runtime.GOOS == "windows" {
			aiName += ".exe"
		}
		aiPath := filepath.Join(base, aiName)
		if _, err := os.Lstat(aiPath); err == nil {
			paths = append(paths, aiPath)
		}
	}

	if configured := strings.TrimSpace(os.Getenv("HWCONTROL_INTEGRITY_FILES")); configured != "" {
		paths = append(paths, filepath.SplitList(configured)...)
	}
	return paths
}

func bridgeKeyDigest(path string) (string, error) {
	info, err := os.Lstat(path)
	if err != nil {
		return "", err
	}
	if info.Mode()&os.ModeSymlink != 0 {
		return "", fmt.Errorf("bridge key must not be a symlink")
	}
	if !info.Mode().IsRegular() {
		return "", fmt.Errorf("bridge key must be a regular file")
	}

	data, err := os.ReadFile(path)
	if err != nil {
		return "", err
	}
	if !validBridgeSecret(strings.TrimSpace(string(data))) {
		return "", fmt.Errorf("bridge key contains an invalid secret")
	}

	sum := sha256.Sum256(data)
	return hex.EncodeToString(sum[:]), nil
}

func integrityFileDigest(path string) (string, error) {
	info, err := os.Lstat(path)
	if err != nil {
		return "", err
	}
	if info.Mode()&os.ModeSymlink != 0 {
		return "", fmt.Errorf("critical integrity target must not be a symlink: %s", filepath.Base(path))
	}
	if !info.Mode().IsRegular() {
		return "", fmt.Errorf("critical integrity target must be a regular file: %s", filepath.Base(path))
	}
	file, err := os.Open(path)
	if err != nil {
		return "", err
	}
	defer file.Close()

	hasher := sha256.New()
	if _, err := io.Copy(hasher, file); err != nil {
		return "", err
	}
	return hex.EncodeToString(hasher.Sum(nil)), nil
}

func (m *bridgeIntegrityMonitor) start(done <-chan struct{}, onViolation func(error)) {
	go func() {
		ticker := time.NewTicker(bridgeIntegrityPollInterval)
		defer ticker.Stop()

		for {
			select {
			case <-done:
				return
			case <-m.stopCh:
				return
			case <-ticker.C:
				for _, target := range m.targets {
					digest, err := integrityFileDigest(target.path)
					if err != nil {
						m.violate(fmt.Errorf("critical integrity target %s is missing or invalid: %w", filepath.Base(target.path), err), onViolation)
						return
					}
					if digest != target.baseline {
						m.violate(fmt.Errorf("critical integrity target %s content changed", filepath.Base(target.path)), onViolation)
						return
					}
				}
			}
		}
	}()
}

func (m *bridgeIntegrityMonitor) violate(reason error, onViolation func(error)) {
	if m.healthy.Swap(false) {
		bridgeIntegrityState.Store(false)
		if onViolation != nil {
			onViolation(reason)
		}
	}
}

func (m *bridgeIntegrityMonitor) stop() {
	if m == nil {
		return
	}
	m.stopOnce.Do(func() { close(m.stopCh) })
}

func bridgeIntegrityHealthy() bool {
	return bridgeIntegrityState.Load()
}

var bridgeIntegrityState atomic.Bool

func init() {
	bridgeIntegrityState.Store(true)
}
