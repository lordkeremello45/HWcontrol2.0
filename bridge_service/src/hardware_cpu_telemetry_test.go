package main

import (
	"testing"
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
