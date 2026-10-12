//go:build darwin

package main

import (
	"context"
	"os/exec"
	"regexp"
	"strconv"
	"strings"
	"time"
)

var ioregBatteryValue = regexp.MustCompile(`"([^"]+)"\s*=\s*(?:"([^"]*)"|([0-9]+))`)

func mergeBatteryMetrics(metrics *HardwareMetrics) {
	ctx, cancel := context.WithTimeout(context.Background(), 4*time.Second)
	defer cancel()
	output, err := exec.CommandContext(ctx, "/usr/sbin/ioreg", "-r", "-c", "AppleSmartBattery", "-l").Output()
	if err != nil || len(output) == 0 || len(output) > 256*1024 {
		metrics.Battery = BatteryMetrics{Status: "unavailable"}
		return
	}
	values := map[string]string{}
	for _, match := range ioregBatteryValue.FindAllStringSubmatch(string(output), -1) {
		if len(match) >= 4 {
			value := match[2]
			if value == "" {
				value = match[3]
			}
			values[match[1]] = value
		}
	}
	if len(values) == 0 {
		metrics.Battery = BatteryMetrics{Status: "unavailable"}
		return
	}
	number := func(key string) float64 {
		value, _ := strconv.ParseFloat(values[key], 64)
		return value
	}
	status := "discharging"
	if strings.EqualFold(values["IsCharging"], "Yes") || values["IsCharging"] == "1" {
		status = "charging"
	} else if strings.EqualFold(values["ExternalConnected"], "Yes") || values["ExternalConnected"] == "1" {
		status = "ac-connected"
	}
	var cycles *int
	if value, err := strconv.Atoi(values["CycleCount"]); err == nil && value >= 0 && value <= 1000000 {
		cycles = &value
	}
	// AppleSmartBattery reports MaxCapacity and DesignCapacity in matching mAh-like
	// units on supported systems. We preserve the unit label instead of claiming Wh.
	metrics.Battery = makeBatteryMetrics(true, status, number("DesignCapacity"), number("MaxCapacity"), "mAh", cycles)
}
