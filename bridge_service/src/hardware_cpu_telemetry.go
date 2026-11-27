package main

import (
	"crypto/sha256"
	"encoding/hex"
	"strings"
	"time"
)

// attachCPUPlatformSensors creates one aggregate CPU record from platform
// identity and explicitly sourced CPU metrics. It never derives sensor support
// from the CPU model alone.
func attachCPUPlatformSensors(devices []HardwareDevice, metrics HardwareMetrics, observedAt time.Time) []HardwareDevice {
	if observedAt.IsZero() {
		observedAt = time.Now().UTC()
	}
	vendor := strings.TrimSpace(metrics.CPUManufacturer)
	model := strings.TrimSpace(metrics.CPUModel)
	hasTelemetry := metrics.CPUUsageSource != "" || metrics.CPUFrequencySource != "" ||
		(metrics.CPUTemperatureSource != "" && isValidTemperature(metrics.CPUTemperature) && metrics.CPUTemperature > 0)
	if !hasTelemetry && vendor == "" && model == "" {
		return devices
	}
	if vendor == "" {
		vendor = "Unknown"
	}
	if model == "" {
		model = "CPU"
	}
	idHash := sha256.Sum256([]byte(strings.ToLower(vendor + "|" + model + "|cpu")))
	id := hex.EncodeToString(idHash[:8])
	for i := range devices {
		if devices[i].ID == id {
			return appendCPUSensors(&devices[i], metrics, observedAt)
		}
	}
	device := HardwareDevice{
		ID: id,
		Identity: HardwareDeviceIdentity{
			Vendor: vendor, DeviceClass: "cpu", Model: model,
		},
		Backend: "platform-metrics",
	}
	device = appendCPUSensors(&device, metrics, observedAt)
	return append(devices, device)
}

func appendCPUSensors(device *HardwareDevice, metrics HardwareMetrics, observedAt time.Time) HardwareDevice {
	add := func(id, kind, unit, source string, value float64) {
		if source == "" || !isFiniteNonNegative(value) {
			return
		}
		appendUniqueHardwareSensor(&device, HardwareSensor{
			ID: id, Kind: kind, Unit: unit, Value: value,
			Source: source, ObservedAt: observedAt.UTC(), State: "available",
		})
	}
	if metrics.CPUUsageSource != "" && metrics.CPUUsage <= 100 {
		add("cpu-utilization", "utilization", "percent", metrics.CPUUsageSource, metrics.CPUUsage)
	}
	if metrics.CPUFrequencySource != "" && isFinitePositive(metrics.CPUFrequencyMHz) {
		add("cpu-frequency", "clock", "megahertz", metrics.CPUFrequencySource, metrics.CPUFrequencyMHz)
	}
	if metrics.CPUTemperatureSource != "" && metrics.CPUTemperature > 0 && isValidTemperature(metrics.CPUTemperature) {
		add("cpu-temperature", "temperature", "celsius", metrics.CPUTemperatureSource, metrics.CPUTemperature)
	}
	if len(device.Sensors) > 0 {
		device.Capabilities = append(device.Capabilities, HardwareCapabilityRef{
			Name: "sensorRead", Read: true, State: "available", Backend: "platform-metrics",
		})
	}
	return *device
}
