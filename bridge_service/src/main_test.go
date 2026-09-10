package main

import (
	"encoding/hex"
	"math"
	"net"
	"os"
	"path/filepath"
	"runtime"
	"strings"
	"testing"
	"time"
)

func TestValidateCommand(t *testing.T) {
	tests := []struct {
		name    string
		command Command
		valid   bool
	}{
		{"valid fan command", Command{Action: "Fan Hızı", Value: 50}, true},
		{"unknown action", Command{Action: "shutdown", Value: 50}, false},
		{"out of range", Command{Action: "Fan Hızı", Value: 101}, false},
		{"missing action", Command{Value: 20}, false},
		{"status command", Command{Action: "Get Status"}, true},
		{"security command", Command{Action: "Get Security"}, true},
		{"diagnostics command", Command{Action: "Get Diagnostics"}, true},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			if (validateCommand(test.command) == nil) != test.valid {
				t.Fatalf("validateCommand(%+v) validity mismatch", test.command)
			}
		})
	}
}

func TestCommandPayloadIsStable(t *testing.T) {
	command := Command{Action: "Fan Hızı", Value: 42.5}
	want := "Fan Hızı\n42.500000"
	if got := commandPayload(command); got != want {
		t.Fatalf("commandPayload() = %q, want %q", got, want)
	}
}

func TestAuthenticateCommand(t *testing.T) {
	command := Command{Action: "Fan Hızı", Value: 50}
	secret := "test-secret"
	command.Auth = signCommand(command, secret)

	if !authenticateCommand(command, secret) {
		t.Fatal("expected command authentication to succeed")
	}
	command.Value = 51
	if authenticateCommand(command, secret) {
		t.Fatal("expected modified command authentication to fail")
	}
}

func TestAuthenticateCommandRejectsMalformedAuth(t *testing.T) {
	command := Command{Action: "Get Status", Auth: "not-hex"}
	if authenticateCommand(command, "test-secret") {
		t.Fatal("expected malformed authentication value to be rejected")
	}

	command.Auth = hex.EncodeToString([]byte("short"))
	if authenticateCommand(command, "test-secret") {
		t.Fatal("expected wrong-length authentication value to be rejected")
	}
}

func TestValidateCommandRejectsNonFiniteAndOutOfRangeValues(t *testing.T) {
	for _, value := range []float64{-1, 101, math.NaN(), math.Inf(1), math.Inf(-1)} {
		if err := validateCommand(Command{Action: "Fan Hızı", Value: value}); err == nil {
			t.Fatalf("validateCommand() accepted invalid value %v", value)
		}
	}
}

func TestBridgePortFallsBackToSafeDefault(t *testing.T) {
	for _, value := range []string{"", "0", "65536", "-1", "not-a-port", "8080:9090"} {
		t.Setenv("HWCONTROL_PORT", value)
		if got := bridgePort(); got != defaultBridgePort {
			t.Fatalf("bridgePort(%q) = %q, want %q", value, got, defaultBridgePort)
		}
	}

	for _, test := range []struct {
		value string
		want  string
	}{
		{"1", "1"},
		{"8080", "8080"},
		{"65535", "65535"},
		{" 9000 ", "9000"},
	} {
		t.Setenv("HWCONTROL_PORT", test.value)
		if got := bridgePort(); got != test.want {
			t.Fatalf("bridgePort(%q) = %q, want %q", test.value, got, test.want)
		}
	}
}

func TestExecuteHardwareCommandFailsClosed(t *testing.T) {
	for _, action := range []string{"Fan Hızı", "AI İşlem Gücü"} {
		err := executeHardwareCommand(Command{Action: action, Value: 50})
		if err == nil {
			t.Fatalf("expected %q to fail without a hardware backend", action)
		}
	}
}

func TestBridgeRequestSizeBound(t *testing.T) {
	server, client := net.Pipe()
	defer client.Close()

	done := make(chan struct{})
	go func() {
		handleConnection(server, "test-secret")
		close(done)
	}()

	payload := []byte(strings.Repeat("A", maxRequestBytes+1))
	if _, err := client.Write(payload); err == nil {
		t.Fatal("expected oversized request to terminate the connection")
	}

	select {
	case <-done:
	case <-time.After(2 * time.Second):
		t.Fatal("oversized request handler did not terminate")
	}
}

func TestBridgeKeyLifecycleUsesAtomicFile(t *testing.T) {
	if runtime.GOOS == "windows" {
		t.Skip("Windows persists the active key to the machine environment")
	}

	root := t.TempDir()
	keyPath := filepath.Join(root, "bridge.key")
	t.Setenv("HWCONTROL_KEY", "")
	t.Setenv("HWCONTROL_KEY_FILE", keyPath)

	secret, err := loadOrCreateSecret()
	if err != nil {
		t.Fatalf("loadOrCreateSecret() error = %v", err)
	}
	if len(secret) != 64 {
		t.Fatalf("generated secret length = %d, want 64 hex characters", len(secret))
	}
	if _, err := hex.DecodeString(secret); err != nil {
		t.Fatalf("generated secret is not hex: %v", err)
	}

	info, err := os.Stat(keyPath)
	if err != nil {
		t.Fatalf("stat key file: %v", err)
	}
	if mode := info.Mode().Perm(); mode != 0600 {
		t.Fatalf("key file mode = %o, want 600", mode)
	}

	reloaded, err := loadOrCreateSecret()
	if err != nil {
		t.Fatalf("reload key: %v", err)
	}
	if reloaded != secret {
		t.Fatalf("reloaded secret changed: got %q, want %q", reloaded, secret)
	}
}
