package main

import (
	"testing"
	"strings"
	"time"
)

func TestAttachCPUPlatformSensorsBuildsValidatedCPURecord(t *testing.T) {
	observed := time.Date(2026, 11, 27, 12, 0, 0, 0, time.UTC)
	metrics := HardwareMetrics{
		CPUManufacturer: "GenuineIntel", CPUModel: "Example CPU",
		CPUUsage: 0, CPUUsageSource: "gopsutil-cpu",
		CPUFrequencyMHz: 4200, CPUFrequencySource: "gopsutil-cpu-info",
		CPUTemperature: 54, CPUTemperatureSource: "coretemp",
	}
	got := attachCPUPlatformSensors(nil, metrics, observed)
	if len(got) != 1 {
		t.Fatalf("expected one CPU device, got %d", len(got))
	}
	if got[0].Identity.DeviceClass != "cpu" || got[0].Identity.Vendor != "GenuineIntel" {
		t.Fatalf("unexpected CPU identity: %+v", got[0].Identity)
	}
	if len(got[0].Sensors) != 3 {
		t.Fatalf("expected utilization, frequency and temperature sensors: %+v", got[0].Sensors)
	}
	if got[0].Sensors[0].Value != 0 {
		t.Fatalf("0%% CPU utilization must remain a valid reading: %+v", got[0].Sensors[0])
	}
	if err := got[0].Validate(); err != nil {
		t.Fatalf("CPU device validation failed: %v", err)
	}
}

func TestAttachCPUPlatformSensorsDoesNotInventSensorCapabilities(t *testing.T) {
	got := attachCPUPlatformSensors(nil, HardwareMetrics{
		CPUManufacturer: "Intel", CPUModel: "Model only",
	}, time.Now())
	if len(got) != 1 {
		t.Fatalf("expected identity-only CPU record, got %d", len(got))
	}
	if len(got[0].Sensors) != 0 || len(got[0].Capabilities) != 0 {
		t.Fatalf("identity alone must not create sensors/capabilities: %+v", got[0])
	}
}

func TestAttachCPUPlatformSensorsUsesStableOpaqueID(t *testing.T) {
	metrics := HardwareMetrics{CPUManufacturer: "AMD", CPUModel: "Example"}
	first := attachCPUPlatformSensors(nil, metrics, time.Now())
	second := attachCPUPlatformSensors(nil, metrics, time.Now())
	if first[0].ID != second[0].ID || len(first[0].ID) != 16 {
		t.Fatalf("CPU ID is not stable/opaque: %q %q", first[0].ID, second[0].ID)
	}
}

func TestAttachMotherboardIdentityEnrichesOnlyMotherboardControllers(t *testing.T) {
	devices := []HardwareDevice{
		{
			ID: "0123456789abcdef",
			Identity: HardwareDeviceIdentity{Vendor: "Unknown", DeviceClass: "motherboard-controller", Model: "nct6775"},
			Backend: "linux-hwmon",
		},
		{
			ID: "fedcba9876543210",
			Identity: HardwareDeviceIdentity{Vendor: "AMD", DeviceClass: "gpu", Model: "GPU"},
			Backend: "linux-sysfs",
		},
	}
	got := attachMotherboardIdentity(devices, HardwareMetrics{
		MotherboardVendor: "ASUSTeK", MotherboardModel: "Example Board",
	})
	if got[0].Identity.Vendor != "ASUSTeK" || !strings.Contains(got[0].Identity.Model, "Example Board") {
		t.Fatalf("motherboard controller identity was not enriched: %+v", got[0].Identity)
	}
	if got[1].Identity.Vendor != "AMD" || got[1].Identity.Model != "GPU" {
		t.Fatalf("non-motherboard identity was modified: %+v", got[1].Identity)
	}
}
