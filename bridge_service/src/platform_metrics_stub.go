//go:build !windows && !linux

package main

func mergePlatformMetrics(_ *HardwareMetrics) {}
