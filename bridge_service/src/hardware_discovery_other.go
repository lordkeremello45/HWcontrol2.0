//go:build !linux

package main

import (
	"crypto/sha256"
	"encoding/hex"
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
	if model := safeDiscoveryText(identity.CPUModel); model != "" {
		vendor := safeDiscoveryText(identity.CPUManufacturer)
		if vendor == "" {
			vendor = "Unknown"
		}
		devices = append(devices, newIdentityOnlyDevice(vendor, "cpu", model, "platform-identity"))
	}
	if model := safeDiscoveryText(identity.GPUModel); model != "" {
		vendor := safeDiscoveryText(identity.GPUVendor)
		if vendor == "" {
			vendor = "Unknown"
		}
		device := newIdentityOnlyDevice(vendor, "gpu", model, "platform-identity")
		device.Identity.Driver = safeDiscoveryText(identity.GPUDriver)
		device.Identity.DriverVersion = safeDiscoveryText(identity.GPUDriverVersion)
		devices = append(devices, device)
	}
	return deduplicateAndValidateHardwareDevices(devices)
}

func newIdentityOnlyDevice(vendor, class, model, backend string) HardwareDevice {
	identityKey := strings.Join([]string{
		strings.ToLower(strings.TrimSpace(vendor)),
		strings.ToLower(strings.TrimSpace(class)),
		strings.ToLower(strings.TrimSpace(model)),
	}, "|")
	sum := sha256.Sum256([]byte(identityKey))
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
