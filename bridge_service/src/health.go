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

type HardwareFeatureCapability struct {
	SchemaVersion int            `json:"schemaVersion"`
	ID            string         `json:"id"`
	Domain        string         `json:"domain"`
	State         string         `json:"state"`
	Platform      string         `json:"platform"`
	Backend       string         `json:"backend"`
	Evidence      string         `json:"evidence,omitempty"`
	ObservedAt    string         `json:"observedAt,omitempty"`
	Reason        string         `json:"reason,omitempty"`
	Constraints   map[string]any `json:"constraints,omitempty"`
}

type HardwareAnomaly struct {
	Code     string `json:"code"`
	Severity string `json:"severity"`
	Message  string `json:"message"`
}

type HardwareHealthEvaluation struct {
	Status         string                        `json:"status"`
	SafetyState    string                        `json:"safetyState"`
	RecoveryAction string                        `json:"recoveryAction"`
	Capabilities   map[string]HardwareCapability `json:"capabilities"`
	FeatureCapabilities []HardwareFeatureCapability `json:"featureCapabilities"`
	Anomalies      []HardwareAnomaly             `json:"anomalies,omitempty"`
}

type HealthSnapshot struct {
	Status            string                        `json:"status"`
	SafetyState       string                        `json:"safetyState"`
	RecoveryAction    string                        `json:"recoveryAction"`
	Checks            map[string]string             `json:"checks"`
	Warnings          []string                      `json:"warnings,omitempty"`
	Anomalies         []HardwareAnomaly             `json:"anomalies,omitempty"`
	Capabilities      map[string]HardwareCapability `json:"capabilities"`
	FeatureCapabilities []HardwareFeatureCapability `json:"featureCapabilities"`
	BridgeVersion     string                        `json:"bridgeVersion"`
	Platform          string                        `json:"platform"`
	Architecture      string                        `json:"architecture"`
	LocalOnly         bool                          `json:"localOnly"`
	HardwareControl   string                        `json:"hardwareControl"`
	SensorSource      string                        `json:"sensorSource"`
	CPUTemperatureSource string                     `json:"cpuTemperatureSource,omitempty"`
	GPUTemperatureSource string                     `json:"gpuTemperatureSource,omitempty"`
	MetricsCollectedAt string                       `json:"metricsCollectedAt,omitempty"`
	DetectionStatus   string                        `json:"detectionStatus"`
	IdentityAvailable bool                          `json:"identityAvailable"`
	Storage           []StorageVolume               `json:"storage"`
}

const (
	thermalWarningTemperature  = 85.0
	thermalCriticalTemperature = 95.0
)

func capability(available bool, backend, reason string) HardwareCapability {
	return HardwareCapability{Available: available, Backend: backend, Reason: reason}
}

func hasValidatedFanControl(metrics HardwareMetrics) bool {
	return metrics.FanControlSupported || anyControllableFanChannel(metrics.FanChannels)
}

func hasValidCriticalTemperature(metrics HardwareMetrics) bool {
	cpuCritical := metrics.CPUTemperature > 0 &&
		isValidTemperature(metrics.CPUTemperature) &&
		metrics.CPUTemperature >= thermalCriticalTemperature
	gpuCritical := metrics.GPUTemperature > 0 &&
		isValidTemperature(metrics.GPUTemperature) &&
		metrics.GPUTemperature >= thermalCriticalTemperature
	return cpuCritical || gpuCritical
}

func resolvedFanControlBackend(metrics HardwareMetrics) string {
	if metrics.FanControlSupported && metrics.FanControlBackend != "" {
		return metrics.FanControlBackend
	}
	for _, channel := range metrics.FanChannels {
		if channel.Supported && channel.Backend != "" && channel.Backend != "monitor-only" {
			return channel.Backend
		}
	}
	if metrics.FanControlBackend != "" {
		return metrics.FanControlBackend
	}
	return "monitor-only"
}


