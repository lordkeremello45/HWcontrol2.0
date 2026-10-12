//go:build linux

package main

import (
	"os"
	"path/filepath"
	"strconv"
	"strings"
)

func batteryFile(path string) string {
	data, err := os.ReadFile(path)
	if err != nil {
		return ""
	}
	return strings.TrimSpace(string(data))
}

func batteryNumber(path string) (float64, bool) {
	value, err := strconv.ParseFloat(batteryFile(path), 64)
	return value, err == nil && isFinitePositive(value)
}

func batteryCycleCount(path string) *int {
	value, err := strconv.Atoi(batteryFile(path))
	if err != nil || value < 0 || value > 1000000 {
		return nil
	}
	return &value
}

func mergeBatteryMetrics(metrics *HardwareMetrics) {
	devices, _ := filepath.Glob("/sys/class/power_supply/BAT*")
	for _, device := range devices {
		presentText := batteryFile(filepath.Join(device, "present"))
		if presentText == "0" {
			continue
		}
		status := strings.ToLower(batteryFile(filepath.Join(device, "status")))
		if status == "" {
			status = "unknown"
		}
		var design, full float64
		unit := ""
		if value, ok := batteryNumber(filepath.Join(device, "energy_full_design")); ok {
			design = value / 1000 // Linux sysfs energy values are normally µWh; display mWh.
			if v, ok := batteryNumber(filepath.Join(device, "energy_full")); ok {
				full = v / 1000
			}
			unit = "mWh"
		} else if value, ok := batteryNumber(filepath.Join(device, "charge_full_design")); ok {
			design = value / 1000 // Linux sysfs charge values are normally µAh; display mAh.
			if v, ok := batteryNumber(filepath.Join(device, "charge_full")); ok {
				full = v / 1000
			}
			unit = "mAh"
		}
		metrics.Battery = makeBatteryMetrics(true, status, design, full, unit, batteryCycleCount(filepath.Join(device, "cycle_count")))
		return
	}
	metrics.Battery = BatteryMetrics{Status: "unavailable"}
}
