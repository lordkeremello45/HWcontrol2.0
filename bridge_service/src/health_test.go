package main

import "testing"

func TestEvaluateHardwareHealthCapabilityMatrix(t *testing.T) {
	bridgeIntegrityState.Store(true)
	metrics := HardwareMetrics{
		CPUTemperature: 55, CPUTemperatureSource: "test-cpu", GPUTemperature: 60, GPUTemperatureSource: "test-gpu", FanRPM: 1200, FanRPMSource: "test-fan", FanControlSupported: true,
		FanControlBackend: "test-backend", ThermalSafetyAvailable: true, SensorSource: "test",
		Voltage: 1.1, PowerWatts: 65, GPUCoreClockMHz: 1500, GPUMemoryClockMHz: 7000,
		GPUMemoryTotalBytes: 8 * 1024 * 1024 * 1024, DetectionStatus: "ok", DetectionSource: "test",
		StorageVolumes: []StorageVolume{{MountPoint: "E:", TotalBytes: 1000, UsedBytes: 900, FreeBytes: 100, UsagePercent: 90, HealthStatus: "unknown"}},
	}
	evaluation := evaluateHardwareHealth(metrics)
	if evaluation.SafetyState != "SAFE" {
		t.Fatalf("safety state = %q, want SAFE", evaluation.SafetyState)
	}
	for _, key := range []string{"cpuTemperature", "gpuTemperature", "fanRpm", "fanControl", "voltage", "power", "gpuCoreClock", "gpuMemoryClock", "gpuMemory", "hardwareIdentity", "storage"} {
		if !evaluation.Capabilities[key].Available {
			t.Fatalf("capability %q unexpectedly unavailable: %#v", key, evaluation.Capabilities[key])
		}
	}
}

func TestEvaluateHardwareHealthRecognizesIndividualFanControl(t *testing.T) {
	bridgeIntegrityState.Store(true)
	evaluation := evaluateHardwareHealth(HardwareMetrics{
		CPUTemperature:         55,
		CPUTemperatureSource:   "test-cpu",
		ThermalSafetyAvailable: true,
		FanControlSupported:    false,
		FanControlBackend:      "monitor-only",
		FanChannels: []FanChannel{{
			ID:           "0123456789abcdef",
			Name:         "Test PWM 1",
			Backend:      "linux-hwmon",
			Supported:    true,
			FanRPM:       1200,
			RPMAvailable: true,
		}},
	})
	for _, key := range []string{"fanChannels", "fanControl", "fanCurveAutomation"} {
		if !evaluation.Capabilities[key].Available {
			t.Fatalf("capability %q should be available for a supported independent fan channel: %#v", key, evaluation.Capabilities[key])
		}
	}
	if evaluation.Capabilities["fanControl"].Backend != "linux-hwmon" {
		t.Fatalf("fan-control backend = %q, want linux-hwmon", evaluation.Capabilities["fanControl"].Backend)
	}
}

func TestEvaluateHardwareHealthUsesEmergencyCoolingForSupportedFanChannel(t *testing.T) {
	bridgeIntegrityState.Store(true)
	evaluation := evaluateHardwareHealth(HardwareMetrics{
		CPUTemperature:         96,
		CPUTemperatureSource:   "test-cpu",
		ThermalSafetyAvailable: true,
		FanChannels: []FanChannel{{
			ID:        "0123456789abcdef",
			Name:      "Test PWM 1",
			Backend:   "linux-hwmon",
			Supported: true,
		}},
	})
	if evaluation.SafetyState != "CRITICAL" {
		t.Fatalf("safety state = %q, want CRITICAL", evaluation.SafetyState)
	}
	if evaluation.RecoveryAction != "emergency-cooling-and-reduce-thermal-load" {
		t.Fatalf("recovery action = %q, want emergency cooling", evaluation.RecoveryAction)
	}
	for _, key := range []string{"fanControl", "fanChannels", "fanCurveAutomation"} {
		if !evaluation.Capabilities[key].Available {
			t.Fatalf("capability %q should be available: %#v", key, evaluation.Capabilities[key])
		}
	}
}