// buildFeatureCapabilities provides a versioned, additive capability contract.
// The legacy map remains available for existing clients. Writable features are
// advertised only when a validated adapter currently reports support.
func buildFeatureCapabilities(metrics HardwareMetrics, legacy map[string]HardwareCapability) []HardwareFeatureCapability {
	platform := runtime.GOOS
	observedAt := strings.TrimSpace(metrics.MetricsCollectedAt)
	makeCapability := func(id, domain, legacyID string, readOnly bool) HardwareFeatureCapability {
		legacyCapability, exists := legacy[legacyID]
		state := "unavailable"
		reason := "Capability evidence is unavailable"
		backend := "none"
		evidence := ""
		if exists {
			backend = strings.TrimSpace(legacyCapability.Backend)
			reason = strings.TrimSpace(legacyCapability.Reason)
			if legacyCapability.Available {
				if readOnly {
					state = "read-only"
				} else {
					state = "supported"
				}
				evidence = backend
				reason = ""
			}
		}
		if backend == "" {
			backend = "none"
		}
		if reason == "" && state == "unavailable" {
			reason = "No validated adapter is available"
		}
		return HardwareFeatureCapability{
			SchemaVersion: 1, ID: id, Domain: domain, State: state,
			Platform: platform, Backend: backend, Evidence: evidence,
			ObservedAt: observedAt, Reason: reason,
		}
	}

	capabilities := []HardwareFeatureCapability{
		makeCapability("telemetry.cpu-temperature", "telemetry", "cpuTemperature", true),
		makeCapability("telemetry.gpu-temperature", "telemetry", "gpuTemperature", true),
		makeCapability("cooling.fan-control", "cooling", "fanControl", false),
		{
			SchemaVersion: 1, ID: "lighting.rgb", Domain: "lighting",
			State: "unavailable", Platform: platform, Backend: "none",
			ObservedAt: observedAt,
			Reason: "No validated RGB/ARGB discovery or control adapter is implemented",
		},
		{
			SchemaVersion: 1, ID: "mouse.rgb", Domain: "mouse",
			State: "unavailable", Platform: platform, Backend: "none",
			ObservedAt: observedAt,
			Reason: "No validated mouse RGB adapter is implemented; device-specific support is not yet known",
		},
		{
			SchemaVersion: 1, ID: "keyboard.rgb", Domain: "keyboard",
			State: "unavailable", Platform: platform, Backend: "none",
			ObservedAt: observedAt,
			Reason: "No validated keyboard RGB adapter is implemented; device-specific support is not yet known",
		},
	}
	return capabilities
}

