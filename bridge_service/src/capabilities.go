package main

import (
	"sort"
	"strings"
)

const capabilitySchemaVersion = 1

const (
	capabilityStateSupported   = "supported"
	capabilityStateReadOnly    = "read-only"
	capabilityStateUnavailable = "unavailable"
	capabilityStateBlocked     = "blocked"
)

type CapabilityConstraint struct {
	Unit                string  `json:"unit,omitempty"`
	Minimum             float64 `json:"minimum,omitempty"`
	Maximum             float64 `json:"maximum,omitempty"`
	Step                float64 `json:"step,omitempty"`
	RequiredPermissions []string `json:"requiredPermissions,omitempty"`
}

type CapabilityRecord struct {
	ID             string                `json:"id"`
	SchemaVersion  int                   `json:"schemaVersion"`
	Domain         string                `json:"domain"`
	State          string                `json:"state"`
	Platform       string                `json:"platform"`
	Backend        string                `json:"backend,omitempty"`
	Evidence       string                `json:"evidence,omitempty"`
	ObservedAt     string                `json:"observedAt,omitempty"`
	Reason         string                `json:"reason,omitempty"`
	Constraints    *CapabilityConstraint `json:"constraints,omitempty"`
}

var writableCapabilityIDs = map[string]struct{}{
	"fanControl": {},
	"fanCurveAutomation": {},
	"gpuPowerLimitControl": {},
	"cpuOverclockControl": {},
	"batteryChargeLimitControl": {},
}

var telemetryCapabilityIDs = map[string]struct{}{
	"cpuTemperature": {},
	"gpuTemperature": {},
	"fanRpm": {},
	"fanChannels": {},
	"voltage": {},
	"power": {},
	"gpuCoreClock": {},
	"gpuMemoryClock": {},
	"gpuMemory": {},
	"hardwareIdentity": {},
	"storage": {},
	"cpuUtilization": {},
	"memory": {},
	"diskUsage": {},
	"gpuUtilization": {},
	"fanPercent": {},
	"batteryHealth": {},
	"thermalSafety": {},
}

// detailedCapabilityRecords is an additive, versioned representation. It does
// not grant control by itself: hardware writes must continue to pass the
// command validator and the owning adapter's safety gate.
func detailedCapabilityRecords(
	capabilities map[string]HardwareCapability,
	metrics HardwareMetrics,
	platform string,
	integrityHealthy bool,
) []CapabilityRecord {
	ids := make([]string, 0, len(capabilities))
	for id := range capabilities {
		ids = append(ids, id)
	}
	sort.Strings(ids)

	records := make([]CapabilityRecord, 0, len(ids))
	for _, id := range ids {
		capability := capabilities[id]
		record := CapabilityRecord{
			ID: id, SchemaVersion: capabilitySchemaVersion,
			Domain: capabilityDomain(id), Platform: platform,
			Backend: sanitizeCapabilityText(capability.Backend, 96),
			Reason: sanitizeCapabilityText(capability.Reason, 240),
			ObservedAt: metrics.MetricsCollectedAt,
			State: capabilityStateUnavailable,
		}

		if isWritableCapability(id) {
			switch {
			case !integrityHealthy:
				record.State = capabilityStateBlocked
				record.Reason = "Runtime integrity verification failed; hardware writes are blocked"
			case capability.Available:
				record.State = capabilityStateSupported
			default:
				record.State = capabilityStateUnavailable
			}
		} else if capability.Available {
			if _, telemetry := telemetryCapabilityIDs[id]; telemetry {
				record.State = capabilityStateReadOnly
			} else {
				record.State = capabilityStateSupported
			}
		}

		record.Evidence = capabilityEvidence(id, capability, metrics)
		if id == "fanControl" || id == "fanCurveAutomation" {
			record.Constraints = &CapabilityConstraint{
				Unit: "percent", Minimum: 20, Maximum: 100, Step: 1,
				RequiredPermissions: []string{"validated-platform-adapter", "valid-thermal-telemetry"},
			}
		}
		records = append(records, record)
	}
	return records
}

func isWritableCapability(id string) bool {
	_, ok := writableCapabilityIDs[id]
	return ok
}

func capabilityDomain(id string) string {
	switch {
	case strings.Contains(id, "fan") || strings.Contains(id, "thermal") || strings.Contains(id, "Temperature"):
		return "cooling"
	case strings.Contains(id, "battery"):
		return "power"
	case strings.Contains(id, "gpu") || strings.Contains(id, "cpu") || id == "voltage" || id == "power" || id == "memory":
		return "telemetry"
	case id == "hardwareIdentity":
		return "identity"
	case id == "storage" || id == "diskUsage":
		return "storage"
	default:
		return "system"
	}
}

func capabilityEvidence(id string, capability HardwareCapability, metrics HardwareMetrics) string {
	switch id {
	case "cpuTemperature":
		return sanitizeCapabilityText(metrics.CPUTemperatureSource, 96)
	case "gpuTemperature":
		return sanitizeCapabilityText(metrics.GPUTemperatureSource, 96)
	case "fanRpm":
		return sanitizeCapabilityText(metrics.FanRPMSource, 96)
	case "fanPercent":
		return sanitizeCapabilityText(metrics.FanPercentSource, 96)
	case "hardwareIdentity":
		return sanitizeCapabilityText(metrics.DetectionSource, 96)
	default:
		return sanitizeCapabilityText(capability.Backend, 96)
	}
}

func sanitizeCapabilityText(value string, maxLength int) string {
	value = strings.TrimSpace(value)
	value = strings.Map(func(r rune) rune {
		if r < 0x20 || r == 0x7f {
			return -1
		}
		return r
	}, value)
	if len(value) > maxLength {
		value = value[:maxLength]
	}
	return value
}
