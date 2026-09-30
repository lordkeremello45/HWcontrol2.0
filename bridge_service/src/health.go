package main

import (
    "fmt"
    "math"
    "runtime"
    "strings"
)

type HardwareCapability struct {
    Available bool   `json:"available"`
    Backend   string `json:"backend"`
    Reason    string `json:"reason,omitempty"`
}

type HardwareAnomaly struct {
    Code     string `json:"code"`
    Severity string `json:"severity"`
    Message  string `json:"message"`
}

type HardwareHealthEvaluation struct {
    Status         string                                 `json:"status"`
    SafetyState    string                                 `json:"safetyState"`
    RecoveryAction string                                 `json:"recoveryAction"`
    Capabilities   map[string]HardwareCapability         `json:"capabilities"`
    Anomalies      []HardwareAnomaly                      `json:"anomalies,omitempty"`
}

type HealthSnapshot struct {
    Status            string                                 `json:"status"`
    SafetyState       string                                 `json:"safetyState"`
    RecoveryAction    string                                 `json:"recoveryAction"`
    Checks            map[string]string                      `json:"checks"`
    Warnings          []string                              `json:"warnings,omitempty"`
    Anomalies         []HardwareAnomaly                      `json:"anomalies,omitempty"`
    Capabilities      map[string]HardwareCapability          `json:"capabilities"`
    BridgeVersion     string                                 `json:"bridgeVersion"`
    Platform          string                                 `json:"platform"`
    Architecture      string                                 `json:"architecture"`
    LocalOnly         bool                                   `json:"localOnly"`
    HardwareControl   string                                 `json:"hardwareControl"`
    SensorSource      string                                 `json:"sensorSource"`
    DetectionStatus   string                                 `json:"detectionStatus"`
    IdentityAvailable bool                                   `json:"identityAvailable"`
}

const (
    thermalWarningTemperature  = 85.0
    thermalCriticalTemperature = 95.0
)

func capability(available bool, backend, reason string) HardwareCapability {
    return HardwareCapability{Available: available, Backend: backend, Reason: reason}
}

