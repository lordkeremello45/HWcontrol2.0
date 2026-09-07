//go:build !windows && !linux

package main

func mergeDriverInfo(metrics *HardwareMetrics) {
	metrics.GPUDriverStatus = "unsupported"
	metrics.GPUDriverSource = "platform stub"
}
