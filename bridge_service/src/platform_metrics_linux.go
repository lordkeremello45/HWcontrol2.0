//go:build linux

package main

import (
	"os"
	"path/filepath"
	"strconv"
	"strings"
)

func readFloatFile(path string) (float64, bool) {
	data, err := os.ReadFile(path)
	if err != nil { return 0, false }
	value, err := strconv.ParseFloat(strings.TrimSpace(string(data)), 64)
	return value, err == nil
}

func readUintFile(path string) (uint64, bool) {
	data, err := os.ReadFile(path)
	if err != nil { return 0, false }
	value, err := strconv.ParseUint(strings.TrimSpace(string(data)), 10, 64)
	return value, err == nil
}

func readFirstLine(path string) string {
	data, err := os.ReadFile(path)
	if err != nil { return "" }
	return strings.TrimSpace(strings.SplitN(string(data), "\n", 2)[0])
}

// AMD telemetry uses the kernel's amdgpu/sysfs interfaces, so it works without
// an additional vendor SDK. NVIDIA is handled by nvidia-smi in main.go.
func mergePlatformMetrics(metrics *HardwareMetrics) {
	cards, _ := filepath.Glob("/sys/class/drm/card[0-9]*")
	for _, card := range cards {
		device := filepath.Join(card, "device")
		if readFirstLine(filepath.Join(device, "vendor")) != "0x1002" { continue }

		if value, ok := readFloatFile(filepath.Join(device, "gpu_busy_percent")); ok {
			metrics.GPUUsage = value
		}
		if value, ok := readUintFile(filepath.Join(device, "mem_info_vram_used")); ok {
			metrics.GPUMemoryUsedBytes = value
		}
		if value, ok := readUintFile(filepath.Join(device, "mem_info_vram_total")); ok {
			metrics.GPUMemoryTotalBytes = value
		}
		if value, ok := readFloatFile(filepath.Join(device, "power1_average")); ok {
			metrics.PowerWatts = value / 1000000
		}

		hwmons, _ := filepath.Glob(filepath.Join(device, "hwmon", "hwmon*"))
		for _, hwmon := range hwmons {
			if value, ok := readFloatFile(filepath.Join(hwmon, "temp1_input")); ok {
				metrics.GPUTemperature = value / 1000
			}
			if value, ok := readFloatFile(filepath.Join(hwmon, "fan1_input")); ok {
				metrics.FanRPM = value
			}
		}

		metrics.GPUVendor = "AMD"
		metrics.SensorSource = "Linux amdgpu sysfs"
		if metrics.GPUName == "" {
			// uevent gives us a stable PCI identity even when a human-readable
			// product name is not exposed by the kernel.
			metrics.GPUName = readFirstLine(filepath.Join(device, "uevent"))
		}
		return
	}
}
