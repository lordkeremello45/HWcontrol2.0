package main

import (
	"runtime"
	"strings"
)

type HealthSnapshot struct {
	Status            string   `json:"status"`
	Checks            map[string]string `json:"checks"`
	Warnings          []string `json:"warnings,omitempty"`
	BridgeVersion     string   `json:"bridgeVersion"`
	Platform          string   `json:"platform"`
	Architecture      string   `json:"architecture"`
	LocalOnly         bool     `json:"localOnly"`
	HardwareControl   string   `json:"hardwareControl"`
	SensorSource      string   `json:"sensorSource"`
	DetectionStatus   string   `json:"detectionStatus"`
	IdentityAvailable bool     `json:"identityAvailable"`
}

func healthSnapshot() HealthSnapshot {
	metrics := collectMetrics()
	checks := map[string]string{
		"authentication": "ok",
		"localTransport": "ok",
		"hardwareControl": "monitor-only",
		"hardwareIdentity": "unavailable",
		"sensors": "unavailable",
	}
	warnings := make([]string, 0, 3)
	if metrics.FanControlSupported {
		checks["hardwareControl"] = "enabled"
	} else {
		warnings = append(warnings, "hardware control backend is unavailable")
	}
	if strings.TrimSpace(metrics.DetectionStatus) != "" && metrics.DetectionStatus != "unavailable" {
		checks["hardwareIdentity"] = "ok"
	} else {
		warnings = append(warnings, "hardware identity detection is unavailable")
	}
	if strings.TrimSpace(metrics.SensorSource) != "" {
		checks["sensors"] = "ok"
	} else {
		warnings = append(warnings, "no dedicated sensor source is currently available")
	}
	status := "healthy"
	if len(warnings) > 0 {
		status = "degraded"
	}
	return HealthSnapshot{
		Status: status,
		Checks: checks,
		Warnings: warnings,
		BridgeVersion: bridgeVersion,
		Platform: runtime.GOOS,
		Architecture: runtime.GOARCH,
		LocalOnly: true,
		HardwareControl: metrics.HardwareControlMode,
		SensorSource: metrics.SensorSource,
		DetectionStatus: metrics.DetectionStatus,
		IdentityAvailable: checks["hardwareIdentity"] == "ok",
	}
}
