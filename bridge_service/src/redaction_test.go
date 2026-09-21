package main

import (
	"strings"
	"testing"
)

func TestRedactSensitiveText(t *testing.T) {
	input := "HWCONTROL_KEY=super-secret HMAC_SECRET=abc123 Authorization: Bearer token-xyz path=C:\\Users\\Kerem\\HWControl\\log.txt /home/kerem/.config/hwcontrol"
	got := redactSensitiveText(input)

	for _, secret := range []string{"super-secret", "abc123", "token-xyz", "Kerem", "kerem"} {
		if strings.Contains(got, secret) {
			t.Fatalf("sensitive value leaked: %q in %q", secret, got)
		}
	}
	for _, expected := range []string{"[REDACTED]", "Bearer [REDACTED]", "<USER>"} {
		if !strings.Contains(got, expected) {
			t.Fatalf("expected %q in redacted output: %q", expected, got)
		}
	}
}

func TestRedactPrivateKey(t *testing.T) {
	input := "-----BEGIN PRIVATE KEY-----\nvery-secret-material\n-----END PRIVATE KEY-----"
	got := redactSensitiveText(input)
	if strings.Contains(got, "very-secret-material") {
		t.Fatal("private key material leaked")
	}
	if !strings.Contains(got, "[REDACTED_PRIVATE_KEY]") {
		t.Fatalf("private key marker missing: %q", got)
	}
}
