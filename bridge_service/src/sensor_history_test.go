package main

import (
	"fmt"
	"testing"
	"time"
)

func resetSensorHistoryForTest() {
	localSensorHistory.mu.Lock()
	localSensorHistory.samples = nil
	localSensorHistory.mu.Unlock()
}

func TestSensorHistoryIsBoundedAndLocal(t *testing.T) {
	resetSensorHistoryForTest()
	defer resetSensorHistoryForTest()
	base := time.Date(2026, 10, 13, 12, 0, 0, 0, time.UTC)
	for i := 0; i < maxSensorHistorySamples+7; i++ {
		recordSensorHistory(HardwareMetrics{
			MetricsCollectedAt: base.Add(time.Duration(i) * time.Second).Format(time.RFC3339Nano),
			CPUTemperature: float64(40 + i%20),
			CPUTemperatureSource: "test-sensor",
		})
	}
	snapshot := sensorHistorySnapshot()
	if snapshot["localOnly"] != true || snapshot["persistent"] != false {
		t.Fatalf("history privacy contract incorrect: %#v", snapshot)
	}
	if snapshot["sampleCount"] != maxSensorHistorySamples {
		t.Fatalf("sample count = %#v, want %d", snapshot["sampleCount"], maxSensorHistorySamples)
	}
	samples, ok := snapshot["samples"].([]SensorHistorySample)
	if !ok || len(samples) != maxSensorHistorySamples {
		t.Fatalf("unexpected samples payload: %#v", snapshot["samples"])
	}
	if samples[0].Timestamp != base.Add(7*time.Second).Format(time.RFC3339Nano) {
		t.Fatalf("oldest retained sample timestamp = %q", samples[0].Timestamp)
	}
}

func TestSensorHistoryIgnoresMissingTimestamp(t *testing.T) {
	resetSensorHistoryForTest()
	defer resetSensorHistoryForTest()
	recordSensorHistory(HardwareMetrics{CPUTemperature: 99})
	if snapshot := sensorHistorySnapshot(); snapshot["sampleCount"] != 0 {
		t.Fatalf("sample without collection timestamp should be ignored: %#v", snapshot)
	}
}

func TestSensorHistoryAgeRejectsInvalidOrFutureTimestamp(t *testing.T) {
	now := time.Date(2026, 10, 13, 12, 0, 0, 0, time.UTC)
	for _, timestamp := range []string{"invalid", now.Add(2*time.Second).Format(time.RFC3339Nano)} {
		if _, ok := sensorHistoryAge(SensorHistorySample{Timestamp: timestamp}, now); ok {
			t.Fatalf("expected invalid/future timestamp %q to be rejected", timestamp)
		}
	}
	age, ok := sensorHistoryAge(SensorHistorySample{Timestamp: now.Add(-5*time.Second).Format(time.RFC3339Nano)}, now)
	if !ok || age != 5*time.Second {
		t.Fatalf("age = %v, valid = %v; want 5s, true", age, ok)
	}
	_ = fmt.Sprintf("%v", age)
}
