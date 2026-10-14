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
