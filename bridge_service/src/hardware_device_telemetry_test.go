package main

import (
	"testing"
	"time"
)

func TestAttachGPUPlatformSensorsAttachesToSingleMatchingGPU(t *testing.T) {
	devices := []HardwareDevice{
		{ID: "0123456789abcdef", Identity: HardwareDeviceIdentity{Vendor: "NVIDIA", DeviceClass: "gpu"}, Backend: "linux-sysfs"},
	}
	observed := time.Date(2026, 11, 27, 12, 0, 0, 0, time.UTC)
	metrics := HardwareMetrics{
		GPUVendor: "NVIDIA", SensorSource: "nvidia-smi", GPUUsageSource: "nvidia-smi",
		GPUTemperature: 62, GPUTemperatureSource: "nvidia-smi",
		GPUUsage: 0, GPUMemoryUsedBytes: 1024, GPUMemoryTotalBytes: 4096,
		PowerWatts: 80, GPUCoreClockMHz: 1800,
	}
	got := attachGPUPlatformSensors(devices, metrics, observed)
	if len(got[0].Sensors) != 6 {
		t.Fatalf("expected six telemetry sensors, got %d: %+v", len(got[0].Sensors), got[0].Sensors)
	}
	if got[0].Sensors[1].Value != 0 {
		t.Fatalf("zero GPU utilization is a valid reading, got %v", got[0].Sensors[1].Value)
	}
	if err := got[0].Validate(); err != nil {
		t.Fatalf("telemetry-enriched device failed validation: %v", err)
	}
}

func TestAttachGPUPlatformSensorsDoesNotGuessAmongMultipleGPUs(t *testing.T) {
	devices := []HardwareDevice{
		{ID: "0123456789abcdef", Identity: HardwareDeviceIdentity{Vendor: "NVIDIA", DeviceClass: "gpu"}, Backend: "linux-sysfs"},
		{ID: "fedcba9876543210", Identity: HardwareDeviceIdentity{Vendor: "NVIDIA", DeviceClass: "gpu"}, Backend: "linux-sysfs"},
	}
	got := attachGPUPlatformSensors(devices, HardwareMetrics{
		GPUVendor: "NVIDIA", SensorSource: "nvidia-smi",
		GPUTemperature: 70, GPUTemperatureSource: "nvidia-smi",
	}, time.Now())
	for _, device := range got {
		if len(device.Sensors) != 0 {
			t.Fatalf("ambiguous telemetry was attached to a GPU: %+v", device)
		}
	}
}

func TestAttachGPUPlatformSensorsIgnoresUnknownVendorAndMissingSource(t *testing.T) {
	devices := []HardwareDevice{
		{ID: "0123456789abcdef", Identity: HardwareDeviceIdentity{Vendor: "NVIDIA", DeviceClass: "gpu"}, Backend: "linux-sysfs"},
	}
	got := attachGPUPlatformSensors(devices, HardwareMetrics{
		GPUVendor: "Unknown", GPUTemperature: 55, GPUTemperatureSource: "unknown",
	}, time.Now())
	if len(got[0].Sensors) != 0 {
		t.Fatalf("telemetry without a trusted vendor/source was attached: %+v", got[0].Sensors)
	}
}

func TestNormalizeGPUVendorAcceptsLibreHardwareMonitorNames(t *testing.T) {
	cases := map[string]string{
		"GpuNvidia": "nvidia",
		"GpuAmd": "amd",
		"GpuIntel": "intel",
	}
	for input, want := range cases {
		if got := normalizeGPUVendor(input); got != want {
			t.Fatalf("normalizeGPUVendor(%q) = %q, want %q", input, got, want)
		}
	}
}

func TestAttachGPUPlatformSensorsPreservesZeroAndSubzeroTemperatures(t *testing.T) {
	for _, temperature := range []float64{0, -5} {
		devices := []HardwareDevice{
			{ID: "0123456789abcdef", Identity: HardwareDeviceIdentity{Vendor: "NVIDIA", DeviceClass: "gpu"}, Backend: "linux-sysfs"},
		}
		got := attachGPUPlatformSensors(devices, HardwareMetrics{
			GPUVendor: "NVIDIA", SensorSource: "test",
			GPUTemperature: temperature, GPUTemperatureSource: "test-temperature",
		}, time.Now())
		if len(got[0].Sensors) != 1 || got[0].Sensors[0].Value != temperature {
			t.Fatalf("valid GPU temperature %v was not preserved: %+v", temperature, got[0].Sensors)
		}
	}
}
