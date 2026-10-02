//go:build windows

package main

import (
	"crypto/rand"
	"fmt"
	"os"
	"path/filepath"
	"unsafe"

	"golang.org/x/sys/windows"
)

const verifyKeySize = 32
const cryptProtectUIForbidden = 0x1

func verifyKeyPath() string {
	root := os.Getenv("ProgramData")
	if root == "" {
		root = `C:\ProgramData`
	}
	return filepath.Join(root, "HWControl", "security", "verify.key")
}

func protectVerifyKey(key []byte) ([]byte, error) {
	in := windows.DataBlob{Size: uint32(len(key)), Data: &key[0]}
	var out windows.DataBlob
	if err := windows.CryptProtectData(&in, nil, nil, 0, nil, cryptProtectUIForbidden, &out); err != nil {
		return nil, fmt.Errorf("CryptProtectData: %w", err)
	}
	defer windows.LocalFree(windows.Handle(uintptr(unsafe.Pointer(out.Data))))
	protected := append([]byte(nil), unsafe.Slice(out.Data, out.Size)...)
	return protected, nil
}

func unprotectVerifyKey(protected []byte) ([]byte, error) {
	if len(protected) == 0 {
		return nil, fmt.Errorf("protected verify.key is empty")
	}
	in := windows.DataBlob{Size: uint32(len(protected)), Data: &protected[0]}
	var out windows.DataBlob
	if err := windows.CryptUnprotectData(&in, nil, nil, 0, nil, cryptProtectUIForbidden, &out); err != nil {
		return nil, fmt.Errorf("CryptUnprotectData: %w", err)
	}
	defer windows.LocalFree(windows.Handle(uintptr(unsafe.Pointer(out.Data))))
	key := append([]byte(nil), unsafe.Slice(out.Data, out.Size)...)
	if len(key) != verifyKeySize {
		return nil, fmt.Errorf("verify.key has invalid length")
	}
	return key, nil
}

func loadOrCreateVerifyKey() ([]byte, error) {
	path := verifyKeyPath()
	if err := os.MkdirAll(filepath.Dir(path), 0750); err != nil {
		return nil, err
	}
	if protected, err := os.ReadFile(path); err == nil {
		return unprotectVerifyKey(protected)
	} else if !os.IsNotExist(err) {
		return nil, err
	}

	key := make([]byte, verifyKeySize)
	if _, err := rand.Read(key); err != nil {
		return nil, fmt.Errorf("generate verify.key: %w", err)
	}
	protected, err := protectVerifyKey(key)
	if err != nil {
		return nil, err
	}
	file, err := os.OpenFile(path, os.O_WRONLY|os.O_CREATE|os.O_EXCL, 0600)
	if err != nil {
		if os.IsExist(err) {
			protected, readErr := os.ReadFile(path)
			if readErr != nil {
				return nil, readErr
			}
			return unprotectVerifyKey(protected)
		}
		return nil, err
	}
	if _, err := file.Write(protected); err != nil {
		_ = file.Close()
		_ = os.Remove(path)
		return nil, err
	}
	if err := file.Sync(); err != nil {
		_ = file.Close()
		return nil, err
	}
	if err := file.Close(); err != nil {
		return nil, err
	}
	return key, nil
}

func verifyInstallationState(root string) error {
	key, err := loadOrCreateVerifyKey()
	if err != nil {
		return fmt.Errorf("load verify.key: %w", err)
	}
	return verifyInstallationStateWithKey(root, key)
}
