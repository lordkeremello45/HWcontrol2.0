package main

import (
	"bytes"
	"context"
	"encoding/json"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strconv"
	"strings"
	"sync"
	"time"
)

type smartctlReport struct {
	SmartStatus struct {
		Passed *bool `json:"passed"`
	} `json:"smart_status"`
	Temperature struct {
		Current *float64 `json:"current"`
	} `json:"temperature"`
	NVMeHealth struct {
		PercentageUsed *float64 `json:"percentage_used"`
	} `json:"nvme_smart_health_information_log"`
}

type storageHealthResult struct {
	status        string
	source        string
	reason        string
	temperature   *float64
	healthPercent *float64
}

var storageHealthCache = struct {
	sync.Mutex
	entries map[string]struct {
		at     time.Time
		result storageHealthResult
	}
}{entries: make(map[string]struct {
	at     time.Time
	result storageHealthResult
})}

// linuxPhysicalDevice maps a mounted Linux partition to its parent block device.
// It returns an empty string when sysfs cannot prove the mapping.
func linuxPhysicalDevice(device string) string {
	if runtime.GOOS != "linux" || !strings.HasPrefix(filepath.Clean(device), "/dev/") {
		return ""
	}
	base := filepath.Base(device)
	candidates := []string{base}
	if strings.HasPrefix(base, "nvme") || strings.HasPrefix(base, "mmcblk") {
		if p := strings.LastIndex(base, "p"); p > 0 && p < len(base)-1 {
			if _, err := strconv.Atoi(base[p+1:]); err == nil {
				candidates = append(candidates, base[:p])
			}
		}
	} else {
		trimmed := strings.TrimRight(base, "0123456789")
		if trimmed != base {
			candidates = append(candidates, trimmed)
		}
	}
	for _, candidate := range candidates {
		if candidate == "" {
			continue
		}
		if _, err := os.Stat(filepath.Join("/sys/class/block", candidate)); err == nil {
			return filepath.Join("/dev", candidate)
		}
	}
	return ""
}

func parseSmartctlReport(data []byte) storageHealthResult {
	var report smartctlReport
	if err := json.Unmarshal(data, &report); err != nil {
		return storageHealthResult{status: "unknown", source: "smartctl", reason: "SMART report was not valid JSON"}
	}
	result := storageHealthResult{status: "unknown", source: "smartctl", reason: "Drive did not provide a supported health indicator"}
	if report.SmartStatus.Passed != nil {
		if *report.SmartStatus.Passed {
			result.status = "healthy"
			result.reason = "Device-reported SMART overall status is passing"
		} else {
			result.status = "warning"
			result.reason = "Device-reported SMART overall status is failing"
		}
	}
	if report.Temperature.Current != nil && *report.Temperature.Current >= -20 && *report.Temperature.Current <= 125 {
		value := *report.Temperature.Current
		result.temperature = &value
	}
	var used *float64
	if report.NVMeHealth.PercentageUsed != nil {
		used = report.NVMeHealth.PercentageUsed
	}
	if used != nil && *used >= 0 && *used <= 1000 {
		value := 100 - *used
		if value < 0 {
			value = 0
		}
		result.healthPercent = &value
		if *used >= 100 && result.status == "healthy" {
			result.status = "warning"
			result.reason = "NVMe reported percentage-used has reached or exceeded its rated endurance"
		}
	}
	return result
}

func readStorageHealth(device string) storageHealthResult {
	physical := linuxPhysicalDevice(device)
	if physical == "" {
		return storageHealthResult{status: "unknown", source: "unavailable", reason: "No supported physical-device mapping is available for SMART health"}
	}
	now := time.Now()
	storageHealthCache.Lock()
	if cached, ok := storageHealthCache.entries[physical]; ok && now.Sub(cached.at) < 30*time.Second {
		storageHealthCache.Unlock()
		return cached.result
	}
	storageHealthCache.Unlock()

	// Fixed executable and arguments; no shell is used and the device path is
	// derived from validated Linux block-device metadata, not user input.
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()
	cmd := exec.CommandContext(ctx, "smartctl", "-a", "-j", physical)
	var stdout, stderr bytes.Buffer
	cmd.Stdout = &stdout
	cmd.Stderr = &stderr
	err := cmd.Run()
	var result storageHealthResult
	if ctx.Err() != nil {
		result = storageHealthResult{status: "unknown", source: "smartctl", reason: "SMART query timed out"}
	} else if err != nil && stdout.Len() == 0 {
		result = storageHealthResult{status: "unknown", source: "smartctl", reason: "smartctl is unavailable or the device cannot be queried; permissions may be required"}
	} else {
		result = parseSmartctlReport(stdout.Bytes())
	}
	// Cache failures too, so missing tools or insufficient permissions do not
	// cause a subprocess to run on every telemetry refresh.
	storageHealthCache.Lock()
	storageHealthCache.entries[physical] = struct {
		at     time.Time
		result storageHealthResult
	}{at: now, result: result}
	storageHealthCache.Unlock()
	return result
}
