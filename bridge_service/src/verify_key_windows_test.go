//go:build windows

package main

import (
	"bytes"
	"testing"
)

func TestVerifyKeyMachineDPAPIRoundTrip(t *testing.T) {
	key := make([]byte, verifyKeySize)
	for i := range key {
		key[i] = byte(i + 1)
	}

	protected, err := protectVerifyKey(key)
	if err != nil {
		t.Fatalf("protectVerifyKey() error = %v", err)
	}
	if len(protected) == 0 {
		t.Fatal("protectVerifyKey() returned an empty DPAPI blob")
	}

	got, err := unprotectVerifyKey(protected)
	if err != nil {
		t.Fatalf("unprotectVerifyKey() error = %v", err)
	}
	if !bytes.Equal(got, key) {
		t.Fatal("DPAPI round-trip did not preserve the integrity key")
	}
}

func TestProtectVerifyKeyRejectsInvalidLength(t *testing.T) {
	for _, key := range [][]byte{nil, {}, make([]byte, verifyKeySize-1), make([]byte, verifyKeySize+1)} {
		if _, err := protectVerifyKey(key); err == nil {
			t.Fatalf("protectVerifyKey(%d bytes) succeeded; want length error", len(key))
		}
	}
}

func TestUnprotectVerifyKeyRejectsEmptyBlob(t *testing.T) {
	if _, err := unprotectVerifyKey(nil); err == nil {
		t.Fatal("unprotectVerifyKey(nil) succeeded; want empty-blob error")
	}
}
