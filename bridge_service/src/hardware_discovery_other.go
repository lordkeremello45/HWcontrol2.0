//go:build !linux

package main

// Runtime device discovery is not yet backed by a validated native collector
// on this platform. Return no fabricated devices until an adapter is added.
func discoverRuntimeHardwareDevices() []HardwareDevice { return []HardwareDevice{} }
