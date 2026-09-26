//go:build linux

package main

import (
	"fmt"
	"os"
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
		id.CPUBaseClockMHz = linuxCPUFrequencyMHz("/sys/devices/system/cpu/cpu0/cpufreq/base_frequency")
		id.CPUMaxClockMHz = linuxCPUFrequencyMHz("/sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq")
	}
	gpuModels := linuxGPUModels()
	cards, _ := filepath.Glob("/sys/class/drm/card[0-9]*")
	for _, card := range cards {
		device := filepath.Join(card, "device")
		vendor := readFirstLine(filepath.Join(device, "vendor"))
		if vendor == "" {
			continue
		}
		gpu := GPUIdentity{
			Vendor: vendorName(vendor),
			DeviceID: readFirstLine(filepath.Join(device, "device")),
			MemoryBytes: linuxGPUBytes(filepath.Join(device, "mem_info_vram_total")),
		}
		if link, err := filepath.EvalSymlinks(filepath.Join(device, "driver")); err == nil {
			gpu.Driver = filepath.Base(link)
		}
		if address, err := filepath.EvalSymlinks(device); err == nil {
			gpu.PCIAddress = filepath.Base(address)
		}
		gpu.Model = gpuModels[gpu.PCIAddress]
		id.GPUs = append(id.GPUs, gpu)
		if id.GPUVendor == "" {
			id.GPUVendor = gpu.Vendor
			id.GPUDriver = gpu.Driver
			id.GPUModel = gpu.Model
		}
	}
	if len(id.GPUs) == 0 {
		if output, err := exec.Command("lspci", "-nn", "-D", "-d", "::0300").Output(); err == nil {
			line := strings.TrimSpace(strings.SplitN(string(output), "\n", 2)[0])
			if idx := strings.Index(line, ": "); idx >= 0 {
				id.GPUModel = strings.TrimSpace(line[idx+2:])
			} else {
				id.GPUModel = line
			}
		}
	}
	if id.SystemModel != "" || id.MotherboardModel != "" || id.CPUModel != "" || id.GPUVendor != "" {
		id.DetectionStatus = "ok"
	}
	return id
}

func vendorName(vendor string) string {
	switch strings.TrimSpace(vendor) {
	case "0x10de":
		return "NVIDIA"
	case "0x1002":
		return "AMD"
	case "0x8086":
		return "Intel"
	default:
		return strings.TrimSpace(vendor)
	}
}

func linuxGPUBytes(path string) uint64 {
	data, err := os.ReadFile(path)
	if err != nil {
		return 0
	}
	value := strings.TrimSpace(string(data))
	var bytes uint64
	if _, err := fmt.Sscanf(value, "%d", &bytes); err != nil {
		return 0
	}
	return bytes
}

func linuxGPUModels() map[string]string {
	models := make(map[string]string)
	for _, class := range []string{"::0300", "::0302"} {
		output, err := exec.Command("lspci", "-D", "-nn", "-d", class).Output()
		if err != nil {
			continue
		}
		for _, line := range strings.Split(string(output), "\n") {
			line = strings.TrimSpace(line)
			if line == "" {
				continue
			}
			colon := strings.Index(line, ": ")
			if colon < 0 {
				continue
			}
			address := strings.TrimSpace(line[:colon])
			model := strings.TrimSpace(line[colon+2:])
			if bracket := strings.Index(model, " ["); bracket >= 0 {
				model = strings.TrimSpace(model[:bracket])
			}
			if model != "" {
				models[address] = model
			}
		}
	}
	return models
}

func linuxCPUFrequencyMHz(path string) float64 {
	data, err := os.ReadFile(path)
	if err != nil {
		return 0
	}
	var khz uint64
	if _, err := fmt.Sscanf(strings.TrimSpace(string(data)), "%d", &khz); err != nil {
		return 0
	}
	return float64(khz) / 1000
}
