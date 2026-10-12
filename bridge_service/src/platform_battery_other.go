//go:build !windows && !linux && !darwin

package main

func mergeBatteryMetrics(metrics *HardwareMetrics) {
	metrics.Battery = BatteryMetrics{Status: "unsupported"}
}
