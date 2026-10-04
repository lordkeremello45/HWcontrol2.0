package main

import (
	"path/filepath"
	"strings"
	"sync"
	"time"

	"github.com/shirou/gopsutil/v3/disk"
)

type StorageVolume struct {
	MountPoint       string   `json:"mountPoint"`
	Device           string   `json:"device"`
	FileSystem       string   `json:"fileSystem"`
	Options          string   `json:"options"`
	TotalBytes       uint64   `json:"totalBytes"`
	UsedBytes        uint64   `json:"usedBytes"`
	FreeBytes        uint64   `json:"freeBytes"`
	UsagePercent     float64  `json:"usagePercent"`
	ReadBytesPerSec  float64  `json:"readBytesPerSec"`
	WriteBytesPerSec float64  `json:"writeBytesPerSec"`
	TemperatureC     *float64 `json:"temperatureC,omitempty"`
	HealthPercent    *float64 `json:"healthPercent,omitempty"`
	HealthStatus     string   `json:"healthStatus"`
	HealthSource     string   `json:"healthSource,omitempty"`
	HealthReason     string   `json:"healthReason,omitempty"`
}

var storageIOState struct {
	sync.Mutex
	At time.Time
	Counters map[string]disk.IOCountersStat
}

func storageDeviceKey(device string) string {
	value := strings.TrimSpace(device)
	if value == "" {
		return ""
	}
	return strings.ToLower(filepath.Clean(value))
}

func storageCounterForVolume(volume StorageVolume, counters map[string]disk.IOCountersStat) (disk.IOCountersStat, bool) {
	keys := []string{
		storageDeviceKey(volume.Device),
		storageDeviceKey(filepath.Base(volume.Device)),
		storageDeviceKey(strings.TrimSuffix(volume.MountPoint, string(filepath.Separator))),
	}
	for _, key := range keys {
		if key == "" {
			continue
		}
		if counter, ok := counters[key]; ok {
			return counter, true
		}
	}
	return disk.IOCountersStat{}, false
}

func collectStorageVolumes() []StorageVolume {
	partitions, err := disk.Partitions(true)
	if err != nil {
		return nil
	}

	now := time.Now()
	counters, _ := disk.IOCounters()
	normalizedCounters := make(map[string]disk.IOCountersStat, len(counters))
	for name, counter := range counters {
		normalizedCounters[storageDeviceKey(name)] = counter
	}

	storageIOState.Lock()
	defer storageIOState.Unlock()

	previousAt := storageIOState.At
	previousCounters := storageIOState.Counters
	storageIOState.At = now
	storageIOState.Counters = normalizedCounters

	elapsed := now.Sub(previousAt).Seconds()
	if elapsed <= 0 {
		elapsed = 0
	}

	volumes := make([]StorageVolume, 0, len(partitions))
	seen := make(map[string]struct{}, len(partitions))
	for _, partition := range partitions {
		mount := strings.TrimSpace(partition.Mountpoint)
		if mount == "" {
			continue
		}
		key := strings.ToLower(filepath.Clean(mount))
		if _, exists := seen[key]; exists {
			continue
		}
		seen[key] = struct{}{}

		usage, err := disk.Usage(mount)
		if err != nil || usage.Total == 0 {
			continue
		}

		volume := StorageVolume{
			MountPoint:   mount,
			Device:       strings.TrimSpace(partition.Device),
			FileSystem:   strings.TrimSpace(partition.Fstype),
			Options:       strings.TrimSpace(strings.Join(partition.Opts, ",")),
			TotalBytes:   usage.Total,
			UsedBytes:    usage.Used,
			FreeBytes:    usage.Free,
			UsagePercent: usage.UsedPercent,
			HealthStatus: "unknown",
			HealthReason: "No platform-specific storage health source is currently configured",
		}

		if previousAt.IsZero() {
			volume.HealthSource = "unavailable"
		} else if counter, ok := storageCounterForVolume(volume, normalizedCounters); ok {
			if previous, previousOK := storageCounterForVolume(volume, previousCounters); previousOK && elapsed > 0 {
				readDelta := float64(counter.ReadBytes - previous.ReadBytes)
				writeDelta := float64(counter.WriteBytes - previous.WriteBytes)
				if counter.ReadBytes < previous.ReadBytes {
					readDelta = 0
				}
				if counter.WriteBytes < previous.WriteBytes {
					writeDelta = 0
				}
				volume.ReadBytesPerSec = readDelta / elapsed
				volume.WriteBytesPerSec = writeDelta / elapsed
			}
			volume.HealthSource = "io-counters"
			volume.HealthReason = "I/O counters available; device health percentage requires a platform-specific reliability backend"
		}

		volumes = append(volumes, volume)
	}
	return volumes
}