func TestEvaluateHardwareHealthDetectsThermalAnomaly(t *testing.T) {
	bridgeIntegrityState.Store(true)
	metrics := HardwareMetrics{CPUTemperature: 96, ThermalSafetyAvailable: true, SensorSource: "test"}
	evaluation := evaluateHardwareHealth(metrics)
	if evaluation.SafetyState != "CRITICAL" {
		t.Fatalf("safety state = %q, want CRITICAL", evaluation.SafetyState)
	}
	if evaluation.RecoveryAction != "stop-hardware-control-and-cool" {
		t.Fatalf("recovery action = %q", evaluation.RecoveryAction)
	}
}

func TestEvaluateHardwareHealthFailsSafeOnIntegrityFailure(t *testing.T) {
	bridgeIntegrityState.Store(false)
	defer bridgeIntegrityState.Store(true)
	evaluation := evaluateHardwareHealth(HardwareMetrics{ThermalSafetyAvailable: true})
	if evaluation.SafetyState != "FAIL_SAFE" {
		t.Fatalf("safety state = %q, want FAIL_SAFE", evaluation.SafetyState)
	}
	if evaluation.RecoveryAction != "trusted-repair-or-reinstall-required" {
		t.Fatalf("recovery action = %q", evaluation.RecoveryAction)
	}
}

func TestEvaluateHardwareHealthDetectsFanStallRisk(t *testing.T) {
	bridgeIntegrityState.Store(true)
	evaluation := evaluateHardwareHealth(HardwareMetrics{CPUTemperature: 88, FanRPM: 0, FanControlSupported: true, FanControlBackend: "test", ThermalSafetyAvailable: true, SensorSource: "test"})
	found := false
	for _, anomaly := range evaluation.Anomalies {
		if anomaly.Code == "fan-stall-risk" && anomaly.Severity == "critical" {
			found = true
		}
	}
	if !found {
		t.Fatal("expected fan-stall-risk anomaly")
	}
}

func TestEvaluateHardwareHealthFlagsNearlyFullStorage(t *testing.T) {
	bridgeIntegrityState.Store(true)
	evaluation := evaluateHardwareHealth(HardwareMetrics{
		ThermalSafetyAvailable: true,
		StorageVolumes:         []StorageVolume{{MountPoint: "E:", UsagePercent: 96}},
	})
	found := false
	for _, anomaly := range evaluation.Anomalies {
		if anomaly.Code == "storage-near-full" && anomaly.Severity == "warning" {
			found = true
		}
	}
	if !found {
		t.Fatal("expected storage-near-full anomaly")
	}
}

func TestEvaluateHardwareHealthExposesBatteryAndSystemCapabilities(t *testing.T) {
	bridgeIntegrityState.Store(true)
	metrics := HardwareMetrics{
		CPUUsage: 35, MemoryUsage: 42, MemoryTotalBytes: 16 * 1024 * 1024 * 1024,
		DiskUsage: 55, DiskTotalBytes: 512 * 1024 * 1024 * 1024,
		GPUUsage: 60, GPUVendor: "NVIDIA", SensorSource: "test",
		FanPercent: 45, FanPercentSource: "test-gpu-fan", FanControlSupported: true, FanControlBackend: "test-backend",
		ThermalSafetyAvailable: true, CPUTemperature: 55, CPUTemperatureSource: "test-cpu",
		Battery: BatteryMetrics{Present: true, DataAvailable: true, HealthPercent: 82},
	}
	evaluation := evaluateHardwareHealth(metrics)
	for _, key := range []string{"cpuUtilization", "memory", "diskUsage", "gpuUtilization", "fanPercent", "batteryHealth", "thermalSafety"} {
		if !evaluation.Capabilities[key].Available {
			t.Errorf("capability %q unexpectedly unavailable: %#v", key, evaluation.Capabilities[key])
		}
	}
}

func TestEvaluateHardwareHealthWarnsOnDegradedBatteryCapacity(t *testing.T) {
	bridgeIntegrityState.Store(true)
	evaluation := evaluateHardwareHealth(HardwareMetrics{
		ThermalSafetyAvailable: true,
		Battery:                BatteryMetrics{Present: true, DataAvailable: true, HealthPercent: 45},
	})
	found := false
	for _, anomaly := range evaluation.Anomalies {
		if anomaly.Code == "battery-capacity-degraded" && anomaly.Severity == "warning" {
			found = true
		}
	}
	if !found {
		t.Fatal("expected degraded-battery-capacity warning")
	}
}

