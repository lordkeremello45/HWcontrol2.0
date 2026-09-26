//go:build linux

package main

import "testing"

func TestParseLspciGPUModelLine(t *testing.T) {
	address, model := parseLspciGPUModelLine("0000:01:00.0 VGA compatible controller [0300]: NVIDIA Corporation Example GPU [10de:2684] (rev a1)")
	if address != "0000:01:00.0" {
		t.Fatalf("unexpected PCI address: %q", address)
	}
	if model != "NVIDIA Corporation Example GPU" {
		t.Fatalf("unexpected GPU model: %q", model)
	}
}
