package main

import (
	"os"
	"testing"
)

func TestHardwareControlSafetyGateFailsClosed(t *testing.T) {
    base := HardwareMetrics{
        ThermalSafetyAvailable: true,
        FanControlSupported:    true,
        FanControlBackend:      "test-backend",
        CPUTemperature:         60,
        GPUTemperature:         60,
    }
    cmd := Command{Action: "Fan Hızı", Value: 50}

    if err := validateFanControlRequest(cmd, base); err != nil {
        t.Fatalf("expected safe fan command to pass: %v", err)
    }

    cases := []struct {
        name    string
        metrics HardwareMetrics
    }{
        {
            name: "no thermal telemetry",
            metrics: HardwareMetrics{
                ThermalSafetyAvailable: false,
                FanControlSupported:    true,
                FanControlBackend:      "test-backend",
                CPUTemperature:         60,
                GPUTemperature:         60,
            },
        },
        {
            name: "critical CPU temperature",
            metrics: HardwareMetrics{
                ThermalSafetyAvailable: true,
                FanControlSupported:    true,
                FanControlBackend:      "test-backend",
                CPUTemperature:         95,
                GPUTemperature:         60,
            },
        },
        {
            name: "critical GPU temperature",
            metrics: HardwareMetrics{
                ThermalSafetyAvailable: true,
                FanControlSupported:    true,
                FanControlBackend:      "test-backend",
                CPUTemperature:         60,
                GPUTemperature:         95,
            },
        },
        {
            name: "monitor only",
            metrics: HardwareMetrics{
                ThermalSafetyAvailable: true,
                FanControlSupported:    false,
                FanControlBackend:      "monitor-only",
                CPUTemperature:         60,
                GPUTemperature:         60,
            },
        },
    }

    for _, tc := range cases {
        t.Run(tc.name, func(t *testing.T) {
            if err := validateFanControlRequest(cmd, tc.metrics); err == nil {
                t.Fatal("expected fan-control request to be denied")
            }
        })
    }
}

func TestHardwareControlSafetyGateDoesNotAffectReadOnlyCommands(t *testing.T) {
    metrics := HardwareMetrics{
        ThermalSafetyAvailable: false,
        FanControlSupported:    false,
        FanControlBackend:      "monitor-only",
        CPUTemperature:         120,
        GPUTemperature:         120,
    }
    if err := validateFanControlRequest(Command{Action: "Get Status"}, metrics); err != nil {
        t.Fatalf("read-only command should not enter fan-control gate: %v", err)
    }
}


func TestHardwareControlDeniedDuringSecurityPanic(t *testing.T) {
	dir := t.TempDir()
	t.Setenv("HWCONTROL_PANIC_FILE", dir+"/panic-mode.json")
	if err := os.WriteFile(dir+"/panic-mode.json", []byte(`{"panic":true}
`), 0600); err != nil {
		t.Fatal(err)
	}
	if err := executeHardwareCommand(Command{Action: "Set Game Mode", Value: 100}); err == nil {
		t.Fatal("expected Game Mode control to be denied during panic mode")
	}
}
