//go:build linux

package main

import (
	"os"
	"path/filepath"
	"strings"
)

func mergeDriverInfo(metrics *HardwareMetrics) {
	cards, _ := filepath.Glob("/sys/class/drm/card[0-9]*")
	for _, card := range cards {
		device := filepath.Join(card, "device")
		vendor := strings.TrimSpace(readFirstLine(filepath.Join(device, "vendor")))
		if vendor == "" {
			continue
		}

		driverLink, err := os.Readlink(filepath.Join(device, "driver"))
		if err != nil {
			continue
		}
		driver := filepath.Base(driverLink)
		version := readFirstLine(filepath.Join(device, "driver", "module", "version"))

		if metrics.GPUVendor == "" {
			switch vendor {
			case "0x1002":
				metrics.GPUVendor = "AMD"
			case "0x10de":
				metrics.GPUVendor = "NVIDIA"
			case "0x8086":
				metrics.GPUVendor = "Intel"
			}
		}
		if metrics.GPUDriver == "" {
			metrics.GPUDriver = driver
		}
		metrics.GPUDriverStatus = "ok"
		metrics.GPUDriverSource = "Linux sysfs"
		if version != "" {
			metrics.GPUDriverVersion = version
		}
		return
	}

	if metrics.GPUDriver == "" {
		metrics.GPUDriverStatus = "unavailable"
		metrics.GPUDriverSource = "Linux sysfs"
	}
}
