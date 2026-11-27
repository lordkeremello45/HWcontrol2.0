package main

import (
	"strings"
	"time"
)

// attachGPUPlatformSensors attaches aggregate GPU telemetry only when exactly
// one discovered GPU matches the reported vendor. It intentionally refuses
// ambiguous multi-GPU attribution instead of assigning readings to the wrong
// adapter.
func attachGPUPlatformSensors(devices []HardwareDevice, metrics HardwareMetrics, observedAt time.Time) []HardwareDevice {
	if observedAt.IsZero() {
		observedAt = time.Now().UTC()
	}
	vendor := normalizeGPUVendor(metrics.GPUVendor)
	if vendor == "" || strings.TrimSpace(metrics.SensorSource) == "" {
		return devices
	}

	match := -1
	matches := 0
	for i := range devices {
		if devices[i].Identity.DeviceClass == "gpu" && normalizeGPUVendor(devices[i].Identity.Vendor) == vendor {
			match = i
			matches++
		}
	}
	if matches != 1 {
		return devices
	}

	device := &devices[match]
	source := strings.TrimSpace(metrics.SensorSource)
	add := func(id, kind, unit string, value float64, sourceName string) {
		if !isFiniteNonNegative(value) || strings.TrimSpace(sourceName) == "" {
			return
		}
		appendUniqueHardwareSensor(device, HardwareSensor{
			ID: id, Kind: kind, Unit: unit, Value: value,
			Source: sourceName, ObservedAt: observedAt.UTC(), State: "available",
		})
	}

	if metrics.GPUTemperatureSource != "" && isValidTemperature(metrics.GPUTemperature) && metrics.GPUTemperature > 0 {
		add("gpu-temperature", "temperature", "celsius", metrics.GPUTemperature, metrics.GPUTemperatureSource)
	}
	if metrics.GPUUsageSource != "" && metrics.GPUUsage <= 100 && isFiniteNonNegative(metrics.GPUUsage) {
		add("gpu-utilization", "utilization", "percent", metrics.GPUUsage, metrics.GPUUsageSource)
	}
	if metrics.GPUMemoryUsedBytes > 0 {
		add("gpu-memory-used", "memory-used", "bytes", float64(metrics.GPUMemoryUsedBytes), source)
	}
	if metrics.GPUMemoryTotalBytes > 0 {
		add("gpu-memory-total", "memory-total", "bytes", float64(metrics.GPUMemoryTotalBytes), source)
	}
	if metrics.PowerWatts > 0 {
		add("gpu-power", "power", "watts", metrics.PowerWatts, source)
	}
	if metrics.GPUCoreClockMHz > 0 {
		add("gpu-core-clock", "clock", "megahertz", metrics.GPUCoreClockMHz, source)
	}
	if metrics.GPUMemoryClockMHz > 0 {
		add("gpu-memory-clock", "clock", "megahertz", metrics.GPUMemoryClockMHz, source)
	}
	if len(device.Sensors) > 0 {
		hasRead := false
		for _, capability := range device.Capabilities {
			if capability.Name == "sensorRead" && capability.Read && capability.State == "available" {
				hasRead = true
				break
			}
		}
		if !hasRead {
			device.Capabilities = append(device.Capabilities, HardwareCapabilityRef{
				Name: "sensorRead", Read: true, State: "available", Backend: source,
			})
		}
	}
	return devices
}

func normalizeGPUVendor(vendor string) string {
	normalized := strings.ToLower(strings.TrimSpace(vendor))
	switch normalized {
	case "nvidia", "10de", "0x10de":
		return "nvidia"
	case "amd", "ati", "1002", "0x1002":
		return "amd"
	case "intel", "8086", "0x8086":
		return "intel"
	default:
		if strings.Contains(normalized, "nvidia") { return "nvidia" }
		if strings.Contains(normalized, "amd") || strings.Contains(normalized, "ati") { return "amd" }
		if strings.Contains(normalized, "intel") { return "intel" }
		return ""
	}
}
