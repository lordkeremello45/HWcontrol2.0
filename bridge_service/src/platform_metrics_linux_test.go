//go:build linux

package main

import "testing"

func TestCollectIntelGPUPlatformMetricsReadsSupportedSysfsValues(t *testing.T) {
	root := t.TempDir()
	base := "class/drm/card0/device"
	writeSysfsFixture(t, root, base+"/vendor", "0x8086")
	writeSysfsFixture(t, root, base+"/gt/gt0/gt_act_freq_mhz", "1250")
	writeSysfsFixture(t, root, base+"/mem_info_vram_used", "1048576")
	writeSysfsFixture(t, root, base+"/mem_info_vram_total", "8388608")
	writeSysfsFixture(t, root, base+"/hwmon/hwmon0/temp1_input", "61000")
	writeSysfsFixture(t, root, base+"/hwmon/hwmon0/power1_average", "45000000")

	metrics := HardwareMetrics{}
	if !collectIntelGPUPlatformMetrics(root, &metrics) {
		t.Fatal("expected Intel GPU to be discovered")
	}
	if metrics.GPUVendor != "Intel" || metrics.SensorSource != "Linux Intel DRM sysfs" {
		t.Fatalf("unexpected provider identity: %+v", metrics)
	}
	if metrics.GPUCoreClockMHz != 1250 || metrics.GPUTemperature != 61 {
		t.Fatalf("unexpected frequency/temperature: %+v", metrics)
	}
	if metrics.GPUMemoryUsedBytes != 1048576 || metrics.GPUMemoryTotalBytes != 8388608 {
		t.Fatalf("unexpected memory metrics: %+v", metrics)
	}
	if metrics.PowerWatts != 45 {
		t.Fatalf("unexpected power conversion: %v", metrics.PowerWatts)
	}
}

func TestCollectIntelGPUPlatformMetricsDoesNotInventMissingDevices(t *testing.T) {
	metrics := HardwareMetrics{}
	if collectIntelGPUPlatformMetrics(t.TempDir(), &metrics) {
		t.Fatal("empty sysfs tree must not produce an Intel GPU")
	}
	if metrics.GPUVendor != "" || metrics.SensorSource != "" {
		t.Fatalf("empty sysfs tree changed metrics: %+v", metrics)
	}
}

func TestMergeLinuxPlatformMetricsPreservesZeroAndSubzeroGPUTemperatures(t *testing.T) {
	for _, temperatureMilliC := range []string{"0", "-5000"} {
		root := t.TempDir()
		base := "class/drm/card0/device"
		writeSysfsFixture(t, root, base+"/vendor", "0x8086")
		writeSysfsFixture(t, root, base+"/hwmon/hwmon0/temp1_input", temperatureMilliC)
		metrics := HardwareMetrics{}
		mergeLinuxPlatformMetrics(root, &metrics)
		want := 0.0
		if temperatureMilliC == "-5000" {
			want = -5
		}
		if metrics.GPUTemperature != want || metrics.GPUTemperatureSource == "" {
			t.Fatalf("temperature %s mC was not retained: %+v", temperatureMilliC, metrics)
		}
	}
}

func TestMergeLinuxPlatformMetricsPreservesAMDZeroTemperature(t *testing.T) {
	root := t.TempDir()
	base := "class/drm/card0/device"
	writeSysfsFixture(t, root, base+"/vendor", "0x1002")
	writeSysfsFixture(t, root, base+"/hwmon/hwmon0/temp1_input", "0")
	metrics := HardwareMetrics{}
	mergeLinuxPlatformMetrics(root, &metrics)
	if metrics.GPUVendor != "AMD" || metrics.GPUTemperature != 0 || metrics.GPUTemperatureSource == "" {
		t.Fatalf("AMD zero-degree reading was not retained: %+v", metrics)
	}
}
