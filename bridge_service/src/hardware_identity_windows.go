//go:build windows

package main

import (
	"encoding/json"
	"os/exec"
	"strings"
)

type windowsHardwareIdentity struct {
	SystemManufacturer string
	SystemModel        string
	SystemVersion      string
	BIOSVendor         string
	BIOSVersion        string
	MotherboardVendor  string
	MotherboardModel   string
	MotherboardVersion string
	CPUManufacturer    string
	CPUModel           string
	CPUPhysicalCores   int
	CPUThreads         int
	GPUVendor          string
	GPUModel           string
	GPUDriver          string
	GPUDriverVersion   string
}

const windowsHardwareIdentityScript = "$ErrorActionPreference='SilentlyContinue'\n" +
	"$cs=Get-CimInstance Win32_ComputerSystem | Select-Object -First 1\n" +
	"$bios=Get-CimInstance Win32_BIOS | Select-Object -First 1\n" +
	"$board=Get-CimInstance Win32_BaseBoard | Select-Object -First 1\n" +
	"$cpu=Get-CimInstance Win32_Processor | Select-Object -First 1\n" +
	"$gpu=Get-CimInstance Win32_VideoController | Where-Object {$_.Name} | Select-Object -First 1\n" +
	"[pscustomobject]@{ systemManufacturer=[string]$cs.Manufacturer; systemModel=[string]$cs.Model; systemVersion=[string]$cs.SystemFamily; biosVendor=[string]$bios.Manufacturer; biosVersion=[string]$bios.SMBIOSBIOSVersion; motherboardVendor=[string]$board.Manufacturer; motherboardModel=[string]$board.Product; motherboardVersion=[string]$board.Version; cpuManufacturer=[string]$cpu.Manufacturer; cpuModel=[string]$cpu.Name; cpuPhysicalCores=[int]$cpu.NumberOfCores; cpuThreads=[int]$cpu.NumberOfLogicalProcessors; gpuVendor=[string]$gpu.AdapterCompatibility; gpuModel=[string]$gpu.Name; gpuDriver=[string]$gpu.DriverProviderName; gpuDriverVersion=[string]$gpu.DriverVersion } | ConvertTo-Json -Compress"

func collectHardwareIdentity() HardwareIdentity {
	id := emptyHardwareIdentity()
	id.DetectionSource = "Windows CIM/WMI"
	output, err := exec.Command("powershell.exe", "-NoProfile", "-NonInteractive", "-Command", windowsHardwareIdentityScript).Output()
	if err != nil || strings.TrimSpace(string(output)) == "" {
		id.DetectionStatus = "unavailable"
		return id
	}
	var raw map[string]any
	if json.Unmarshal(output, &raw) != nil {
		id.DetectionStatus = "unavailable"
		return id
	}
	id.SystemManufacturer = stringValue(raw["systemManufacturer"])
	id.SystemModel = stringValue(raw["systemModel"])
	id.SystemVersion = stringValue(raw["systemVersion"])
	id.BIOSVendor = stringValue(raw["biosVendor"])
	id.BIOSVersion = stringValue(raw["biosVersion"])
	id.MotherboardVendor = stringValue(raw["motherboardVendor"])
	id.MotherboardModel = stringValue(raw["motherboardModel"])
	id.MotherboardVersion = stringValue(raw["motherboardVersion"])
	id.CPUManufacturer = stringValue(raw["cpuManufacturer"])
	id.CPUModel = stringValue(raw["cpuModel"])
	id.CPUPhysicalCores = intValue(raw["cpuPhysicalCores"])
	id.CPUThreads = intValue(raw["cpuThreads"])
	id.GPUVendor = stringValue(raw["gpuVendor"])
	id.GPUModel = stringValue(raw["gpuModel"])
	id.GPUDriver = stringValue(raw["gpuDriver"])
	id.GPUDriverVersion = stringValue(raw["gpuDriverVersion"])
	if id.SystemModel != "" || id.MotherboardModel != "" || id.CPUModel != "" || id.GPUModel != "" {
		id.DetectionStatus = "ok"
	}
	return id
}

func stringValue(value any) string {
	if value == nil {
		return ""
	}
	return strings.TrimSpace(toString(value))
}

func intValue(value any) int {
	switch v := value.(type) {
	case float64:
		return int(v)
	default:
		return 0
	}
}

func toString(value any) string {
	if s, ok := value.(string); ok {
		return s
	}
	return ""
}
