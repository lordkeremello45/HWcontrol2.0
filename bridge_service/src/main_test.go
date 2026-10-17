package main

import (
	"bufio"
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"fmt"
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
	cmd := Command{
		Action:    action,
		Value:     value,
		Timestamp: time.Now().UnixMilli(),
		Nonce:     "0123456789abcdef0123456789abcdef",
	}
	cmd.Auth = strings.Repeat("0", sha256.Size*2)
	return cmd
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

func TestMaxNvidiaGPUTemperatureFromMetricsOutputSelectsHottestGPU(t *testing.T) {
	output := []byte("NVIDIA GPU 0, 560.1, 52, x\nNVIDIA GPU 1, 560.1, 87, x\ninvalid row\n")
	value, ok := maxNvidiaGPUTemperatureFromMetricsOutput(output)
	if !ok {
		t.Fatal("expected a valid GPU temperature")
	}
	if value != 87 {
		t.Fatalf("maximum GPU temperature = %v, want 87", value)
	}
}

func TestMaxNvidiaGPUTemperatureFromMetricsOutputFailsClosed(t *testing.T) {
	for _, input := range []string{"", "invalid row\n", "GPU,driver,N/A\n", "GPU,driver,0\n", "GPU,driver,150\n"} {
		if value, ok := maxNvidiaGPUTemperatureFromMetricsOutput([]byte(input)); ok {
			t.Fatalf("input %q returned invalid temperature %v", input, value)
		}
	}
}

func TestMaxNvidiaGPUTemperatureSelectsHottestValidGPU(t *testing.T) {
	value, ok := maxNvidiaGPUTemperature([]byte("52\n87\ninvalid\n0\n128\n"))
	if !ok {
		t.Fatal("expected a valid GPU temperature")
	}
	if value != 87 {
		t.Fatalf("maximum GPU temperature = %v, want 87", value)
	}
}

func TestMaxNvidiaGPUTemperatureRejectsMissingOrInvalidSamples(t *testing.T) {
	for _, input := range []string{"", "N/A\n", "0\n", "-1\n", "150\n", "NaN\n", "+Inf\n"} {
		if value, ok := maxNvidiaGPUTemperature([]byte(input)); ok {
			t.Fatalf("input %q returned unsafe GPU temperature %v", input, value)
		}
	}
}

func TestFanChannelCommandRequiresValidatedTarget(t *testing.T) {
	for _, test := range []struct {
		name  string
		target string
		valid bool
	}{
		{name: "missing target", target: "", valid: false},
		{name: "path is not a channel id", target: "/sys/class/hwmon/hwmon0/pwm1", valid: false},
		{name: "valid opaque id", target: "0123456789abcdef", valid: true},
	} {
		t.Run(test.name, func(t *testing.T) {
			cmd := testCommand("Set Fan Channel", 55)
			cmd.Target = test.target
			if got := validateCommand(cmd) == nil; got != test.valid {
				t.Fatalf("validateCommand() validity = %v, want %v", got, test.valid)
			}
		})
	}

	legacy := testCommand("Get Status", 0)
	legacy.Target = "0123456789abcdef"
	if err := validateCommand(legacy); err == nil {
		t.Fatal("target must be rejected for non-targeted actions")
	}
}

func TestTargetedCommandAuthenticatesFanChannelID(t *testing.T) {
	cmd := testCommand("Set Fan Channel", 60)
	cmd.Target = "0123456789abcdef"
	cmd.Auth = signCommand(cmd, "test-secret")
	if !authenticateCommand(cmd, "test-secret") {
		t.Fatal("expected signed channel command to authenticate")
	}
	cmd.Target = "fedcba9876543210"
	if authenticateCommand(cmd, "test-secret") {
		t.Fatal("changing target must invalidate command authentication")
	}
}

func TestFanChannelSafetyGate(t *testing.T) {
	const channelID = "0123456789abcdef"
	base := HardwareMetrics{
		ThermalSafetyAvailable: true,
		CPUTemperature:         60,
		GPUTemperature:         65,
		FanChannels: []FanChannel{{
			ID: channelID, Name: "Test PWM 1", Backend: "test-hwmon", Supported: true,
		}},
	}
	cmd := testCommand("Set Fan Channel", 70)
	cmd.Target = channelID
	if err := validateFanChannelControlRequest(cmd, base); err != nil {
		t.Fatalf("expected a supported channel to pass safety gate: %v", err)
	}

	unsupported := base
	unsupported.FanChannels = []FanChannel{{
		ID: channelID, Name: "Test PWM 1", Backend: "monitor-only", Supported: false,
		Reason: "manual mode is not available",
	}}
	if err := validateFanChannelControlRequest(cmd, unsupported); err == nil {
		t.Fatal("unsupported channel must remain monitor-only")
	}

	noThermal := base
	noThermal.ThermalSafetyAvailable = false
	if err := validateFanChannelControlRequest(cmd, noThermal); err == nil {
		t.Fatal("channel control must fail closed without valid thermal telemetry")
	}

	critical := base
	critical.CPUTemperature = criticalCPUTemperature
	cmd.Value = 99
	if err := validateFanChannelControlRequest(cmd, critical); err == nil {
		t.Fatal("critical thermal state must reject a sub-100% fan target")
	}
	cmd.Value = 100
	if err := validateFanChannelControlRequest(cmd, critical); err != nil {
		t.Fatalf("100%% emergency target should pass for a supported channel: %v", err)
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

func TestValidateCommandRejectsValueOutsideAuthenticatedPrecision(t *testing.T) {
	command := testCommand("AI İşlem Gücü", 50)
	const secret = "test-secret"
	command.Auth = signCommand(command, secret)

	// The existing six-decimal HMAC representation would otherwise produce
	// the same signature for both of these values.
	command.Value = 50.0000001
	if !authenticateCommand(command, secret) {
		t.Fatal("test precondition failed: rounded canonical payload should match")
	}
	if err := validateCommand(command); err == nil {
		t.Fatal("value that collides under six-decimal HMAC canonicalization was accepted")
	}
}

func TestValidateCommandRejectsNonCanonicalActionWhitespace(t *testing.T) {
	command := testCommand(" Get Status ", 0)
	command.Auth = signCommand(command, "test-secret")
	if err := validateCommand(command); err == nil {
		t.Fatal("padded action should be rejected before dispatch")
	}
}

func TestValidateCommandRejectsValueOutsideAuthenticatedPrecision(t *testing.T) {
	command := testCommand("AI İşlem Gücü", 50)
	const secret = "test-secret"
	command.Auth = signCommand(command, secret)

	// The existing six-decimal HMAC representation would otherwise produce
	// the same signature for both of these values.
	command.Value = 50.0000001
	if !authenticateCommand(command, secret) {
		t.Fatal("test precondition failed: rounded canonical payload should match")
	}
	if err := validateCommand(command); err == nil {
		t.Fatal("value that collides under six-decimal HMAC canonicalization was accepted")
	}
}

func TestValidateCommandRejectsNonCanonicalActionWhitespace(t *testing.T) {
	command := testCommand(" Get Status ", 0)
	command.Auth = signCommand(command, "test-secret")
	if err := validateCommand(command); err == nil {
		t.Fatal("padded action should be rejected before dispatch")
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

func TestValidateCommandRejectsInvalidAuthAndReadOnlyValue(t *testing.T) {
	invalidAuth := testCommand("Get Status", 0)
	invalidAuth.Auth = "not-hex"
	if err := validateCommand(invalidAuth); err == nil {
		t.Fatal("expected malformed auth to be rejected")
	}

	for _, action := range []string{"Get Status", "Get Security", "Get Diagnostics", "Get Health", "Get Game Mode"} {
		command := testCommand(action, 1)
		if err := validateCommand(command); err == nil {
			t.Fatalf("expected non-zero value for %q to be rejected", action)
		}
	}

	longAction := testCommand(strings.Repeat("A", maxActionLength+1), 0)
	if err := validateCommand(longAction); err == nil {
		t.Fatal("expected oversized action to be rejected")
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

func TestCommandNonceCacheFailsClosedWhenFull(t *testing.T) {
	replayMu.Lock()
	original := replayNonces
	now := time.Now()
	replayNonces = make(map[string]time.Time, maxReplayNonces)
	for i := 0; i < maxReplayNonces; i++ {
		replayNonces[fmt.Sprintf("%032x", i+1)] = now.Add(time.Minute)
	}
	firstNonce := fmt.Sprintf("%032x", 1)
	replayMu.Unlock()

	t.Cleanup(func() {
		replayMu.Lock()
		replayNonces = original
		replayMu.Unlock()
	})

	if consumeCommandNonce("ffffffffffffffffffffffffffffffff", now) {
		t.Fatal("a new nonce must be rejected when the replay cache is saturated")
	}
	replayMu.Lock()
	_, retained := replayNonces[firstNonce]
	count := len(replayNonces)
	replayMu.Unlock()
	if !retained {
		t.Fatal("a still-valid nonce was evicted from the replay cache")
	}
	if count != maxReplayNonces {
		t.Fatalf("replay cache size = %d, want %d", count, maxReplayNonces)
	}
	if consumeCommandNonce(firstNonce, now) {
		t.Fatal("a previously used nonce became replayable when the cache was full")
	}
	if !consumeCommandNonce("eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee", now.Add(2*time.Minute)) {
		t.Fatal("expired cache entries should allow new commands after their validity window")
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
		FanControlSupported:    true,
		FanControlBackend:      "test-backend",
		ThermalSafetyAvailable: true,
		CPUTemperature:         60,
		GPUTemperature:         65,
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

func TestCriticalTemperaturePermitsOnlyEmergencyCoolingTarget(t *testing.T) {
	base := HardwareMetrics{
		FanControlSupported:    true,
		FanControlBackend:      "test-backend",
		ThermalSafetyAvailable: true,
		CPUTemperature:         60,
		GPUTemperature:         65,
	}

	for _, test := range []struct {
		name   string
		mutate func(*HardwareMetrics)
	}{
		{"critical CPU", func(m *HardwareMetrics) { m.CPUTemperature = criticalCPUTemperature }},
		{"critical GPU", func(m *HardwareMetrics) { m.GPUTemperature = criticalGPUTemperature }},
	} {
		t.Run(test.name, func(t *testing.T) {
			metrics := base
			test.mutate(&metrics)
			if err := validateFanControlRequest(testCommand("Fan Hızı", 100), metrics); err != nil {
				t.Fatalf("100%% emergency cooling target should be allowed with valid telemetry and backend: %v", err)
			}
			if err := validateFanControlRequest(testCommand("Fan Hızı", 99), metrics); err == nil {
				t.Fatal("critical thermal state must reject a fan target below 100%")
			}
		})
	}
}

func TestEmergencyCoolingStillRequiresValidTelemetryAndSupportedBackend(t *testing.T) {
	critical := HardwareMetrics{
		FanControlSupported:    true,
		FanControlBackend:      "test-backend",
		ThermalSafetyAvailable: true,
		CPUTemperature:         criticalCPUTemperature,
		GPUTemperature:         65,
	}
	if err := validateFanControlRequest(testCommand("Fan Hızı", 100), critical); err != nil {
		t.Fatalf("expected valid emergency request to be accepted: %v", err)
	}

	withoutThermal := critical
	withoutThermal.ThermalSafetyAvailable = false
	if err := validateFanControlRequest(testCommand("Fan Hızı", 100), withoutThermal); err == nil {
		t.Fatal("emergency cooling must fail closed when thermal telemetry is unavailable")
	}

	unsupported := critical
	unsupported.FanControlSupported = false
	unsupported.FanControlBackend = "monitor-only"
	if err := validateFanControlRequest(testCommand("Fan Hızı", 100), unsupported); err == nil {
		t.Fatal("emergency cooling must not bypass the hardware capability gate")
	}

	invalid := critical
	invalid.CPUTemperature = 150
	if err := validateFanControlRequest(testCommand("Fan Hızı", 100), invalid); err == nil {
		t.Fatal("emergency cooling must reject invalid thermal telemetry")
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

func TestConnectionClosesAfterRepeatedMalformedRequests(t *testing.T) {
	previousIntegrity := bridgeIntegrityHealthy()
	bridgeIntegrityState.Store(true)
	t.Cleanup(func() { bridgeIntegrityState.Store(previousIntegrity) })

	server, client := net.Pipe()
	defer client.Close()
	if err := client.SetDeadline(time.Now().Add(3 * time.Second)); err != nil {
		t.Fatal(err)
	}
	done := make(chan struct{})
	go func() {
		handleConnection(server, "test-secret")
		close(done)
	}()

	decoder := json.NewDecoder(client)
	for i := 0; i < 5; i++ {
		if _, err := fmt.Fprintln(client, "{invalid-json}"); err != nil {
			t.Fatalf("write malformed request %d: %v", i+1, err)
		}
		var response Response
		if err := decoder.Decode(&response); err != nil {
			t.Fatalf("read response %d: %v", i+1, err)
		}
		if response.Status != "ERROR" {
			t.Fatalf("response %d status = %q, want ERROR", i+1, response.Status)
		}
	}
	select {
	case <-done:
	case <-time.After(2 * time.Second):
		t.Fatal("connection remained open after repeated malformed requests")
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

func TestHardwareControlSafetyGateRejectsInvalidSensorValues(t *testing.T) {
	base := HardwareMetrics{
		ThermalSafetyAvailable: true,
		CPUTemperature: 60,
		GPUTemperature: 65,
	}
	for _, test := range []struct {
		name string
		mutate func(*HardwareMetrics)
	}{
		{"CPU over sensor range", func(m *HardwareMetrics) { m.CPUTemperature = 150 }},
		{"GPU below sensor range", func(m *HardwareMetrics) { m.GPUTemperature = -50 }},
		{"CPU NaN", func(m *HardwareMetrics) { m.CPUTemperature = math.NaN() }},
		{"GPU positive infinity", func(m *HardwareMetrics) { m.GPUTemperature = math.Inf(1) }},
		{"no valid thermal source", func(m *HardwareMetrics) { m.ThermalSafetyAvailable = false }},
	} {
		t.Run(test.name, func(t *testing.T) {
			metrics := base
			test.mutate(&metrics)
			if err := hardwareControlSafetyError(metrics); err == nil {
				t.Fatal("expected invalid thermal telemetry to block hardware control")
			}
		})
	}
}


func TestDecodeAudioDeviceProbeOutput(t *testing.T) {
	data, err := decodeAudioDeviceProbeOutput([]byte(`{"capture":[{"index":0,"nameHex":"555342204d6963726f70686f6e65","isDefault":true}],"playback":[{"index":2,"nameHex":"537065616b657273","isDefault":false}]}`))
	if err != nil { t.Fatalf("decodeAudioDeviceProbeOutput returned error: %v", err) }
	capture := data["capture"].([]map[string]any)
	playback := data["playback"].([]map[string]any)
	if len(capture) != 1 || capture[0]["name"] != "USB Microphone" || capture[0]["isDefault"] != true {
		t.Fatalf("unexpected capture endpoints: %#v", capture)
	}
	if len(playback) != 1 || playback[0]["index"] != 2 || playback[0]["name"] != "Speakers" {
		t.Fatalf("unexpected playback endpoints: %#v", playback)
	}
	if data["localOnly"] != true { t.Fatalf("audio endpoint response must be marked local-only") }
}

func TestDecodeAudioDeviceProbeOutputRejectsInvalidNames(t *testing.T) {
	tests := []struct { name, raw string }{
		{"invalid hex", `{"capture":[{"index":0,"nameHex":"xyz","isDefault":true}]}`},
		{"empty name", `{"playback":[{"index":0,"nameHex":"","isDefault":true}]}`},
		{"negative index", `{"capture":[{"index":-1,"nameHex":"4d6963","isDefault":true}]}`},
	}
	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			if _, err := decodeAudioDeviceProbeOutput([]byte(test.raw)); err == nil {
				t.Fatal("expected invalid native audio device data to be rejected")
			}
		})
	}
}


func TestValidAudioStudioStartRequest(t *testing.T) {
	request := audioStudioStartRequest{
		CaptureIndex: 0, PlaybackIndex: 1,
		InputGain: 0, GateThreshold: -48, CompressorThreshold: -12,
		CompressorRatio: 2, CompressorAttack: 10, CompressorRelease: 100,
		CompressorKnee: 6, HighPassFrequency: 80, LimiterCeiling: -1,
		EQGain: []float64{0, 2, -1}, EQFrequency: []float64{100, 1000, 8000},
		LimiterEnabled: true,
	}
	if err := validAudioStudioStartRequest(request); err != nil {
		t.Fatalf("valid audio profile rejected: %v", err)
	}
	request.EQGain = []float64{0, 2}
	if err := validAudioStudioStartRequest(request); err == nil {
		t.Fatal("EQ profile with fewer than three bands must be rejected")
	}
	request.EQGain = []float64{0, 2, -1}
	request.InputGain = math.NaN()
	if err := validAudioStudioStartRequest(request); err == nil {
		t.Fatal("non-finite audio parameters must be rejected")
	}
}

func TestDecodeAudioStudioStartTarget(t *testing.T) {
	request := audioStudioStartRequest{
		CaptureIndex: 0, PlaybackIndex: 0,
		GateThreshold: -48, CompressorThreshold: -12,
		CompressorRatio: 2, CompressorAttack: 10, CompressorRelease: 100,
		CompressorKnee: 6, HighPassFrequency: 80, LimiterCeiling: -1,
		EQGain: []float64{0, 0, 0}, EQFrequency: []float64{100, 1000, 8000},
	}
	raw, err := json.Marshal(request)
	if err != nil { t.Fatal(err) }
	target := base64.RawURLEncoding.EncodeToString(raw)
	decoded, err := decodeAudioStudioStartTarget(target)
	if err != nil { t.Fatalf("valid encoded profile rejected: %v", err) }
	line := audioStudioStartLine(decoded)
	if !strings.HasPrefix(line, "start 0 0 0 ") || !strings.Contains(line, "1000") {
		t.Fatalf("unexpected native start protocol: %s", line)
	}
	if _, err := decodeAudioStudioStartTarget("not-valid-base64"); err == nil {
		t.Fatal("malformed audio configuration target must be rejected")
	}
}


func TestValidateAudioStudioStartCommand(t *testing.T) {
	request := audioStudioStartRequest{
		CaptureIndex: 0, PlaybackIndex: 0,
		GateThreshold: -48, CompressorThreshold: -12,
		CompressorRatio: 2, CompressorAttack: 10, CompressorRelease: 100,
		CompressorKnee: 6, HighPassFrequency: 80, LimiterCeiling: -1,
		EQGain: []float64{0, 0, 0}, EQFrequency: []float64{100, 1000, 8000},
	}
	raw, err := json.Marshal(request)
	if err != nil { t.Fatal(err) }
	cmd := testCommand("Start Audio Studio", 0)
	cmd.Target = base64.RawURLEncoding.EncodeToString(raw)
	if err := validateCommand(cmd); err != nil {
		t.Fatalf("valid authenticated audio command shape rejected: %v", err)
	}
	cmd.Target = ""
	if err := validateCommand(cmd); err == nil {
		t.Fatal("start command without profile must be rejected")
	}
}

func TestDecodeCommandStrictAcceptsKnownFields(t *testing.T) {
	cmd := testCommand("Get Status", 0)
	payload, err := json.Marshal(cmd)
	if err != nil {
		t.Fatal(err)
	}
	var decoded Command
	if err := decodeCommandStrict(payload, &decoded); err != nil {
		t.Fatalf("valid command rejected: %v", err)
	}
	if decoded.Action != cmd.Action || decoded.Nonce != cmd.Nonce {
		t.Fatalf("decoded command mismatch: got %+v want %+v", decoded, cmd)
	}
}

func TestDecodeCommandStrictRejectsUnknownFields(t *testing.T) {
	payload := []byte(`{"action":"Get Status","value":0,"timestamp":1,"nonce":"0123456789abcdef0123456789abcdef","auth":"00","trusted":true}`)
	var decoded Command
	if err := decodeCommandStrict(payload, &decoded); err == nil {
		t.Fatal("unknown JSON field was accepted")
	}
}

func TestDecodeCommandStrictRejectsMultipleJSONValues(t *testing.T) {
	payload := []byte(`{"action":"Get Status","value":0,"timestamp":1,"nonce":"0123456789abcdef0123456789abcdef","auth":"00"} {}`)
	var decoded Command
	if err := decodeCommandStrict(payload, &decoded); err == nil {
		t.Fatal("multiple JSON values were accepted")
	}
}
