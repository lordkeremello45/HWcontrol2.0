//go:build linux

package main

import (
	"os/exec"
	"path/filepath"
	"strings"

	"github.com/shirou/gopsutil/v3/cpu"
)

func collectHardwareIdentity() HardwareIdentity {
	id := emptyHardwareIdentity()
	id.DetectionSource = "Linux sysfs/proc"
	id.SystemManufacturer = readFirstLine("/sys/class/dmi/id/sys_vendor")
	id.SystemModel = readFirstLine("/sys/class/dmi/id/product_name")
	id.SystemVersion = readFirstLine("/sys/class/dmi/id/product_version")
	id.BIOSVendor = readFirstLine("/sys/class/dmi/id/bios_vendor")
	id.BIOSVersion = readFirstLine("/sys/class/dmi/id/bios_version")
	id.MotherboardVendor = readFirstLine("/sys/class/dmi/id/board_vendor")
	id.MotherboardModel = readFirstLine("/sys/class/dmi/id/board_name")
	id.MotherboardVersion = readFirstLine("/sys/class/dmi/id/board_version")
	if infos, err := cpu.Info(); err == nil && len(infos) > 0 {
		id.CPUManufacturer = infos[0].VendorID
		id.CPUModel = infos[0].ModelName
		if threads, err := cpu.Counts(true); err == nil {
			id.CPUThreads = threads
		}
		if cores, err := cpu.Counts(false); err == nil {
			id.CPUPhysicalCores = cores
		}
	}
	cards, _ := filepath.Glob("/sys/class/drm/card[0-9]*")
	for _, card := range cards {
		device := filepath.Join(card, "device")
		vendor := readFirstLine(filepath.Join(device, "vendor"))
		switch vendor {
		case "0x10de":
			id.GPUVendor = "NVIDIA"
		case "0x1002":
			id.GPUVendor = "AMD"
		case "0x8086":
			id.GPUVendor = "Intel"
		default:
			if vendor != "" {
				id.GPUVendor = vendor
			}
		}
		if link, err := filepath.EvalSymlinks(filepath.Join(device, "driver")); err == nil {
			id.GPUDriver = filepath.Base(link)
		}
		break
	}
	if output, err := exec.Command(platformExecutable("lspci"), "-nn", "-d", "::0300").Output(); err == nil {
		line := strings.TrimSpace(strings.SplitN(string(output), "\n", 2)[0])
		if idx := strings.Index(line, ": "); idx >= 0 {
			id.GPUModel = strings.TrimSpace(line[idx+2:])
		} else {
			id.GPUModel = line
		}
	}
	if id.SystemModel != "" || id.MotherboardModel != "" || id.CPUModel != "" || id.GPUVendor != "" {
		id.DetectionStatus = "ok"
	}
	return id
}
