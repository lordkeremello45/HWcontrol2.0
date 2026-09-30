package main

import (
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"os"
	"strings"
	"sync"
	"sync/atomic"
	"time"
)

const bridgeIntegrityPollInterval = 2 * time.Second

type bridgeIntegrityMonitor struct {
	path     string
	baseline string
	stopCh   chan struct{}
	stopOnce sync.Once
	healthy  atomic.Bool
}

func newBridgeIntegrityMonitor() (*bridgeIntegrityMonitor, error) {
	// Explicit environment provisioning is outside the file-integrity model.
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

	bridgeIntegrityState.Store(true)
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
	if !validBridgeSecret(strings.TrimSpace(string(data))) {
		return "", fmt.Errorf("bridge key contains an invalid secret")
	}

	sum := sha256.Sum256(data)
	return hex.EncodeToString(sum[:]), nil
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
