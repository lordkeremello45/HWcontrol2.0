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

func TestClassifyStorageDeviceOnlyClaimsSupportedEvidence(t *testing.T) {
	tests := []struct {
		device string
		wantType string
		wantRemovable bool
	}{
		{"/dev/nvme0n1p1", "nvme_ssd", false},
		{"/dev/mmcblk0p1", "mmc_storage", false},
		{"/dev/disk/by-id/usb-SanDisk_123", "usb_storage", true},
		{"/dev/sda1", "unknown", false},
		{"E:", "unknown", false},
		{"", "unknown", false},
	}
	for _, test := range tests {
		gotType, source, removable := classifyStorageDevice(test.device)
		if gotType != test.wantType || removable != test.wantRemovable || source == "" {
			t.Errorf("classifyStorageDevice(%q) = (%q, %q, %v), want type %q removable %v",
				test.device, gotType, source, removable, test.wantType, test.wantRemovable)
		}
	}
}