func TestEvaluateHardwareHealthMarksInvalidUtilization(t *testing.T) {
	bridgeIntegrityState.Store(true)
	evaluation := evaluateHardwareHealth(HardwareMetrics{
		CPUUsage: 140, MemoryUsage: 50, ThermalSafetyAvailable: true,
	})
	found := false
	for _, anomaly := range evaluation.Anomalies {
		if anomaly.Code == "cpu-utilization-invalid" {
			found = true
		}
	}
	if !found {
		t.Fatal("expected invalid CPU utilization anomaly")
	}
}

func TestEvaluateHardwareHealthDoesNotAdvertiseUnimplementedWriteControls(t *testing.T) {
	bridgeIntegrityState.Store(true)
	evaluation := evaluateHardwareHealth(HardwareMetrics{
		CPUTemperature: 50, GPUTemperature: 55, ThermalSafetyAvailable: true,
		FanControlSupported: false, FanControlBackend: "monitor-only",
	})
	for _, key := range []string{"gpuPowerLimitControl", "cpuOverclockControl", "batteryChargeLimitControl"} {
		capability := evaluation.Capabilities[key]
		if capability.Available {
			t.Errorf("unsupported capability %q was advertised as available", key)
		}
		if capability.Reason == "" {
			t.Errorf("unsupported capability %q has no explanation", key)
		}
	}
	if evaluation.Capabilities["fanCurveAutomation"].Available {
		t.Fatal("fan curve automation must remain unavailable without a verified control backend")
	}
}

func TestEvaluateHardwareHealthDoesNotAdvertiseTemperatureWithoutSource(t *testing.T) {
	bridgeIntegrityState.Store(true)
	evaluation := evaluateHardwareHealth(HardwareMetrics{
		CPUTemperature:         55,
		GPUTemperature:         60,
		ThermalSafetyAvailable: true,
	})
	if evaluation.Capabilities["cpuTemperature"].Available || evaluation.Capabilities["gpuTemperature"].Available {
		t.Fatal("temperature without a known source must not be advertised as verified telemetry")
	}
}

func TestEvaluateHardwareHealthDoesNotConfuseFanControlWithFanTelemetry(t *testing.T) {
	bridgeIntegrityState.Store(true)
	evaluation := evaluateHardwareHealth(HardwareMetrics{
		FanControlSupported:    true,
		FanControlBackend:      "linux-hwmon",
		FanRPM:                 0,
		FanPercent:             0,
		ThermalSafetyAvailable: true,
	})
	if !evaluation.Capabilities["fanControl"].Available {
		t.Fatal("writable fan control should be reported independently")
	}
	if evaluation.Capabilities["fanRpm"].Available || evaluation.Capabilities["fanPercent"].Available {
		t.Fatal("fan control support must not imply readable fan telemetry")
	}
}

func TestEvaluateHardwareHealthDetectsStalledIndividualFanAmongMultipleChannels(t *testing.T) {
	bridgeIntegrityState.Store(true)
	evaluation := evaluateHardwareHealth(HardwareMetrics{
		CPUTemperature: 88, ThermalSafetyAvailable: true,
		FanChannels: []FanChannel{
			{ID: "0123456789abcdef", Name: "CPU Fan", Backend: "linux-hwmon", Supported: true, FanRPM: 1450, RPMAvailable: true},
			{ID: "1123456789abcdef", Name: "GPU Fan", Backend: "linux-hwmon", Supported: true, FanRPM: 0, RPMAvailable: true, FanPercent: 55, PercentAvailable: true},
		},
	})
	found := false
	for _, anomaly := range evaluation.Anomalies {
		if anomaly.Code == "fan-stall-risk" && anomaly.Severity == "critical" && anomaly.Message == "Fan channel GPU Fan has a non-zero PWM command (55.0%) but reports 0 RPM under thermal load" {
			found = true
		}
	}
	if !found {
		t.Fatalf("expected a channel-specific critical stall anomaly, got %#v", evaluation.Anomalies)
	}
}

