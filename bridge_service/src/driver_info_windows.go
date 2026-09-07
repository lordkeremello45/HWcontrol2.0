//go:build windows

package main

import (
	"encoding/json"
	"os/exec"
	"strings"
)

type windowsDriverInfo struct {
	Provider string `json:"provider"`
	Version string `json:"version"`
	Name string `json:"name"`
	Signed bool `json:"signed"`
}

const windowsDriverScript = `$ErrorActionPreference = 'SilentlyContinue'
$driver = Get-CimInstance Win32_PnPSignedDriver | Where-Object { $_.DeviceClass -eq 'DISPLAY' -and $_.Status -eq 'OK' } | Select-Object -First 1
if ($driver) { [pscustomobject]@{ provider=[string]$driver.DriverProviderName; version=[string]$driver.DriverVersion; name=[string]$driver.FriendlyName; signed=[bool]$driver.IsSigned } | ConvertTo-Json -Compress }`

func mergeDriverInfo(metrics *HardwareMetrics) {
	output, err := exec.Command("powershell.exe", "-NoProfile", "-NonInteractive", "-Command", windowsDriverScript).Output()
	if err != nil || strings.TrimSpace(string(output)) == "" {
		if metrics.GPUDriverStatus == "" { metrics.GPUDriverStatus = "unavailable" }
		metrics.GPUDriverSource = "Windows PnP"
		return
	}
	var info windowsDriverInfo
	if json.Unmarshal(output, &info) != nil { return }
	if info.Provider != "" { metrics.GPUDriverProvider = info.Provider }
	if info.Version != "" { metrics.GPUDriverVersion = info.Version }
	if metrics.GPUDriver == "" { metrics.GPUDriver = info.Provider }
	if info.Name != "" && metrics.GPUName == "" { metrics.GPUName = info.Name }
	metrics.GPUDriverStatus = "ok"
	metrics.GPUDriverSource = "Windows PnP"
	if !info.Signed { metrics.GPUDriverStatus = "unsigned" }
}
