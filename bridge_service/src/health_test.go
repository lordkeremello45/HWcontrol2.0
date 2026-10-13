package main

import "testing"

func TestEvaluateHardwareHealthCapabilityMatrix(t *testing.T) {
	bridgeIntegrityState.Store(true)
	metrics := HardwareMetrics{
		CPUTemperature: 55, CPUTemperatureSource: "test-cpu", GPUTemperature: 60, GPUTemperatureSource: "test-gpu", FanRPM: 1200, FanControlSupported: true,
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
		FanPercent: 45, FanControlSupported: true, FanControlBackend: "test-backend",
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
