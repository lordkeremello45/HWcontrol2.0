//go:build darwin

package main

import (
	"os/exec"
	"strings"
)

func macSysctl(key string) string {
	out, err := exec.Command("sysctl", "-n", key).Output()
	if err != nil { return "" }
	return strings.TrimSpace(string(out))
}

func collectHardwareIdentity() HardwareIdentity {
	id := emptyHardwareIdentity()
	id.DetectionSource = "macOS sysctl/ioreg"
	id.SystemManufacturer = "Apple"
	id.SystemModel = macSysctl("hw.model")
	id.CPUArchitecture = macSysctl("hw.machine")
	id.CPUModel = macSysctl("machdep.cpu.brand_string")
	id.CPUThreads = parsePositiveInt(macSysctl("hw.logicalcpu"))
	id.CPUPhysicalCores = parsePositiveInt(macSysctl("hw.physicalcpu"))
	id.GPUVendor = "Apple"
	if out, err := exec.Command("ioreg", "-l", "-c", "IOPlatformExpertDevice").Output(); err == nil {
		text := string(out)
		id.SystemVersion = extractIORegValue(text, "product-name")
		id.MotherboardModel = extractIORegValue(text, "board-id")
		id.BIOSVersion = extractIORegValue(text, "version")
	}
	if id.SystemModel != "" || id.CPUModel != "" { id.DetectionStatus = "ok" }
	return id
}

func parsePositiveInt(value string) int {
	n := 0
	for _, r := range value { if r < '0' || r > '9' { return 0 }; n = n*10 + int(r-'0') }
	return n
}

func extractIORegValue(text, key string) string {
	needle := key + "" = ""
	start := strings.Index(text, needle)
	if start < 0 { return "" }
	start += len(needle)
	end := strings.Index(text[start:], """)
	if end < 0 { return "" }
	return text[start:start+end]
}
