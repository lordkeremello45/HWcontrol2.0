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
