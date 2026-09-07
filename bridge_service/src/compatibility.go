package main

import "strings"

const (
	DriverActionFullFeatures = "full_features"
	DriverActionSafeMode     = "safe_mode"
	DriverActionMonitorOnly  = "monitor_only"
)

func applyCompatibilityPolicy(metrics *HardwareMetrics) {
	status := strings.ToLower(strings.TrimSpace(metrics.GPUDriverStatus))
	vendor := strings.ToLower(strings.TrimSpace(metrics.GPUVendor))

	switch status {
	case "ok":
		metrics.GPUDriverAction = DriverActionFullFeatures
		metrics.GPUDriverReason = "GPU driver detected and telemetry backend is available."
	case "unsigned":
		metrics.GPUDriverAction = DriverActionSafeMode
		metrics.GPUDriverReason = "Display driver was detected but Windows reports it as unsigned."
	case "unavailable":
		metrics.GPUDriverAction = DriverActionMonitorOnly
		metrics.GPUDriverReason = "GPU driver could not be identified; hardware control is restricted."
	case "unsupported":
		metrics.GPUDriverAction = DriverActionMonitorOnly
		metrics.GPUDriverReason = "This platform does not provide a supported GPU driver detector."
	default:
		metrics.GPUDriverAction = DriverActionSafeMode
		metrics.GPUDriverReason = "Driver compatibility could not be determined safely."
	}

	// Do not claim full control when no GPU vendor is known.
	if metrics.GPUDriverAction == DriverActionFullFeatures && vendor == "" {
		metrics.GPUDriverAction = DriverActionSafeMode
		metrics.GPUDriverReason = "Driver is present, but GPU vendor identification is incomplete."
	}
}
