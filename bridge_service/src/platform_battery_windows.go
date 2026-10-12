//go:build windows

package main

import (
	"context"
	"encoding/json"
	"os/exec"
	"strings"
	"time"
)

type windowsBatteryPayload struct {
	Present bool   `json:"present"`
	Status  string `json:"status"`
	Design  float64 `json:"designCapacity"`
	Full    float64 `json:"fullChargeCapacity"`
	Cycles  int    `json:"cycleCount"`
	HasCycle bool  `json:"hasCycleCount"`
}

// WMI values are read-only. The fixed script collects no serial numbers or other
// persistent device identifiers, and the subprocess is bounded by a timeout.
const windowsBatteryScript = `$ErrorActionPreference = 'SilentlyContinue'
$static = Get-CimInstance -Namespace 'root\wmi' -ClassName BatteryStaticData | Select-Object -First 1
$full = Get-CimInstance -Namespace 'root\wmi' -ClassName BatteryFullChargedCapacity | Select-Object -First 1
$cycle = Get-CimInstance -Namespace 'root\wmi' -ClassName BatteryCycleCount | Select-Object -First 1
$battery = Get-CimInstance -ClassName Win32_Battery | Select-Object -First 1
$status = if ($battery) { switch ([int]$battery.BatteryStatus) { 1 {'discharging'} 2 {'ac-connected'} 3 {'full'} 4 {'low'} 5 {'critical'} 6 {'charging'} 7 {'charging-high'} 8 {'charging-low'} 9 {'charging-critical'} 10 {'undefined'} 11 {'partially-charged'} default {'unknown'} } } else { 'unavailable' }
[pscustomobject]@{
 present = [bool]($battery -or $static -or $full)
 status = [string]$status
 designCapacity = [double]$static.DesignedCapacity
 fullChargeCapacity = [double]$full.FullChargedCapacity
 cycleCount = [int]$cycle.CycleCount
 hasCycleCount = [bool]($cycle -and $cycle.CycleCount -ge 0)
} | ConvertTo-Json -Compress`

func mergeBatteryMetrics(metrics *HardwareMetrics) {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	output, err := exec.CommandContext(ctx, "powershell.exe", "-NoProfile", "-NonInteractive", "-Command", windowsBatteryScript).Output()
	if err != nil || len(output) == 0 || len(output) > 64*1024 {
		metrics.Battery = BatteryMetrics{Status: "unavailable"}
		return
	}
	var payload windowsBatteryPayload
	decoder := json.NewDecoder(strings.NewReader(string(output)))
	decoder.DisallowUnknownFields()
	if decoder.Decode(&payload) != nil {
		metrics.Battery = BatteryMetrics{Status: "unavailable"}
		return
	}
	var cycles *int
	if payload.HasCycle && payload.Cycles >= 0 && payload.Cycles <= 1000000 {
		cycles = &payload.Cycles
	}
	metrics.Battery = makeBatteryMetrics(payload.Present, payload.Status, payload.Design, payload.Full, "mWh", cycles)
}
