package main

import (
	"encoding/json"
	"strings"
	"testing"
)

func TestParseLiquidctlStatusNormalizesIndependentCoolingReadings(t *testing.T) {
	input := []byte(`[
	  {
	    "bus":"hid",
	    "address":"/dev/hidraw3",
	    "description":"NZXT Kraken X",
	    "serial_number":"DO-NOT-EXPORT",
	    "status":[
	      {"key":"Liquid temperature","value":30.1,"unit":"°C"},
	      {"key":"Pump speed","value":2400,"unit":"rpm"},
	      {"key":"Fan speed","value":1014,"unit":"rpm"},
	      {"key":"Firmware version","value":"1.2","unit":""}
	    ]
	  }
	]`)

	status, err := parseLiquidctlStatus(input)
	if err != nil {
		t.Fatalf("parse liquidctl status: %v", err)
	}
	if status.State != "available" || len(status.Devices) != 1 {
		t.Fatalf("unexpected discovery status: %+v", status)
	}
	device := status.Devices[0]
	if device.Name != "NZXT Kraken X" || device.Backend != "liquidctl" || device.State != "available" {
		t.Fatalf("unexpected device metadata: %+v", device)
	}
	if len(device.ID) != 16 || len(device.Readings) != 3 {
		t.Fatalf("device identity or readings are invalid: %+v", device)
	}
	kinds := map[string]bool{}
	for _, reading := range device.Readings {
		kinds[reading.Kind] = true
	}
	for _, kind := range []string{"coolantTemperature", "pumpRPM", "fanRPM"} {
		if !kinds[kind] {
			t.Fatalf("missing normalized %s reading: %+v", kind, device.Readings)
		}
	}
	encoded, err := json.Marshal(status)
	if err != nil {
		t.Fatalf("marshal normalized status: %v", err)
	}
	if strings.Contains(string(encoded), "DO-NOT-EXPORT") || strings.Contains(string(encoded), "/dev/hidraw3") {
		t.Fatalf("private/raw device identifiers leaked into public telemetry: %s", encoded)
	}
}

func TestParseLiquidctlStatusRejectsUnknownOrInvalidMeasurements(t *testing.T) {
	input := []byte(`[{"description":"Controller","status":[
		{"key":"Liquid temperature","value":999,"unit":"°C"},
		{"key":"Pump speed","value":-1,"unit":"rpm"},
		{"key":"Fan speed","value":55,"unit":"percent"},
		{"key":"Flow rate","value":2.5,"unit":"L/min"}
	]}]`)
	status, err := parseLiquidctlStatus(input)
	if err != nil {
		t.Fatalf("parse valid JSON with unsupported measurements: %v", err)
	}
	if status.State != "available" || len(status.Devices) != 1 {
		t.Fatalf("expected the explicitly valid flow reading to remain available: %+v", status)
	}
	if len(status.Devices[0].Readings) != 1 || status.Devices[0].Readings[0].Kind != "flowRate" {
		t.Fatalf("invalid or unknown measurements were not filtered: %+v", status.Devices[0].Readings)
	}
}

func TestParseLiquidctlStatusHandlesEmptyAndMalformedResponses(t *testing.T) {
	empty, err := parseLiquidctlStatus([]byte("[]"))
	if err != nil || empty.State != "unavailable" {
		t.Fatalf("empty status should report unavailable, got %+v err=%v", empty, err)
	}
	if _, err := parseLiquidctlStatus([]byte("{broken")); err == nil {
		t.Fatal("malformed JSON must be rejected")
	}
	if _, err := parseLiquidctlStatus([]byte("[] []")); err == nil {
		t.Fatal("trailing JSON values must be rejected")
	}
}

func TestNormalizeCoolingReadingConvertsFahrenheit(t *testing.T) {
	reading, ok := normalizeCoolingReading(liquidctlStatusValue{
		Key: "Coolant temperature", Value: 86.0, Unit: "°F",
	})
	if !ok || reading.Kind != "coolantTemperature" || reading.Value < 29.9 || reading.Value > 30.1 || reading.Unit != "°C" {
		t.Fatalf("Fahrenheit conversion failed: %+v ok=%v", reading, ok)
	}
}

func TestAddLiquidCoolingCapabilitiesMapsNormalizedReadingNames(t *testing.T) {
	status := LiquidCoolingStatus{
		State:   "available",
		Backend: "liquidctl",
		Devices: []LiquidCoolingDevice{{
			State:    "available",
			Readings: []CoolingReading{
				{Kind: "coolantTemperature", Value: 31, Unit: "°C"},
				{Kind: "pumpRPM", Value: 2400, Unit: "RPM"},
				{Kind: "fanRPM", Value: 1000, Unit: "RPM"},
				{Kind: "flowRate", Value: 2.5, Unit: "L/min"},
				{Kind: "coolantLevel", Value: 80, Unit: "%"},
			},
		}},
	}
	capabilities := make(map[string]HardwareCapability)
	addLiquidCoolingCapabilities(capabilities, status)
	for _, key := range []string{"liquidCooling", "coolantTemperature", "pumpRPM", "coolingFanRPM", "coolingFlowRate", "coolantLevel"} {
		if !capabilities[key].Available {
			t.Fatalf("capability %q should map to a validated reading: %#v", key, capabilities[key])
		}
	}
	if capabilities["leakDetection"].Available {
		t.Fatal("leak detection must remain unavailable without an explicit validated reading")
	}
}