func evaluateHardwareHealth(metrics HardwareMetrics) HardwareHealthEvaluation {
    capabilities := map[string]HardwareCapability{
        "cpuTemperature": capability(isValidTemperature(metrics.CPUTemperature), metrics.SensorSource, "CPU thermal telemetry unavailable"),
        "gpuTemperature": capability(isValidTemperature(metrics.GPUTemperature), metrics.SensorSource, "GPU thermal telemetry unavailable"),
        "fanRpm": capability(metrics.FanRPM >= 0 && (metrics.FanRPM > 0 || metrics.FanControlSupported), metrics.SensorSource, "Fan RPM telemetry unavailable"),
        "fanControl": capability(metrics.FanControlSupported && metrics.FanControlBackend != "" && metrics.FanControlBackend != "monitor-only", metrics.FanControlBackend, "No validated hardware-control backend"),
        "voltage": capability(isFinitePositive(metrics.Voltage), metrics.SensorSource, "Voltage telemetry unavailable"),
        "power": capability(isFinitePositive(metrics.PowerWatts), metrics.SensorSource, "Power telemetry unavailable"),
        "gpuCoreClock": capability(isFinitePositive(metrics.GPUCoreClockMHz), metrics.SensorSource, "GPU core clock telemetry unavailable"),
        "gpuMemoryClock": capability(isFinitePositive(metrics.GPUMemoryClockMHz), metrics.SensorSource, "GPU memory clock telemetry unavailable"),
        "gpuMemory": capability(metrics.GPUMemoryTotalBytes > 0, metrics.SensorSource, "GPU memory capacity unavailable"),
        "hardwareIdentity": capability(strings.TrimSpace(metrics.DetectionStatus) != "" && metrics.DetectionStatus != "unavailable", metrics.DetectionSource, "Hardware identity unavailable"),
    }

    anomalies := make([]HardwareAnomaly, 0, 6)
    if metrics.CPUTemperature > 0 && !isValidTemperature(metrics.CPUTemperature) {
        anomalies = append(anomalies, HardwareAnomaly{"cpu-thermal-invalid", "critical", "CPU thermal telemetry is outside a valid operating range"})
    }
    if metrics.GPUTemperature > 0 && !isValidTemperature(metrics.GPUTemperature) {
        anomalies = append(anomalies, HardwareAnomaly{"gpu-thermal-invalid", "critical", "GPU thermal telemetry is outside a valid operating range"})
    }
    if metrics.CPUTemperature >= thermalCriticalTemperature {
        anomalies = append(anomalies, HardwareAnomaly{"cpu-overtemperature", "critical", fmt.Sprintf("CPU temperature reached %.1f °C", metrics.CPUTemperature)})
    } else if metrics.CPUTemperature >= thermalWarningTemperature {
        anomalies = append(anomalies, HardwareAnomaly{"cpu-temperature-high", "warning", fmt.Sprintf("CPU temperature reached %.1f °C", metrics.CPUTemperature)})
    }
    if metrics.GPUTemperature >= thermalCriticalTemperature {
        anomalies = append(anomalies, HardwareAnomaly{"gpu-overtemperature", "critical", fmt.Sprintf("GPU temperature reached %.1f °C", metrics.GPUTemperature)})
    } else if metrics.GPUTemperature >= thermalWarningTemperature {
        anomalies = append(anomalies, HardwareAnomaly{"gpu-temperature-high", "warning", fmt.Sprintf("GPU temperature reached %.1f °C", metrics.GPUTemperature)})
    }
    if metrics.FanControlSupported && metrics.FanRPM <= 0 && (metrics.CPUTemperature >= thermalWarningTemperature || metrics.GPUTemperature >= thermalWarningTemperature) {
        anomalies = append(anomalies, HardwareAnomaly{"fan-stall-risk", "critical", "Fan control is available but no fan RPM is reported while thermal load is high"})
    }
    if !metrics.ThermalSafetyAvailable {
        anomalies = append(anomalies, HardwareAnomaly{"thermal-sensor-missing", "warning", "No valid thermal sensor is available; hardware control must remain fail-closed"})
    }

    safetyState := "SAFE"
    recoveryAction := "none"
    for _, anomaly := range anomalies {
        switch anomaly.Severity {
        case "critical":
            safetyState = "CRITICAL"
        case "warning":
            if safetyState == "SAFE" { safetyState = "WARNING" }
        }
    }
    if !bridgeIntegrityHealthy() {
        safetyState = "FAIL_SAFE"
        recoveryAction = "trusted-repair-or-reinstall-required"
        anomalies = append(anomalies, HardwareAnomaly{Code: "runtime-integrity-failure", Severity: "critical", Message: "Runtime integrity verification failed; sensitive IPC and hardware control must remain disabled"})
    } else if safetyState == "CRITICAL" {
        recoveryAction = "stop-hardware-control-and-cool"
    } else if safetyState == "WARNING" {
        recoveryAction = "monitor-and-reduce-thermal-load"
    }

    status := "healthy"
    if safetyState != "SAFE" || len(anomalies) > 0 || !capabilities["hardwareIdentity"].Available { status = "degraded" }
    if safetyState == "FAIL_SAFE" { status = "unsafe" }
    return HardwareHealthEvaluation{Status: status, SafetyState: safetyState, RecoveryAction: recoveryAction, Capabilities: capabilities, Anomalies: anomalies}
}

func isFinitePositive(value float64) bool {
    return !math.IsNaN(value) && !math.IsInf(value, 0) && value > 0
}

func isValidTemperature(value float64) bool {
    return !math.IsNaN(value) && !math.IsInf(value, 0) && value >= -20 && value <= 125
}

func healthSnapshot() HealthSnapshot {
    metrics := collectMetrics()
    evaluation := evaluateHardwareHealth(metrics)
    checks := map[string]string{"authentication": "ok", "localTransport": "ok", "hardwareControl": "monitor-only", "hardwareIdentity": "unavailable", "sensors": "unavailable", "runtimeIntegrity": "unhealthy"}
    warnings := make([]string, 0, 4)
    if metrics.FanControlSupported { checks["hardwareControl"] = "enabled" } else { warnings = append(warnings, "hardware control backend is unavailable") }
    if evaluation.Capabilities["hardwareIdentity"].Available { checks["hardwareIdentity"] = "ok" } else { warnings = append(warnings, "hardware identity detection is unavailable") }
    if strings.TrimSpace(metrics.SensorSource) != "" { checks["sensors"] = "ok" } else { warnings = append(warnings, "no dedicated sensor source is currently available") }
    if bridgeIntegrityHealthy() { checks["runtimeIntegrity"] = "ok" } else { warnings = append(warnings, "runtime integrity verification failed; trusted repair is required") }
    return HealthSnapshot{
        Status: evaluation.Status, SafetyState: evaluation.SafetyState, RecoveryAction: evaluation.RecoveryAction,
        Checks: checks, Warnings: warnings, Anomalies: evaluation.Anomalies, Capabilities: evaluation.Capabilities,
        BridgeVersion: bridgeVersion, Platform: runtime.GOOS, Architecture: runtime.GOARCH, LocalOnly: true,
        HardwareControl: metrics.HardwareControlMode, SensorSource: metrics.SensorSource, DetectionStatus: metrics.DetectionStatus,
        IdentityAvailable: evaluation.Capabilities["hardwareIdentity"].Available,
    }
}