func TestEvaluateHardwareHealthWarnsWhenControllableFanRPMIsUnavailable(t *testing.T) {
	bridgeIntegrityState.Store(true)
	evaluation := evaluateHardwareHealth(HardwareMetrics{
		CPUTemperature: 88, ThermalSafetyAvailable: true,
		FanChannels: []FanChannel{{
			ID: "0123456789abcdef", Name: "CPU Fan", Backend: "linux-hwmon", Supported: true,
			RPMAvailable: false,
		}},
	})
	for _, anomaly := range evaluation.Anomalies {
		if anomaly.Code == "fan-stall-risk" {
			t.Fatal("missing RPM telemetry must not be misreported as a confirmed zero-RPM stall")
		}
		if anomaly.Code == "fan-rpm-unavailable-under-thermal-load" && anomaly.Severity == "warning" {
			return
		}
	}
	t.Fatalf("expected an RPM-unavailable warning, got %#v", evaluation.Anomalies)
}

func TestEvaluateHardwareHealthIgnoresUnsupportedFanChannelsForStallDetection(t *testing.T) {
	bridgeIntegrityState.Store(true)
	evaluation := evaluateHardwareHealth(HardwareMetrics{
		CPUTemperature: 88, ThermalSafetyAvailable: true,
		FanChannels: []FanChannel{{
			ID: "0123456789abcdef", Name: "Monitor-only Fan", Backend: "monitor-only",
			Supported: false, FanRPM: 0, RPMAvailable: true,
		}},
	})
	for _, anomaly := range evaluation.Anomalies {
		if anomaly.Code == "fan-stall-risk" || anomaly.Code == "fan-rpm-unavailable-under-thermal-load" {
			t.Fatalf("unsupported channel must not produce a controllable-fan anomaly: %#v", anomaly)
		}
	}
}

func TestEvaluateHardwareHealthDoesNotFlagIntentionalZeroPWMAsFanStall(t *testing.T) {
	bridgeIntegrityState.Store(true)
	evaluation := evaluateHardwareHealth(HardwareMetrics{
		CPUTemperature: 88, ThermalSafetyAvailable: true,
		FanChannels: []FanChannel{{
			ID: "0123456789abcdef", Name: "GPU Fan", Backend: "linux-hwmon", Supported: true,
			FanRPM: 0, RPMAvailable: true, FanPercent: 0, PercentAvailable: true,
		}},
	})
	for _, anomaly := range evaluation.Anomalies {
		if anomaly.Code == "fan-stall-risk" {
			t.Fatalf("zero RPM with a zero PWM command may be an intentional fan-stop mode: %#v", anomaly)
		}
	}
}

func TestEvaluateHardwareHealthDoesNotConfirmStallWithoutPWMCommandState(t *testing.T) {
	bridgeIntegrityState.Store(true)
	evaluation := evaluateHardwareHealth(HardwareMetrics{
		CPUTemperature: 88, ThermalSafetyAvailable: true,
		FanChannels: []FanChannel{{
			ID: "0123456789abcdef", Name: "CPU Fan", Backend: "linux-hwmon", Supported: true,
			FanRPM: 0, RPMAvailable: true, PercentAvailable: false,
		}},
	})
	for _, anomaly := range evaluation.Anomalies {
		if anomaly.Code == "fan-stall-risk" {
			t.Fatal("zero RPM without command-state telemetry must not be treated as a confirmed stall")
		}
		if anomaly.Code == "fan-command-state-unavailable-under-thermal-load" && anomaly.Severity == "warning" {
			return
		}
	}
	t.Fatalf("expected missing PWM-command-state warning, got %#v", evaluation.Anomalies)
}

func TestHardwareCapabilityIncludesExplicitState(t *testing.T) {
	for _, test := range []struct {
		name      string
		available bool
		backend   string
		reason    string
		want      string
	}{
		{name: "available", available: true, backend: "test", want: "available"},
		{name: "permission denied", backend: "test", reason: "permission denied", want: "permission_denied"},
		{name: "unsupported", backend: "not-implemented", reason: "adapter not implemented", want: "unsupported"},
		{name: "unavailable", backend: "test", reason: "sensor not detected", want: "unavailable"},
	} {
		t.Run(test.name, func(t *testing.T) {
			got := capability(test.available, test.backend, test.reason)
			if got.State != test.want {
				t.Fatalf("capability state = %q, want %q", got.State, test.want)
			}
			if got.Available != test.available {
				t.Fatalf("capability available = %t, want %t", got.Available, test.available)
			}
		})
	}
}
