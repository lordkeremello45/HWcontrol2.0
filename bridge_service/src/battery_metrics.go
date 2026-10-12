package main

import "math"

// BatteryMetrics reports battery wear metadata only. It does not infer remaining
// runtime from health and never changes charging or power-management settings.
type BatteryMetrics struct {
	Present             bool    `json:"present"`
	Status              string  `json:"status"`
	DataAvailable       bool    `json:"dataAvailable"`
	DesignCapacity      float64 `json:"designCapacity"`
	FullChargeCapacity  float64 `json:"fullChargeCapacity"`
	CapacityUnit        string  `json:"capacityUnit"`
	HealthPercent       float64 `json:"healthPercent"`
	CycleCount          *int    `json:"cycleCount,omitempty"`
}

func makeBatteryMetrics(present bool, status string, design, full float64, unit string, cycles *int) BatteryMetrics {
	result := BatteryMetrics{
		Present: present,
		Status: status,
		CapacityUnit: unit,
		CycleCount: cycles,
	}
	if !present || !isFinitePositive(design) || !isFinitePositive(full) || unit == "" {
		return result
	}
	result.DataAvailable = true
	result.DesignCapacity = design
	result.FullChargeCapacity = full
	result.HealthPercent = full / design * 100
	if math.IsNaN(result.HealthPercent) || math.IsInf(result.HealthPercent, 0) {
		result.DataAvailable = false
		result.DesignCapacity = 0
		result.FullChargeCapacity = 0
		result.HealthPercent = 0
	}
	return result
}

func isFinitePositive(value float64) bool {
	return value > 0 && !math.IsNaN(value) && !math.IsInf(value, 0)
}
