package main

import (
	"encoding/json"
	"testing"
)

func TestDetailedCapabilityRecordsDistinguishReadOnlyAndWritable(t *testing.T) {
	metrics := HardwareMetrics{
		CPUTemperature: 58,
		CPUTemperatureSource: "test-cpu-sensor",
		MetricsCollectedAt: "2026-10-14T12:00:00Z",
		FanControlSupported: true,
		FanControlBackend: "test-fan-backend",
		ThermalSafetyAvailable: true,
	}
	records := detailedCapabilityRecords(map[string]HardwareCapability{
		"cpuTemperature": {Available: true, Backend: "test-cpu-sensor"},
		"fanControl": {Available: true, Backend: "test-fan-backend"},
		"gpuPowerLimitControl": {Available: false, Backend: "not-implemented", Reason: "not implemented"},
	}, metrics, "linux", true)

	got := map[string]CapabilityRecord{}
	for _, record := range records {
		got[record.ID] = record
	}
	if got["cpuTemperature"].State != capabilityStateReadOnly {
		t.Fatalf("temperature state = %q, want read-only", got["cpuTemperature"].State)
	}
	if got["fanControl"].State != capabilityStateSupported {
		t.Fatalf("fan control state = %q, want supported", got["fanControl"].State)
	}
	if got["fanControl"].Constraints == nil || got["fanControl"].Constraints.Minimum != 20 || got["fanControl"].Constraints.Maximum != 100 {
		t.Fatalf("fan control constraints missing or unsafe: %#v", got["fanControl"].Constraints)
	}
	if got["gpuPowerLimitControl"].State != capabilityStateUnavailable {
		t.Fatalf("unimplemented power limit state = %q, want unavailable", got["gpuPowerLimitControl"].State)
	}
	if got["cpuTemperature"].ObservedAt != metrics.MetricsCollectedAt {
		t.Fatalf("observedAt = %q, want metrics timestamp", got["cpuTemperature"].ObservedAt)
	}
}

func TestDetailedCapabilityRecordsBlockWritesWhenIntegrityFails(t *testing.T) {
	records := detailedCapabilityRecords(map[string]HardwareCapability{
		"fanControl": {Available: true, Backend: "test-backend"},
		"cpuTemperature": {Available: true, Backend: "test-sensor"},
	}, HardwareMetrics{}, "linux", false)

	for _, record := range records {
		if record.ID == "fanControl" && record.State != capabilityStateBlocked {
			t.Fatalf("fan control state = %q, want blocked", record.State)
		}
		if record.ID == "cpuTemperature" && record.State != capabilityStateReadOnly {
			t.Fatalf("read-only telemetry must remain read-only when integrity blocks writes, got %q", record.State)
		}
	}
}

func TestDetailedCapabilityRecordsSanitizeTextAndSerializeVersion(t *testing.T) {
	records := detailedCapabilityRecords(map[string]HardwareCapability{
		"hardwareIdentity": {Available: false, Backend: "bad\nbackend", Reason: "unknown\x00reason"},
	}, HardwareMetrics{}, "linux", true)
	if len(records) != 1 {
		t.Fatalf("records length = %d, want 1", len(records))
	}
	if records[0].Backend != "badbackend" || records[0].Reason != "unknownreason" {
		t.Fatalf("control characters were not removed: %#v", records[0])
	}
	if records[0].SchemaVersion != capabilitySchemaVersion {
		t.Fatalf("schemaVersion = %d, want %d", records[0].SchemaVersion, capabilitySchemaVersion)
	}
	payload, err := json.Marshal(records[0])
	if err != nil {
		t.Fatalf("marshal capability: %v", err)
	}
	var decoded map[string]any
	if err := json.Unmarshal(payload, &decoded); err != nil {
		t.Fatalf("unmarshal capability: %v", err)
	}
	if decoded["state"] != capabilityStateUnavailable {
		t.Fatalf("serialized state = %#v", decoded["state"])
	}
}
