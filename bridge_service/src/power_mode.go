package main

import "fmt"

// PowerModeState describes the user-configured OS power mode. It deliberately
// does not claim that the effective CPU/GPU performance state is guaranteed.
type PowerModeState struct {
	Supported bool   `json:"supported"`
	Platform  string `json:"platform"`
	AC        string `json:"ac"`
	DC        string `json:"dc"`
	Message   string `json:"message"`
}

const (
	powerModeBalanced   = 0.0
	powerModeEfficiency = 50.0
	powerModePerformance = 100.0
)

func powerModeName(value float64) (string, bool) {
	switch value {
	case powerModeBalanced:
		return "Balanced", true
	case powerModeEfficiency:
		return "Best Power Efficiency", true
	case powerModePerformance:
		return "Best Performance", true
	default:
		return "", false
	}
}

func validatePowerModeRequest(action string, value float64) error {
	if action != "Set Power Mode AC" && action != "Set Power Mode DC" {
		return fmt.Errorf("unsupported power mode action")
	}
	if _, ok := powerModeName(value); !ok {
		return fmt.Errorf("power mode value must be 0 (Balanced), 50 (Best Power Efficiency), or 100 (Best Performance)")
	}
	return nil
}
