//go:build windows

package main

import (
	"context"
	"encoding/json"
	"os/exec"
	"strings"
	"time"
)

type windowsSensorMetrics struct {
	CPUTemperature float64 `json:"cpuTemperature"`
	GPUTemperature float64 `json:"gpuTemperature"`
	GPUUsage       float64 `json:"gpuUsage"`
	FanRPM         float64 `json:"fanRpm"`
	PowerWatts     float64 `json:"powerWatts"`
	Voltage        float64 `json:"voltage"`
	GPUVendor      string  `json:"gpuVendor"`
	SensorSource       string  `json:"sensorSource"`
	HasCPUTemperature  bool    `json:"hasCpuTemperature"`
	HasGPUTemperature  bool    `json:"hasGpuTemperature"`
}

const windowsSensorScript = `$ErrorActionPreference = 'SilentlyContinue'
$sensors = @(Get-CimInstance -Namespace 'root\LibreHardwareMonitor' -ClassName Sensor)
$cpuTempSensor = $sensors | Where-Object { $_.SensorType -eq 'Temperature' -and $_.Name -match 'CPU|Package|Core' } | Select-Object -First 1
$cpuTemp = $cpuTempSensor.Value
$gpu = $sensors | Where-Object { $_.HardwareType -match 'Gpu' } | Select-Object -First 1
$gpuTempSensor = $sensors | Where-Object { $_.HardwareType -match 'Gpu' -and $_.SensorType -eq 'Temperature' } | Select-Object -First 1
$gpuTemp = $gpuTempSensor.Value
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
  $hasCpuTemperature = ($null -ne $acpi)
  $hasGpuTemperature = $false
  $fan = if ($fanObject) { $fanObject.DesiredSpeed } else { 0 }
  $voltage = if ($voltageObject) { $voltageObject.CurrentReading } else { 0 }
  $vendor = 'WMI fallback'
}
if ($sensors) {
  $hasCpuTemperature = ($null -ne $cpuTempSensor -and $null -ne $cpuTempSensor.Value)
  $hasGpuTemperature = ($null -ne $gpuTempSensor -and $null -ne $gpuTempSensor.Value)
}
[pscustomobject]@{ cpuTemperature=[double]$cpuTemp; gpuTemperature=[double]$gpuTemp; hasCpuTemperature=[bool]$hasCpuTemperature; hasGpuTemperature=[bool]$hasGpuTemperature; gpuUsage=[double]$gpuLoad; fanRpm=[double]$fan; powerWatts=[double]$power; voltage=[double]$voltage; gpuVendor=$vendor; sensorSource=$(if ($sensors) { 'LibreHardwareMonitor WMI' } else { 'Windows WMI fallback' }) } | ConvertTo-Json -Compress`

func mergePlatformMetrics(metrics *HardwareMetrics) {
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()
	command := exec.CommandContext(ctx, "powershell.exe", "-NoProfile", "-NonInteractive", "-Command", windowsSensorScript)
	command.Env = hardwareToolEnvironment()
	output, err := command.Output()
	if err != nil || strings.TrimSpace(string(output)) == "" {
		return
	}
	var sensors windowsSensorMetrics
	if json.Unmarshal(output, &sensors) != nil {
		return
	}
	if sensors.HasCPUTemperature && isValidTemperature(sensors.CPUTemperature) && sensors.SensorSource != "" {
		metrics.CPUTemperature = sensors.CPUTemperature
		metrics.CPUTemperatureSource = sensors.SensorSource
	}
	if sensors.HasGPUTemperature && isValidTemperature(sensors.GPUTemperature) && sensors.SensorSource != "" {
		metrics.GPUTemperature = sensors.GPUTemperature
		metrics.GPUTemperatureSource = sensors.SensorSource
	}
	if isFiniteNonNegative(sensors.GPUUsage) && sensors.GPUUsage <= 100 && sensors.SensorSource != "" {
		metrics.GPUUsage = sensors.GPUUsage
		metrics.GPUUsageSource = sensors.SensorSource
	}
	if isFinitePositive(sensors.FanRPM) {
		metrics.FanRPM = sensors.FanRPM
		metrics.FanRPMSource = sensors.SensorSource
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
