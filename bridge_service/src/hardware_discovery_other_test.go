//go:build !linux

package main

import "testing"

func TestHardwareDevicesFromIdentityBuildsIdentityOnlyInventory(t *testing.T) {
	identity := HardwareIdentity{
		SystemManufacturer: "Acme", SystemModel: "Model X",
		MotherboardVendor: "BoardCo", MotherboardModel: "B550",
		CPUManufacturer: "CPUCo", CPUModel: "Example CPU",
		GPUVendor: "NVIDIA", GPUModel: "Example GPU", GPUDriver: "display",
		GPUDriverVersion: "1.2.3",
	}
	devices := hardwareDevicesFromIdentity(identity)
	if len(devices) != 4 {
		t.Fatalf("expected system, motherboard, CPU and GPU; got %d", len(devices))
	}
	for _, device := range devices {
		if err := device.Validate(); err != nil {
			t.Fatalf("invalid device: %v", err)
		}
		if len(device.Sensors) != 0 || len(device.Actuators) != 0 || len(device.Capabilities) != 0 {
			t.Fatalf("identity-only discovery fabricated capabilities: %+v", device)
		}
	}
}

func TestHardwareDevicesFromIdentityDoesNotInventMissingGPU(t *testing.T) {
	devices := hardwareDevicesFromIdentity(HardwareIdentity{
		SystemManufacturer: "Apple", SystemModel: "Mac",
		CPUManufacturer: "Apple", CPUModel: "Apple Silicon",
		GPUVendor: "Apple",
	})
	for _, device := range devices {
		if device.Identity.DeviceClass == "gpu" {
			t.Fatal("GPU record was invented without a detected GPU model")
		}
	}
}

func TestIdentityOnlyDeviceIDsAreDeterministicAndOpaque(t *testing.T) {
	a := newIdentityOnlyDevice("NVIDIA", "gpu", "RTX Example", "platform-identity")
	b := newIdentityOnlyDevice("NVIDIA", "gpu", "RTX Example", "platform-identity")
	if a.ID != b.ID || len(a.ID) != 16 {
		t.Fatalf("unexpected deterministic ID: %q %q", a.ID, b.ID)
	}
	if a.ID == "RTX Example" {
		t.Fatal("device ID exposed model text")
	}
}

func TestHardwareDevicesFromIdentityPreservesMultiCPUAndMultiGPUInventory(t *testing.T) {
	identity := HardwareIdentity{
		SystemManufacturer: "Acme", SystemModel: "Workstation",
		CPUs: []HardwareDeviceIdentity{
			{Vendor: "GenuineIntel", DeviceClass: "cpu", Model: "Xeon Example"},
			{Vendor: "GenuineIntel", DeviceClass: "cpu", Model: "Xeon Example"},
		},
		GPUs: []HardwareDeviceIdentity{
			{Vendor: "Intel", DeviceClass: "gpu", ProductID: "VEN_8086&DEV_1234", Model: "Integrated Graphics"},
			{Vendor: "NVIDIA", DeviceClass: "gpu", ProductID: "VEN_10DE&DEV_2684", Model: "GeForce Example", Driver: "NVIDIA", DriverVersion: "1.0"},
		},
	}
	devices := hardwareDevicesFromIdentity(identity)
	cpuCount, gpuCount := 0, 0
	gpuIDs := make(map[string]struct{})
	for _, device := range devices {
		if err := device.Validate(); err != nil {
			t.Fatalf("invalid inventory device: %v", err)
		}
		switch device.Identity.DeviceClass {
		case "cpu":
			cpuCount++
		case "gpu":
			gpuCount++
			gpuIDs[device.ID] = struct{}{}
		}
	}
	if cpuCount != 2 || gpuCount != 2 {
		t.Fatalf("multi-device inventory was truncated: CPUs=%d GPUs=%d devices=%+v", cpuCount, gpuCount, devices)
	}
	if len(gpuIDs) != 2 {
		t.Fatalf("distinct PCI GPU identities collapsed: %+v", devices)
	}
}
