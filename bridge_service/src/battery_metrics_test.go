package main

import (
	"math"
	"testing"
)

func TestMakeBatteryMetricsCalculatesHealthAndPreservesCycles(t *testing.T) {
	cycles := 325
	got := makeBatteryMetrics(true, "charging", 60000, 48000, "mWh", &cycles)
	if !got.DataAvailable {
		t.Fatal("expected capacity data to be available")
	}
	if got.HealthPercent != 80 {
		t.Fatalf("health = %v, want 80", got.HealthPercent)
	}
	if got.CycleCount == nil || *got.CycleCount != cycles {
		t.Fatalf("cycle count = %v, want %d", got.CycleCount, cycles)
	}
	if got.CapacityUnit != "mWh" || got.Status != "charging" {
		t.Fatalf("unexpected battery metadata: %+v", got)
	}
}

func TestMakeBatteryMetricsFailsClosedForMissingOrInvalidCapacity(t *testing.T) {
	cases := []struct {
		name string
		present bool
		design float64
		full float64
		unit string
	}{
		{name: "not present", present: false, design: 60000, full: 48000, unit: "mWh"},
		{name: "zero design", present: true, design: 0, full: 48000, unit: "mWh"},
		{name: "negative full", present: true, design: 60000, full: -1, unit: "mWh"},
		{name: "nan", present: true, design: 60000, full: math.NaN(), unit: "mWh"},
		{name: "missing unit", present: true, design: 60000, full: 48000},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			got := makeBatteryMetrics(tc.present, "unknown", tc.design, tc.full, tc.unit, nil)
			if got.DataAvailable || got.HealthPercent != 0 {
				t.Fatalf("invalid capacity should not be reported as valid: %+v", got)
			}
		})
	}
}

func TestMakeBatteryMetricsAllowsCapacityAboveDesignWithoutClamping(t *testing.T) {
	got := makeBatteryMetrics(true, "full", 50000, 52000, "mWh", nil)
	if !got.DataAvailable || got.HealthPercent != 104 {
		t.Fatalf("expected raw reported ratio of 104%%, got %+v", got)
	}
}
