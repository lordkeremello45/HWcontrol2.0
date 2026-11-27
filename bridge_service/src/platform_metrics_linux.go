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
	if err != nil {
		return 0, false
	}
	value, err := strconv.ParseFloat(strings.TrimSpace(string(data)), 64)
	return value, err == nil
}

func readUintFile(path string) (uint64, bool) {
	data, err := os.ReadFile(path)
	if err != nil {
		return 0, false
	}
	value, err := strconv.ParseUint(strings.TrimSpace(string(data)), 10, 64)
	return value, err == nil
}

func readFirstLine(path string) string {
	data, err := os.ReadFile(path)
	if err != nil {
		return ""
	}
	return strings.TrimSpace(strings.SplitN(string(data), "\n", 2)[0])
}

// AMD telemetry uses the kernel's amdgpu/sysfs interfaces, so it works without
// an additional vendor SDK. NVIDIA is handled by nvidia-smi in main.go.
func mergePlatformMetrics(metrics *HardwareMetrics) {
	mergeLinuxPlatformMetrics("/sys", metrics)
}

func mergeLinuxPlatformMetrics(root string, metrics *HardwareMetrics) {
	if metrics == nil {
		return
	}
	cards, _ := filepath.Glob(filepath.Join(root, "class", "drm", "card[0-9]*"))
	for _, card := range cards {
		device := filepath.Join(card, "device")
		if readFirstLine(filepath.Join(device, "vendor")) != "0x1002" {
			continue
		}

		if value, ok := readFloatFile(filepath.Join(device, "gpu_busy_percent")); ok {
			metrics.GPUUsage = value
			metrics.GPUUsageSource = "Linux amdgpu sysfs"
		}
		if value, ok := readUintFile(filepath.Join(device, "mem_info_vram_used")); ok {
			metrics.GPUMemoryUsedBytes = value
		}
		if value, ok := readUintFile(filepath.Join(device, "mem_info_vram_total")); ok {
			metrics.GPUMemoryTotalBytes = value
		}

		hwmons, _ := filepath.Glob(filepath.Join(device, "hwmon", "hwmon*"))
		for _, hwmon := range hwmons {
			if value, ok := readFloatFile(filepath.Join(hwmon, "temp1_input")); ok {
				temperature := value / 1000
				if isValidTemperature(temperature) {
					metrics.GPUTemperature = temperature
					metrics.GPUTemperatureSource = "Linux amdgpu sysfs"
				}
			}
			if value, ok := readFloatFile(filepath.Join(hwmon, "fan1_input")); ok && isFinitePositive(value) {
				metrics.FanRPM = value
				metrics.FanRPMSource = "Linux amdgpu sysfs"
			}
			if value, ok := readFloatFile(filepath.Join(hwmon, "power1_average")); ok && isFinitePositive(value) {
				metrics.PowerWatts = value / 1000000
			}
		}

		metrics.GPUVendor = "AMD"
		metrics.SensorSource = "Linux amdgpu sysfs"
		return
	}
	collectIntelGPUPlatformMetrics(root, metrics)
}

func collectIntelGPUPlatformMetrics(root string, metrics *HardwareMetrics) bool {
	if metrics == nil {
		return false
	}
	cards, _ := filepath.Glob(filepath.Join(root, "class", "drm", "card[0-9]*"))
	for _, card := range cards {
		device := filepath.Join(card, "device")
		if readFirstLine(filepath.Join(device, "vendor")) != "0x8086" {
			continue
		}

		frequencyPaths := []string{
			filepath.Join(device, "gt", "gt0", "gt_act_freq_mhz"),
			filepath.Join(device, "gt", "gt0", "rps_act_freq_mhz"),
			filepath.Join(device, "gt_cur_freq_mhz"),
			filepath.Join(device, "rps_cur_freq_mhz"),
		}
		for _, path := range frequencyPaths {
			if value, ok := readFloatFile(path); ok && isFinitePositive(value) {
				metrics.GPUCoreClockMHz = value
				break
			}
		}
		if value, ok := readUintFile(filepath.Join(device, "mem_info_vram_used")); ok {
			metrics.GPUMemoryUsedBytes = value
		}
		if value, ok := readUintFile(filepath.Join(device, "mem_info_vram_total")); ok {
			metrics.GPUMemoryTotalBytes = value
		}

		hwmons, _ := filepath.Glob(filepath.Join(device, "hwmon", "hwmon*"))
		for _, hwmon := range hwmons {
			if value, ok := readFloatFile(filepath.Join(hwmon, "temp1_input")); ok {
				temperature := value / 1000
				if isValidTemperature(temperature) && temperature > 0 {
					metrics.GPUTemperature = temperature
					metrics.GPUTemperatureSource = "Linux Intel DRM sysfs"
				}
			}
			if value, ok := readFloatFile(filepath.Join(hwmon, "power1_average")); ok && isFinitePositive(value) {
				metrics.PowerWatts = value / 1000000
			}
			if value, ok := readFloatFile(filepath.Join(hwmon, "fan1_input")); ok && isFinitePositive(value) {
				metrics.FanRPM = value
				metrics.FanRPMSource = "Linux Intel DRM sysfs"
			}
		}
		metrics.GPUVendor = "Intel"
		metrics.SensorSource = "Linux Intel DRM sysfs"
		return true
	}
	return false
}
