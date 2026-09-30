package main

import "testing"

func TestEvaluateHardwareHealthCapabilityMatrix(t *testing.T) {
    bridgeIntegrityState.Store(true)
    metrics := HardwareMetrics{
        CPUTemperature: 55, GPUTemperature: 60, FanRPM: 1200, FanControlSupported: true,
        FanControlBackend: "test-backend", ThermalSafetyAvailable: true, SensorSource: "test",
        Voltage: 1.1, PowerWatts: 65, GPUCoreClockMHz: 1500, GPUMemoryClockMHz: 7000,
        GPUMemoryTotalBytes: 8 * 1024 * 1024 * 1024, DetectionStatus: "ok", DetectionSource: "test",
    }
    evaluation := evaluateHardwareHealth(metrics)
    if evaluation.SafetyState != "SAFE" { t.Fatalf("safety state = %q, want SAFE", evaluation.SafetyState) }
    for _, key := range []string{"cpuTemperature", "gpuTemperature", "fanRpm", "fanControl", "voltage", "power", "gpuCoreClock", "gpuMemoryClock", "gpuMemory", "hardwareIdentity"} {
        if !evaluation.Capabilities[key].Available { t.Fatalf("capability %q unexpectedly unavailable: %#v", key, evaluation.Capabilities[key]) }
    }
}

func TestEvaluateHardwareHealthDetectsThermalAnomaly(t *testing.T) {
    bridgeIntegrityState.Store(true)
    metrics := HardwareMetrics{CPUTemperature: 96, ThermalSafetyAvailable: true, SensorSource: "test"}
    evaluation := evaluateHardwareHealth(metrics)
    if evaluation.SafetyState != "CRITICAL" { t.Fatalf("safety state = %q, want CRITICAL", evaluation.SafetyState) }
    if evaluation.RecoveryAction != "stop-hardware-control-and-cool" { t.Fatalf("recovery action = %q", evaluation.RecoveryAction) }
}

func TestEvaluateHardwareHealthFailsSafeOnIntegrityFailure(t *testing.T) {
    bridgeIntegrityState.Store(false)
    defer bridgeIntegrityState.Store(true)
    evaluation := evaluateHardwareHealth(HardwareMetrics{ThermalSafetyAvailable: true})
    if evaluation.SafetyState != "FAIL_SAFE" { t.Fatalf("safety state = %q, want FAIL_SAFE", evaluation.SafetyState) }
    if evaluation.RecoveryAction != "trusted-repair-or-reinstall-required" { t.Fatalf("recovery action = %q", evaluation.RecoveryAction) }
}

func TestEvaluateHardwareHealthDetectsFanStallRisk(t *testing.T) {
    bridgeIntegrityState.Store(true)
    evaluation := evaluateHardwareHealth(HardwareMetrics{CPUTemperature: 88, FanRPM: 0, FanControlSupported: true, FanControlBackend: "test", ThermalSafetyAvailable: true, SensorSource: "test"})
    found := false
    for _, anomaly := range evaluation.Anomalies { if anomaly.Code == "fan-stall-risk" && anomaly.Severity == "critical" { found = true } }
    if !found { t.Fatal("expected fan-stall-risk anomaly") }
}
