//go:build windows

package main

import (
	"encoding/json"
	"os/exec"
	"strings"
)

type windowsSensorMetrics struct {
	CPUTemperature float64 `json:"cpuTemperature"`
	GPUTemperature float64 `json:"gpuTemperature"`
	GPUUsage       float64 `json:"gpuUsage"`
	FanRPM         float64 `json:"fanRpm"`
	PowerWatts     float64 `json:"powerWatts"`
	Voltage        float64 `json:"voltage"`
	GPUVendor      string  `json:"gpuVendor"`
	SensorSource   string  `json:"sensorSource"`
}

const windowsSensorScript = `$ErrorActionPreference = 'SilentlyContinue'
$sensors = @(Get-CimInstance -Namespace 'root\LibreHardwareMonitor' -ClassName Sensor)
$cpuTemp = ($sensors | Where-Object { $_.SensorType -eq 'Temperature' -and $_.Name -match 'CPU|Package|Core' } | Select-Object -First 1).Value
$gpu = ($sensors | Where-Object { $_.HardwareType -match 'Gpu' } | Select-Object -First 1)
$gpuTemp = ($sensors | Where-Object { $_.HardwareType -match 'Gpu' -and $_.SensorType -eq 'Temperature' } | Select-Object -First 1).Value
$gpuLoad = ($sensors | Where-Object { $_.HardwareType -match 'Gpu' -and $_.SensorType -eq 'Load' } | Select-Object -First 1).Value
$fan = ($sensors | Where-Object { $_.SensorType -eq 'Fan' } | Select-Object -First 1).Value
$power = ($sensors | Where-Object { $_.SensorType -eq 'Power' -and $_.Name -match 'GPU|Package' } | Select-Object -First 1).Value
$voltage = ($sensors | Where-Object { $_.SensorType -eq 'Voltage' -and $_.Name -match 'GPU|Core' } | Select-Object -First 1).Value
$vendor = if ($gpu.HardwareType) { [string]$gpu.HardwareType } else { 'unknown' }
if (-not $sensors) {
  $acpi = Get-CimInstance -Namespace 'root\wmi' -ClassName MSAcpi_ThermalZoneTemperature | Select-Object -First 1
  $fanObject = Get-CimInstance -ClassName Win32_Fan | Select-Object -First 1
  $voltageObject = Get-CimInstance -ClassName Win32_VoltageProbe | Select-Object -First 1
  $cpuTemp = if ($acpi) { ($acpi.CurrentTemperature / 10) - 273.15 } else { 0 }
  $fan = if ($fanObject) { $fanObject.DesiredSpeed } else { 0 }
  $voltage = if ($voltageObject) { $voltageObject.CurrentReading } else { 0 }
  $vendor = 'WMI fallback'
}
[pscustomobject]@{ cpuTemperature=[double]$cpuTemp; gpuTemperature=[double]$gpuTemp; gpuUsage=[double]$gpuLoad; fanRpm=[double]$fan; powerWatts=[double]$power; voltage=[double]$voltage; gpuVendor=$vendor; sensorSource=$(if ($sensors) { 'LibreHardwareMonitor WMI' } else { 'Windows WMI fallback' }) } | ConvertTo-Json -Compress`

func mergePlatformMetrics(metrics *HardwareMetrics) {
	output, err := exec.Command("powershell.exe", "-NoProfile", "-NonInteractive", "-Command", windowsSensorScript).Output()
	if err != nil || strings.TrimSpace(string(output)) == "" {
		return
	}
	var sensors windowsSensorMetrics
	if json.Unmarshal(output, &sensors) != nil {
		return
	}
	if sensors.CPUTemperature > 0 {
		metrics.CPUTemperature = sensors.CPUTemperature
	}
	if sensors.GPUTemperature > 0 {
		metrics.GPUTemperature = sensors.GPUTemperature
	}
	if sensors.GPUUsage > 0 {
		metrics.GPUUsage = sensors.GPUUsage
	}
	if sensors.FanRPM > 0 {
		metrics.FanRPM = sensors.FanRPM
	}
	if sensors.PowerWatts > 0 {
		metrics.PowerWatts = sensors.PowerWatts
	}
	if sensors.Voltage > 0 {
		metrics.Voltage = sensors.Voltage
	}
	if sensors.GPUVendor != "" && sensors.GPUVendor != "unknown" {
		metrics.GPUVendor = sensors.GPUVendor
	}
	if sensors.SensorSource != "" {
		metrics.SensorSource = sensors.SensorSource
	}
}
