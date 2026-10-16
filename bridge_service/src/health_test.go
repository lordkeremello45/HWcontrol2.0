package main

import (
	"encoding/json"
	"testing"
)

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
		CPUTemperature: 55,
		CPUTemperatureSource: "test-cpu",
		ThermalSafetyAvailable: true,
		FanControlSupported: false,
		FanControlBackend: "monitor-only",
		FanChannels: []FanChannel{{
			ID: "0123456789abcdef",
			Name: "Test PWM 1",
			Backend: "linux-hwmon",
			Supported: true,
			FanRPM: 1200,
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
		CPUTemperature: 96,
		CPUTemperatureSource: "test-cpu",
		ThermalSafetyAvailable: true,
		FanChannels: []FanChannel{{
			ID: "0123456789abcdef",
			Name: "Test PWM 1",
			Backend: "linux-hwmon",
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
		StorageVolumes: []StorageVolume{{MountPoint: "E:", UsagePercent: 96}},
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
		Battery: BatteryMetrics{Present: true, DataAvailable: true, HealthPercent: 45},
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
		CPUTemperature: 55,
		GPUTemperature: 60,
		ThermalSafetyAvailable: true,
	})
	if evaluation.Capabilities["cpuTemperature"].Available || evaluation.Capabilities["gpuTemperature"].Available {
		t.Fatal("temperature without a known source must not be advertised as verified telemetry")
	}
}

func TestEvaluateHardwareHealthDoesNotConfuseFanControlWithFanTelemetry(t *testing.T) {
	bridgeIntegrityState.Store(true)
	evaluation := evaluateHardwareHealth(HardwareMetrics{
		FanControlSupported: true,
		FanControlBackend: "linux-hwmon",
		FanRPM: 0,
		FanPercent: 0,
		ThermalSafetyAvailable: true,
	})
	if !evaluation.Capabilities["fanControl"].Available {
		t.Fatal("writable fan control should be reported independently")
	}
	if evaluation.Capabilities["fanRpm"].Available || evaluation.Capabilities["fanPercent"].Available {
		t.Fatal("fan control support must not imply readable fan telemetry")
	}
}

func TestFeatureCapabilityContractReportsRGBAsUnavailable(t *testing.T) {
	bridgeIntegrityState.Store(true)
	evaluation := evaluateHardwareHealth(HardwareMetrics{
		CPUTemperature: 52, CPUTemperatureSource: "test-cpu",
		MetricsCollectedAt: "2026-10-15T12:00:00Z",
		ThermalSafetyAvailable: true,
	})
	byID := make(map[string]HardwareFeatureCapability, len(evaluation.FeatureCapabilities))
	for _, capability := range evaluation.FeatureCapabilities {
		if capability.SchemaVersion != 1 {
			t.Errorf("capability %q schemaVersion = %d, want 1", capability.ID, capability.SchemaVersion)
		}
		if capability.Platform == "" {
			t.Errorf("capability %q has no platform", capability.ID)
		}
		byID[capability.ID] = capability
	}
	for _, id := range []string{"lighting.rgb", "mouse.rgb", "keyboard.rgb"} {
		capability, ok := byID[id]
		if !ok {
			t.Fatalf("missing capability %q", id)
		}
		if capability.State != "unavailable" {
			t.Errorf("%s state = %q, want unavailable until a validated adapter exists", id, capability.State)
		}
		if capability.Reason == "" {
			t.Errorf("%s must explain why it is unavailable", id)
		}
	}
	if got := byID["telemetry.cpu-temperature"].State; got != "read-only" {
		t.Errorf("CPU temperature state = %q, want read-only", got)
	}
	if got := byID["cooling.fan-control"].State; got != "unavailable" {
		t.Errorf("fan control state = %q, want unavailable without validated control telemetry", got)
	}
}

func TestHealthSnapshotKeepsLegacyCapabilityMapAndAddsVersionedContract(t *testing.T) {
	bridgeIntegrityState.Store(true)
	evaluation := evaluateHardwareHealth(HardwareMetrics{})
	snapshot := HealthSnapshot{
		Capabilities: evaluation.Capabilities,
		FeatureCapabilities: evaluation.FeatureCapabilities,
	}
	encoded, err := json.Marshal(snapshot)
	if err != nil {
		t.Fatalf("marshal health snapshot: %v", err)
	}
	var decoded map[string]json.RawMessage
	if err := json.Unmarshal(encoded, &decoded); err != nil {
		t.Fatalf("unmarshal health snapshot: %v", err)
	}
	if _, ok := decoded["capabilities"]; !ok {
		t.Fatal("legacy capabilities field disappeared")
	}
	if _, ok := decoded["featureCapabilities"]; !ok {
		t.Fatal("new featureCapabilities field is missing")
	}
}
