package main

import (
	"bufio"
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

func testCommand(action string, value float64) Command {
	return Command{
		Action: action,
		Value: value,
		Timestamp: time.Now().UnixMilli(),
		Nonce: "0123456789abcdef0123456789abcdef",
	}
}

func TestValidateCommand(t *testing.T) {
	tests := []struct {
		name    string
		command Command
		valid   bool
	}{
		{"valid fan command", testCommand("Fan Hızı", 50), true},
		{"unknown action", testCommand("shutdown", 50), false},
		{"out of range", testCommand("Fan Hızı", 101), false},
		{"missing action", testCommand("", 20), false},
		{"status command", testCommand("Get Status", 0), true},
		{"security command", testCommand("Get Security", 0), true},
		{"diagnostics command", testCommand("Get Diagnostics", 0), true},
		{"health command", testCommand("Get Health", 0), true},
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
	command := Command{Action: "Fan Hızı", Value: 42.5, Timestamp: 1710000000123, Nonce: "0123456789abcdef0123456789abcdef"}
	want := "Fan Hızı\n42.500000\n1710000000123\n0123456789abcdef0123456789abcdef"
	if got := commandPayload(command); got != want {
		t.Fatalf("commandPayload() = %q, want %q", got, want)
	}
}

func TestAuthenticateCommand(t *testing.T) {
	command := testCommand("Fan Hızı", 50)
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
	command := testCommand("Get Status", 0)
	command.Auth = "not-hex"
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
		if err := validateCommand(testCommand("Fan Hızı", value)); err == nil {
			t.Fatalf("validateCommand() accepted invalid value %v", value)
		}
	}
}


func TestValidateCommandRejectsStaleTimestampAndMalformedNonce(t *testing.T) {
	stale := testCommand("Get Status", 0)
	stale.Timestamp = time.Now().Add(-commandClockSkew - time.Second).UnixMilli()
	if err := validateCommand(stale); err == nil {
		t.Fatal("expected stale command to be rejected")
	}

	malformed := testCommand("Get Status", 0)
	malformed.Nonce = "not-a-nonce"
	if err := validateCommand(malformed); err == nil {
		t.Fatal("expected malformed nonce to be rejected")
	}
}

func TestCommandNonceReplayProtection(t *testing.T) {
	nonce := "fedcba9876543210fedcba9876543210"
	if !consumeCommandNonce(nonce, time.Now()) {
		t.Fatal("expected first nonce to be accepted")
	}
	if consumeCommandNonce(nonce, time.Now()) {
		t.Fatal("expected replayed nonce to be rejected")
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

func TestHardwareControlSafetyGate(t *testing.T) {
	base := HardwareMetrics{
		FanControlSupported: true,
		FanControlBackend:   "test-backend",
		ThermalSafetyAvailable: true,
		CPUTemperature:      60,
		GPUTemperature:      65,
	}
	if err := hardwareControlSafetyError(base); err != nil {
		t.Fatalf("expected safe temperatures, got %v", err)
	}
	critical := base
	critical.CPUTemperature = criticalCPUTemperature
	if err := hardwareControlSafetyError(critical); err == nil {
		t.Fatal("expected critical CPU temperature to block hardware control")
	}
	noThermal := base
	noThermal.ThermalSafetyAvailable = false
	if err := validateFanControlRequest(testCommand("Fan Hızı", 50), noThermal); err == nil {
		t.Fatal("expected missing thermal telemetry to fail closed")
	}
	unsupported := base
	unsupported.FanControlSupported = false
	if err := validateFanControlRequest(testCommand("Fan Hızı", 50), unsupported); err == nil {
		t.Fatal("expected unsupported fan control to fail closed")
	}
	if err := validateFanControlRequest(testCommand("Get Status", 0), critical); err != nil {
		t.Fatalf("non-control command should not be blocked by fan safety gate: %v", err)
	}
}

func TestExecuteHardwareCommandFailsClosed(t *testing.T) {
	for _, action := range []string{"Fan Hızı", "AI İşlem Gücü"} {
		err := executeHardwareCommand(testCommand(action, 50))
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

	payload := append([]byte(strings.Repeat("A", maxRequestBytes+1)), '\n')
	writeDone := make(chan error, 1)
	go func() {
		_, err := client.Write(payload)
		writeDone <- err
	}()
	select {
	case err := <-writeDone:
		if err != nil {
			t.Fatalf("write oversized request: %v", err)
		}
	case <-time.After(5 * time.Second):
		t.Fatal("oversized request write timed out")
	}

	reader := bufio.NewReader(client)
	_ = client.SetReadDeadline(time.Now().Add(2 * time.Second))
	if response, err := reader.ReadBytes('\n'); err != nil {
		t.Fatalf("read oversized request response: %v", err)
	} else if !strings.Contains(string(response), "request too large") {
		t.Fatalf("unexpected oversized request response: %s", response)
	}

	select {
	case <-done:
	case <-time.After(2 * time.Second):
		t.Fatal("oversized request handler did not terminate")
	}
}

func TestBridgeKeyLifecycleUsesAtomicFile(t *testing.T) {

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
	if runtime.GOOS != "windows" {
		if mode := info.Mode().Perm(); mode != 0600 {
			t.Fatalf("key file mode = %o, want 600", mode)
		}
	}

	reloaded, err := loadOrCreateSecret()
	if err != nil {
		t.Fatalf("reload key: %v", err)
	}
	if reloaded != secret {
		t.Fatalf("reloaded secret changed: got %q, want %q", reloaded, secret)
	}
}
