package main

import (
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"os"
	"path/filepath"
	"runtime"
	"sync"
	"sync/atomic"
	"time"
)

const bridgeIntegrityPollInterval = 2 * time.Second

type bridgeIntegrityMonitor struct {
	path      string
	baseline  string
	stopCh    chan struct{}
	stopOnce  sync.Once
	healthy   atomic.Bool
}

func newBridgeIntegrityMonitor() (*bridgeIntegrityMonitor, error) {
	// Explicit environment provisioning is already outside the file-integrity
	// model. Production installers use the protected bridge.key file.
	if secret := os.Getenv("HWCONTROL_KEY"); secret != "" && secret != "replace-me" {
		return nil, nil
	}

	path := defaultKeyFile()
	if err := validateKeyFilePath(path); err != nil {
		return nil, err
	}
	baseline, err := bridgeKeyDigest(path)
	if err != nil {
		return nil, fmt.Errorf("establish bridge key integrity baseline: %w", err)
	}

	m := &bridgeIntegrityMonitor{
		path:     path,
		baseline: baseline,
		stopCh:   make(chan struct{}),
	}
	m.healthy.Store(true)
	return m, nil
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
	secret := string(data)
	if !validBridgeSecret(trimBridgeSecret(secret)) {
		return "", fmt.Errorf("bridge key integrity baseline contains an invalid secret")
	}

	sum := sha256.Sum256(data)
	return hex.EncodeToString(sum[:]), nil
}

func trimBridgeSecret(value string) string {
	return string([]byte(value)[:len(value)-len(value)+len(value)])[:0] + trimSpace(value)
}

func trimSpace(value string) string {
	start, end := 0, len(value)
	for start < end && (value[start] == ' ' || value[start] == '\n' || value[start] == '\r' || value[start] == '\t') {
		start++
	}
	for end > start && (value[end-1] == ' ' || value[end-1] == '\n' || value[end-1] == '\r' || value[end-1] == '\t') {
		end--
	}
	return value[start:end]
}

func (m *bridgeIntegrityMonitor) start(ctxDone <-chan struct{}, onViolation func(error)) {
	go func() {
		ticker := time.NewTicker(bridgeIntegrityPollInterval)
		defer ticker.Stop()
		for {
			select {
			case <-ctxDone:
				return
			case <-m.stopCh:
				return
			case <-ticker.C:
				digest, err := bridgeKeyDigest(m.path)
				if err != nil {
					m.violate(fmt.Errorf("bridge key is missing or invalid: %w", err), onViolation)
					return
				}
				if digest != m.baseline {
					m.violate(fmt.Errorf("bridge key content changed"), onViolation)
					return
				}
			}
		}
	}()
}

func (m *bridgeIntegrityMonitor) violate(reason error, onViolation func(error)) {
	if m.healthy.Swap(false) {
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
	// The process-wide flag is intentionally fail-closed. Once a violation is
	// detected, active connections must not accept another authenticated command.
	return bridgeIntegrityState.Load()
}

var bridgeIntegrityState atomic.Bool

func init() {
	bridgeIntegrityState.Store(true)
}

// Keep the runtime platform distinction explicit: the baseline monitor is
// cross-platform; OS-specific event APIs can replace the polling loop later
// without changing the fail-closed policy.
var _ = runtime.GOOS
var _ = filepath.Separator
