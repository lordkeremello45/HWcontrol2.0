//go:build darwin

package main

import (
	"os/exec"
	"strings"
)

func macSysctl(key string) string {
	out, err := exec.Command("sysctl", "-n", key).Output()
	if err != nil {
		return ""
	}
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

	if id.SystemModel != "" || id.CPUModel != "" {
		id.DetectionStatus = "ok"
	}
	return id
}

func parsePositiveInt(value string) int {
	n := 0
	for _, r := range value {
		if r < '0' || r > '9' {
			return 0
		}
		n = n*10 + int(r-'0')
	}
	return n
}

func extractIORegValue(text, key string) string {
	quote := string(rune(34))
	needle := quote + key + quote + " = "
	start := strings.Index(text, needle)
	if start < 0 {
		return ""
	}
	value := strings.TrimSpace(text[start+len(needle):])
	if strings.HasPrefix(value, "<") {
		q1 := strings.Index(value, quote)
		if q1 < 0 {
			return ""
		}
		q2 := strings.Index(value[q1+1:], quote)
		if q2 < 0 {
			return ""
		}
		return value[q1+1 : q1+1+q2]
	}
	if strings.HasPrefix(value, quote) {
		q2 := strings.Index(value[1:], quote)
		if q2 < 0 {
			return ""
		}
		return value[1 : 1+q2]
	}
	if end := strings.IndexAny(value, "\r\n"); end >= 0 {
		return strings.TrimSpace(value[:end])
	}
	return value
}
