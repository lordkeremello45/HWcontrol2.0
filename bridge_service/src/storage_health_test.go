package main

import (
	"encoding/json"
	"testing"
)

func TestParseSmartctlReportNVMeHealth(t *testing.T) {
	data := []byte(`{
		"smart_status":{"passed":true},
		"temperature":{"current":42},
		"nvme_smart_health_information_log":{"percentage_used":17}
	}`)
	got := parseSmartctlReport(data)
	if got.status != "healthy" {
		t.Fatalf("status = %q, want healthy", got.status)
	}
	if got.temperature == nil || *got.temperature != 42 {
		t.Fatalf("temperature = %v, want 42", got.temperature)
	}
	if got.healthPercent == nil || *got.healthPercent != 83 {
		t.Fatalf("healthPercent = %v, want 83", got.healthPercent)
	}
}

func TestParseSmartctlReportEnduranceExceeded(t *testing.T) {
	got := parseSmartctlReport([]byte(`{
		"smart_status":{"passed":true},
		"nvme_smart_health_information_log":{"percentage_used":120}
	}`))
	if got.status != "warning" {
		t.Fatalf("status = %q, want warning", got.status)
	}
	if got.healthPercent == nil || *got.healthPercent != 0 {
		t.Fatalf("healthPercent = %v, want 0", got.healthPercent)
	}
}

func TestParseSmartctlReportDoesNotInventHealth(t *testing.T) {
	got := parseSmartctlReport([]byte(`{"temperature":{"current":35}}`))
	if got.status != "unknown" {
		t.Fatalf("status = %q, want unknown", got.status)
	}
	if got.healthPercent != nil {
		t.Fatalf("healthPercent = %v, want nil", got.healthPercent)
	}
}

func TestParseSmartctlReportRejectsInvalidJSON(t *testing.T) {
	got := parseSmartctlReport([]byte("not-json"))
	if got.status != "unknown" || got.healthPercent != nil || got.temperature != nil {
		t.Fatalf("invalid report produced misleading values: %#v", got)
	}
}

func TestSmartctlReportJSONShape(t *testing.T) {
	var report smartctlReport
	if err := json.Unmarshal([]byte(`{"smart_status":{"passed":false}}`), &report); err != nil {
		t.Fatal(err)
	}
	if report.SmartStatus.Passed == nil || *report.SmartStatus.Passed {
		t.Fatal("expected explicit failing SMART status")
	}
}
