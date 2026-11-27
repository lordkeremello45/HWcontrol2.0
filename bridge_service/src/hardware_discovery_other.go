//go:build !linux

package main

import (
	"crypto/sha256"
	"encoding/hex"
	"strconv"
	"strings"
)

// discoverRuntimeHardwareDevices uses the platform's existing identity
// collector. It deliberately reports identity-only devices: no sensor or
// actuator capability is inferred from a model name.
func discoverRuntimeHardwareDevices() []HardwareDevice {
	return hardwareDevicesFromIdentity(collectHardwareIdentity())
}

func hardwareDevicesFromIdentity(identity HardwareIdentity) []HardwareDevice {
	devices := make([]HardwareDevice, 0, 4)
	if model := safeDiscoveryText(identity.SystemModel); model != "" {
		vendor := safeDiscoveryText(identity.SystemManufacturer)
		if vendor == "" {
			vendor = "Unknown"
		}
		devices = append(devices, newIdentityOnlyDevice(vendor, "system", model, "platform-identity"))
	}
	if model := safeDiscoveryText(identity.MotherboardModel); model != "" {
		vendor := safeDiscoveryText(identity.MotherboardVendor)
		if vendor == "" {
			vendor = "Unknown"
		}
		devices = append(devices, newIdentityOnlyDevice(vendor, "motherboard", model, "platform-identity"))
	}
	cpuInventory := identity.CPUs
	if len(cpuInventory) == 0 && safeDiscoveryText(identity.CPUModel) != "" {
		cpuInventory = []HardwareDeviceIdentity{{
			Vendor: identity.CPUManufacturer, DeviceClass: "cpu", Model: identity.CPUModel,
		}}
	}
	for index, cpu := range cpuInventory {
		vendor := safeDiscoveryText(cpu.Vendor)
		if vendor == "" {
			vendor = "Unknown"
		}
		model := safeDiscoveryText(cpu.Model)
		if model == "" {
			continue
		}
		discriminator := ""
		if len(cpuInventory) > 1 {
			discriminator = "cpu-" + strconv.Itoa(index)
		}
		devices = append(devices, newIdentityOnlyDeviceWithDiscriminator(vendor, "cpu", model, "platform-identity", discriminator))
	}

	gpuInventory := identity.GPUs
	if len(gpuInventory) == 0 && safeDiscoveryText(identity.GPUModel) != "" {
		gpuInventory = []HardwareDeviceIdentity{{
			Vendor: identity.GPUVendor, DeviceClass: "gpu", Model: identity.GPUModel,
			Driver: identity.GPUDriver, DriverVersion: identity.GPUDriverVersion,
		}}
	}
	for index, gpu := range gpuInventory {
		vendor := safeDiscoveryText(gpu.Vendor)
		if vendor == "" {
			vendor = "Unknown"
		}
		model := safeDiscoveryText(gpu.Model)
		if model == "" {
			continue
		}
		discriminator := safeDiscoveryText(gpu.ProductID)
		if len(gpuInventory) > 1 {
			instanceKey := "gpu-" + strconv.Itoa(index)
			if discriminator != "" {
				instanceKey += "-" + discriminator
			}
			discriminator = instanceKey
		}
		device := newIdentityOnlyDeviceWithDiscriminator(vendor, "gpu", model, "platform-identity", discriminator)
		device.Identity.ProductID = safeDiscoveryText(gpu.ProductID)
		device.Identity.Driver = safeDiscoveryText(gpu.Driver)
		device.Identity.DriverVersion = safeDiscoveryText(gpu.DriverVersion)
		devices = append(devices, device)
	}
	return deduplicateAndValidateHardwareDevices(devices)
}

func newIdentityOnlyDevice(vendor, class, model, backend string) HardwareDevice {
	return newIdentityOnlyDeviceWithDiscriminator(vendor, class, model, backend, "")
}

func newIdentityOnlyDeviceWithDiscriminator(vendor, class, model, backend, discriminator string) HardwareDevice {
	identityParts := []string{
		strings.ToLower(strings.TrimSpace(vendor)),
		strings.ToLower(strings.TrimSpace(class)),
		strings.ToLower(strings.TrimSpace(model)),
	}
	if strings.TrimSpace(discriminator) != "" {
		identityParts = append(identityParts, strings.ToLower(strings.TrimSpace(discriminator)))
	}
	sum := sha256.Sum256([]byte(strings.Join(identityParts, "|")))
	return HardwareDevice{
		ID: hex.EncodeToString(sum[:8]),
		Identity: HardwareDeviceIdentity{
			Vendor: vendor, DeviceClass: class, Model: model,
		},
		Backend: backend,
	}
}

func safeDiscoveryText(value string) string {
	value = strings.TrimSpace(value)
	if len(value) > 512 {
		value = value[:512]
	}
	return strings.Map(func(r rune) rune {
		if r < 0x20 && r != '\t' {
			return -1
		}
		return r
	}, value)
}

func deduplicateAndValidateHardwareDevices(devices []HardwareDevice) []HardwareDevice {
	result := make([]HardwareDevice, 0, len(devices))
	seen := make(map[string]struct{}, len(devices))
	for _, device := range devices {
		if _, exists := seen[device.ID]; exists {
			continue
		}
		if device.Validate() != nil {
			continue
		}
		seen[device.ID] = struct{}{}
		result = append(result, device)
	}
	return result
}
