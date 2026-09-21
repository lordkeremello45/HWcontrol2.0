//go:build !linux && !windows && !darwin

package main

func collectHardwareIdentity() HardwareIdentity {
	id := emptyHardwareIdentity()
	id.DetectionSource = "unsupported platform"
	id.DetectionStatus = "unsupported"
	return id
}
