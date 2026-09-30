package main

import "testing"

func TestStorageVolumeUsageFields(t *testing.T) {
	volume := StorageVolume{MountPoint: "E:", TotalBytes: 1000, UsedBytes: 900, FreeBytes: 100}
	volume.UsagePercent = float64(volume.UsedBytes) / float64(volume.TotalBytes) * 100
	if volume.UsagePercent != 90 {
		t.Fatalf("usage = %v, want 90", volume.UsagePercent)
	}
	if volume.HealthStatus != "" {
		t.Fatalf("zero-value health status = %q", volume.HealthStatus)
	}
}

func TestStorageDeviceKeyNormalizesNames(t *testing.T) {
	if storageDeviceKey("NVMe0n1") != storageDeviceKey("nvme0n1") {
		t.Fatal("storage device key should be case-insensitive")
	}
}