func evaluateHardwareHealth(metrics HardwareMetrics) HardwareHealthEvaluation {
	capabilities := map[string]HardwareCapability{
		"cpuTemperature":   capability(metrics.CPUTemperatureSource != "" && metrics.CPUTemperature > 0 && isValidTemperature(metrics.CPUTemperature), metrics.CPUTemperatureSource, "CPU thermal telemetry unavailable or source unknown"),
		"gpuTemperature":   capability(metrics.GPUTemperatureSource != "" && metrics.GPUTemperature > 0 && isValidTemperature(metrics.GPUTemperature), metrics.GPUTemperatureSource, "GPU thermal telemetry unavailable or source unknown"),
		"fanRpm":           capability(isFinitePositive(metrics.FanRPM) && metrics.FanRPMSource != "", metrics.FanRPMSource, "Fan RPM telemetry unavailable or source unknown"),
		"fanControl":       capability(hasValidatedFanControl(metrics), resolvedFanControlBackend(metrics), "No validated hardware-control backend"),
		"fanChannels":      capability(len(metrics.FanChannels) > 0, "platform-fan-discovery", "No fan/PWM channels were enumerated"),
		"voltage":          capability(isFinitePositive(metrics.Voltage), metrics.SensorSource, "Voltage telemetry unavailable"),
		"power":            capability(isFinitePositive(metrics.PowerWatts), metrics.SensorSource, "Power telemetry unavailable"),
		"gpuCoreClock":     capability(isFinitePositive(metrics.GPUCoreClockMHz), metrics.SensorSource, "GPU core clock telemetry unavailable"),
		"gpuMemoryClock":   capability(isFinitePositive(metrics.GPUMemoryClockMHz), metrics.SensorSource, "GPU memory clock telemetry unavailable"),
		"gpuMemory":        capability(metrics.GPUMemoryTotalBytes > 0, metrics.SensorSource, "GPU memory capacity unavailable"),
		"hardwareIdentity": capability(strings.TrimSpace(metrics.DetectionStatus) != "" && metrics.DetectionStatus != "unavailable", metrics.DetectionSource, "Hardware identity unavailable"),
		"storage":          capability(len(metrics.StorageVolumes) > 0, "gopsutil", "No mounted storage volume could be enumerated"),
		"cpuUtilization":   capability(isFiniteNonNegative(metrics.CPUUsage) && metrics.CPUUsage <= 100, "gopsutil", "CPU utilization telemetry unavailable or invalid"),
		"memory":           capability(metrics.MemoryTotalBytes > 0 && isFiniteNonNegative(metrics.MemoryUsage) && metrics.MemoryUsage <= 100, "gopsutil", "System memory telemetry unavailable or invalid"),
		"diskUsage":        capability(metrics.DiskTotalBytes > 0 && isFiniteNonNegative(metrics.DiskUsage) && metrics.DiskUsage <= 100, "gopsutil", "Root-volume usage telemetry unavailable or invalid"),
		"gpuUtilization":   capability(isFiniteNonNegative(metrics.GPUUsage) && metrics.GPUUsage <= 100 && metrics.GPUVendor != "", metrics.SensorSource, "GPU utilization telemetry unavailable or invalid"),
		"fanPercent":       capability(isFiniteNonNegative(metrics.FanPercent) && metrics.FanPercent > 0 && metrics.FanPercent <= 100 && metrics.FanPercentSource != "", metrics.FanPercentSource, "Fan percentage telemetry unavailable or source unknown"),
		"batteryHealth":    capability(metrics.Battery.Present && metrics.Battery.DataAvailable && isFinitePositive(metrics.Battery.HealthPercent), "platform-battery-api", "Battery health requires valid design and full-charge capacity readings"),
		"thermalSafety":    capability(metrics.ThermalSafetyAvailable && ((metrics.CPUTemperature > 0 && isValidTemperature(metrics.CPUTemperature)) || (metrics.GPUTemperature > 0 && isValidTemperature(metrics.GPUTemperature))), metrics.SensorSource, "No valid CPU/GPU temperature source is available"),
		"fanCurveAutomation": capability(hasValidatedFanControl(metrics) && metrics.ThermalSafetyAvailable, resolvedFanControlBackend(metrics), "Automatic fan control requires both valid thermal telemetry and a supported control backend"),
		"gpuPowerLimitControl": capability(false, "not-implemented", "GPU power-limit telemetry may be readable, but a validated write backend is not implemented"),
		"cpuOverclockControl": capability(false, "not-implemented", "CPU clock/voltage overclocking is not implemented"),
		"batteryChargeLimitControl": capability(false, "not-implemented", "Battery health is read-only; charging thresholds are not changed"),
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
	if metrics.Battery.Present && metrics.Battery.DataAvailable && metrics.Battery.HealthPercent > 0 && metrics.Battery.HealthPercent < 60 {
		anomalies = append(anomalies, HardwareAnomaly{"battery-capacity-degraded", "warning", fmt.Sprintf("Reported battery full-charge capacity is %.1f%% of design capacity", metrics.Battery.HealthPercent)})
	}
	if !isFiniteNonNegative(metrics.CPUUsage) || metrics.CPUUsage > 100 {
		anomalies = append(anomalies, HardwareAnomaly{"cpu-utilization-invalid", "warning", "CPU utilization reading is invalid and must not be interpreted as a real percentage"})
	}
	if !isFiniteNonNegative(metrics.MemoryUsage) || metrics.MemoryUsage > 100 {
		anomalies = append(anomalies, HardwareAnomaly{"memory-utilization-invalid", "warning", "Memory utilization reading is invalid and must not be interpreted as a real percentage"})
	}
	for _, volume := range metrics.StorageVolumes {
		if volume.UsagePercent >= 95 {
			anomalies = append(anomalies, HardwareAnomaly{"storage-near-full", "warning", fmt.Sprintf("Storage volume %s is %.1f%% full", volume.MountPoint, volume.UsagePercent)})
		}
	}

	safetyState := "SAFE"
	recoveryAction := "none"
	for _, anomaly := range anomalies {
		switch anomaly.Severity {
		case "critical":
			safetyState = "CRITICAL"
		case "warning":
			if safetyState == "SAFE" {
				safetyState = "WARNING"
			}
		}
	}
	if !bridgeIntegrityHealthy() {
		safetyState = "FAIL_SAFE"
		recoveryAction = "trusted-repair-or-reinstall-required"
		anomalies = append(anomalies, HardwareAnomaly{Code: "runtime-integrity-failure", Severity: "critical", Message: "Runtime integrity verification failed; sensitive IPC and hardware control must remain disabled"})
	} else if safetyState == "CRITICAL" {
		if hasValidCriticalTemperature(metrics) && metrics.ThermalSafetyAvailable && hasValidatedFanControl(metrics) {
			recoveryAction = "emergency-cooling-and-reduce-thermal-load"
		} else {
			recoveryAction = "stop-hardware-control-and-cool"
		}
	} else if safetyState == "WARNING" {
		recoveryAction = "monitor-and-reduce-thermal-load"
	}

	status := "healthy"
	if safetyState != "SAFE" || len(anomalies) > 0 || !capabilities["hardwareIdentity"].Available {
		status = "degraded"
	}
	if safetyState == "FAIL_SAFE" {
		status = "unsafe"
	}
	return HardwareHealthEvaluation{Status: status, SafetyState: safetyState, RecoveryAction: recoveryAction, Capabilities: capabilities, FeatureCapabilities: buildFeatureCapabilities(metrics, capabilities), Anomalies: anomalies}
}

func isFinitePositive(value float64) bool {
	return !math.IsNaN(value) && !math.IsInf(value, 0) && value > 0
}

func isFiniteNonNegative(value float64) bool {
	return !math.IsNaN(value) && !math.IsInf(value, 0) && value >= 0
}

func isValidTemperature(value float64) bool {
	return !math.IsNaN(value) && !math.IsInf(value, 0) && value >= -20 && value <= 125
}

func healthSnapshot() HealthSnapshot {
	metrics := collectMetrics()
	evaluation := evaluateHardwareHealth(metrics)
	checks := map[string]string{"authentication": "ok", "localTransport": "ok", "hardwareControl": "monitor-only", "hardwareIdentity": "unavailable", "sensors": "unavailable", "runtimeIntegrity": "unhealthy"}
	warnings := make([]string, 0, 4)
	if hasValidatedFanControl(metrics) {
		checks["hardwareControl"] = "enabled"
	} else {
		warnings = append(warnings, "hardware control backend is unavailable")
	}
	if evaluation.Capabilities["hardwareIdentity"].Available {
		checks["hardwareIdentity"] = "ok"
	} else {
		warnings = append(warnings, "hardware identity detection is unavailable")
	}
	if strings.TrimSpace(metrics.SensorSource) != "" {
		checks["sensors"] = "ok"
	} else {
		warnings = append(warnings, "no dedicated sensor source is currently available")
	}
	if bridgeIntegrityHealthy() {
		checks["runtimeIntegrity"] = "ok"
	} else {
		warnings = append(warnings, "runtime integrity verification failed; trusted repair is required")
	}
	return HealthSnapshot{
		Status: evaluation.Status, SafetyState: evaluation.SafetyState, RecoveryAction: evaluation.RecoveryAction,
		Checks: checks, Warnings: warnings, Anomalies: evaluation.Anomalies, Capabilities: evaluation.Capabilities, FeatureCapabilities: evaluation.FeatureCapabilities,
		BridgeVersion: bridgeVersion, Platform: runtime.GOOS, Architecture: runtime.GOARCH, LocalOnly: true,
		HardwareControl: metrics.HardwareControlMode, SensorSource: metrics.SensorSource,
		CPUTemperatureSource: metrics.CPUTemperatureSource, GPUTemperatureSource: metrics.GPUTemperatureSource,
		MetricsCollectedAt: metrics.MetricsCollectedAt, DetectionStatus: metrics.DetectionStatus,
		IdentityAvailable: evaluation.Capabilities["hardwareIdentity"].Available,
		Storage:           metrics.StorageVolumes,
	}
}
