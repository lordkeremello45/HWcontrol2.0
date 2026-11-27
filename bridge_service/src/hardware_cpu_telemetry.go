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
		appendUniqueHardwareSensor(device, HardwareSensor{
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

func attachMotherboardIdentity(devices []HardwareDevice, metrics HardwareMetrics) []HardwareDevice {
	vendor := strings.TrimSpace(metrics.MotherboardVendor)
	model := strings.TrimSpace(metrics.MotherboardModel)
	if vendor == "" && model == "" {
		return devices
	}
	for i := range devices {
		if devices[i].Identity.DeviceClass != "motherboard-controller" {
			continue
		}
		if vendor != "" {
			devices[i].Identity.Vendor = vendor
		}
		if model != "" {
			devices[i].Identity.Model = model + " (" + devices[i].Identity.Model + ")"
		}
		if err := devices[i].Validate(); err != nil {
			continue
		}
	}
	return devices
}

func attachMemoryPlatformSensors(devices []HardwareDevice, metrics HardwareMetrics, observedAt time.Time) []HardwareDevice {
	if metrics.MemoryUsageSource == "" || observedAt.IsZero() {
		if observedAt.IsZero() { observedAt = time.Now().UTC() }
	}
	if metrics.MemoryUsageSource == "" || metrics.MemoryTotalBytes == 0 {
		return devices
	}
	hash := sha256.Sum256([]byte("system-memory"))
	device := HardwareDevice{
		ID: hex.EncodeToString(hash[:8]),
		Identity: HardwareDeviceIdentity{Vendor: "System", DeviceClass: "memory", Model: "System memory"},
		Backend: "gopsutil-memory",
	}
	add := func(id, kind, unit string, value float64) {
		if !isFiniteNonNegative(value) { return }
		appendUniqueHardwareSensor(&device, HardwareSensor{
			ID: id, Kind: kind, Unit: unit, Value: value,
			Source: metrics.MemoryUsageSource, ObservedAt: observedAt.UTC(), State: "available",
		})
	}
	add("memory-usage", "utilization", "percent", metrics.MemoryUsage)
	add("memory-used", "memory-used", "bytes", float64(metrics.MemoryUsedBytes))
	add("memory-total", "memory-total", "bytes", float64(metrics.MemoryTotalBytes))
	device.Capabilities = []HardwareCapabilityRef{{
		Name: "sensorRead", Read: true, State: "available", Backend: "gopsutil-memory",
	}}
	if err := device.Validate(); err != nil {
		return devices
	}
	for i := range devices {
		if devices[i].ID == device.ID {
			devices[i] = device
			return devices
		}
	}
	return append(devices, device)
}
