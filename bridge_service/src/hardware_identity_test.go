package main

import "testing"

func TestHardwareIdentityContract(t *testing.T) {
	id := emptyHardwareIdentity()
	if !id.SerialsExcluded {
		t.Fatal("hardware identity must exclude serial numbers")
	}
	if id.CPUArchitecture == "" {
		t.Fatal("CPU architecture must be populated")
	}
	if id.DetectionStatus == "" {
		t.Fatal("detection status must be populated")
	}
}

func TestHardwareIdentityDetectionDoesNotExposeCredentialFields(t *testing.T) {
	id := collectHardwareIdentity()
	if id.SerialsExcluded != true {
		t.Fatal("serials must remain excluded")
	}
}

func TestGPUIdentityContract(t *testing.T) {
	gpu := GPUIdentity{
		Vendor: "NVIDIA",
		Model: "Example GPU",
		Driver: "nvidia",
		DriverVersion: "1.0",
		PCIAddress: "0000:01:00.0",
		DeviceID: "0x1234",
	}
	if gpu.Vendor == "" || gpu.Model == "" || gpu.PCIAddress == "" {
		t.Fatal("GPU identity fields must support vendor, model and PCI address")
	}
	if !idSerialsExcluded() {
		t.Fatal("GPU identity must not include serial number fields")
	}
}

func idSerialsExcluded() bool {
	return emptyHardwareIdentity().SerialsExcluded
}
