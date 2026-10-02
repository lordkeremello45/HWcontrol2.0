package main

import (
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"sort"
	"strings"
)

const verifyStateVersion = 1

type verifyFileRecord struct {
	Path   string `json:"path"`
	Size   int64  `json:"size"`
	SHA256 string `json:"sha256"`
}

type verifyState struct {
	Version int               `json:"version"`
	Files   []verifyFileRecord `json:"files"`
	MAC     string            `json:"mac"`
}

func verifyInstallationRoot() (string, error) {
	executable, err := os.Executable()
	if err != nil {
		return "", fmt.Errorf("resolve bridge executable: %w", err)
	}
	resolved, err := filepath.EvalSymlinks(executable)
	if err != nil {
		return "", fmt.Errorf("resolve bridge executable path: %w", err)
	}
	return filepath.Dir(resolved), nil
}

func verifyStateDir() string {
	if configured := strings.TrimSpace(os.Getenv("HWCONTROL_VERIFY_STATE_DIR")); configured != "" {
		return configured
	}
	if root := strings.TrimSpace(os.Getenv("ProgramData")); root != "" {
		return filepath.Join(root, "HWControl", "security", "state")
	}
	return filepath.Join(filepath.Dir(os.TempDir()), "hwcontrol-security-state")
}

func verifyStatePath() string {
	return filepath.Join(verifyStateDir(), "verify.state")
}

func canonicalVerifyRecords(records []verifyFileRecord) []verifyFileRecord {
	result := append([]verifyFileRecord(nil), records...)
	sort.Slice(result, func(i, j int) bool { return result[i].Path < result[j].Path })
	return result
}

func verifyStatePayload(state verifyState) []byte {
	state.MAC = ""
	payload, _ := json.Marshal(state)
	return payload
}

func verifyStateMAC(key []byte, state verifyState) string {
	mac := hmac.New(sha256.New, key)
	_, _ = mac.Write(verifyStatePayload(state))
	return hex.EncodeToString(mac.Sum(nil))
}

func verifyFileDigest(path string) (verifyFileRecord, error) {
	info, err := os.Lstat(path)
	if err != nil {
		return verifyFileRecord{}, err
	}
	if info.Mode()&os.ModeSymlink != 0 || !info.Mode().IsRegular() {
		return verifyFileRecord{}, fmt.Errorf("non-regular file: %s", path)
	}
	file, err := os.Open(path)
	if err != nil {
		return verifyFileRecord{}, err
	}
	defer file.Close()
	hasher := sha256.New()
	if _, err := io.Copy(hasher, file); err != nil {
		return verifyFileRecord{}, err
	}
	return verifyFileRecord{
		Path: filepath.ToSlash(path),
		Size: info.Size(),
		SHA256: hex.EncodeToString(hasher.Sum(nil)),
	}, nil
}

func collectVerifyInventory(root string) ([]verifyFileRecord, error) {
	var records []verifyFileRecord
	err := filepath.Walk(root, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}
		if info.IsDir() {
			return nil
		}
		if filepath.Clean(path) == filepath.Clean(verifyStatePath()) ||
			filepath.Clean(path) == filepath.Clean(verifyKeyPath()) {
			return nil
		}
		record, err := verifyFileDigest(path)
		if err != nil {
			return err
		}
		record.Path, err = filepath.Rel(root, path)
		if err != nil {
			return err
		}
		record.Path = filepath.ToSlash(record.Path)
		records = append(records, record)
		return nil
	})
	if err != nil {
		return nil, err
	}
	return canonicalVerifyRecords(records), nil
}

func verifyRecordsEqual(expected, actual []verifyFileRecord) bool {
	expected = canonicalVerifyRecords(expected)
	actual = canonicalVerifyRecords(actual)
	if len(expected) != len(actual) {
		return false
	}
	for i := range expected {
		if expected[i] != actual[i] {
			return false
		}
	}
	return true
}

func writeVerifyState(state verifyState) error {
	if err := os.MkdirAll(verifyStateDir(), 0750); err != nil {
		return fmt.Errorf("create verify state directory: %w", err)
	}
	state.Files = canonicalVerifyRecords(state.Files)
	data, err := json.MarshalIndent(state, "", "  ")
	if err != nil {
		return err
	}
	tmp, err := os.CreateTemp(verifyStateDir(), "verify.state.*.tmp")
	if err != nil {
		return err
	}
	tmpName := tmp.Name()
	defer os.Remove(tmpName)
	if err := tmp.Chmod(0600); err != nil {
		_ = tmp.Close()
		return err
	}
	if _, err := tmp.Write(data); err != nil {
		_ = tmp.Close()
		return err
	}
	if err := tmp.Sync(); err != nil {
		_ = tmp.Close()
		return err
	}
	if err := tmp.Close(); err != nil {
		return err
	}
	if err := os.Rename(tmpName, verifyStatePath()); err != nil {
		return err
	}
	return nil
}

// verifyInstallationState is the Windows-only local anti-tamper baseline.
// Non-Windows builds intentionally return nil so this feature remains
// platform-scoped without weakening the existing cross-platform monitor.
func verifyInstallationStateWithKey(root string, key []byte) error {
	stateData, err := os.ReadFile(verifyStatePath())
	if errors.Is(err, os.ErrNotExist) {
		records, inventoryErr := collectVerifyInventory(root)
		if inventoryErr != nil {
			return fmt.Errorf("create verify baseline: %w", inventoryErr)
		}
		state := verifyState{Version: verifyStateVersion, Files: records}
		state.MAC = verifyStateMAC(key, state)
		if err := writeVerifyState(state); err != nil {
			return fmt.Errorf("persist verify baseline: %w", err)
		}
		return nil
	}
	if err != nil {
		return fmt.Errorf("read verify state: %w", err)
	}
	var state verifyState
	if err := json.Unmarshal(stateData, &state); err != nil {
		return fmt.Errorf("verify state is invalid: %w", err)
	}
	if state.Version != verifyStateVersion {
		return fmt.Errorf("verify state version mismatch")
	}
	expectedMAC := verifyStateMAC(key, state)
	providedMAC, err := hex.DecodeString(state.MAC)
	if err != nil || !hmac.Equal([]byte(expectedMAC), []byte(state.MAC)) || len(providedMAC) != sha256.Size {
		return fmt.Errorf("verify state authentication failed")
	}
	actual, err := collectVerifyInventory(root)
	if err != nil {
		return fmt.Errorf("collect current installation inventory: %w", err)
	}
	if !verifyRecordsEqual(state.Files, actual) {
		return fmt.Errorf("installation inventory changed: file added, removed, or modified")
	}
	return nil
}
