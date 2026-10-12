//go:build windows

package main

import (
	"fmt"
	"runtime"
	"unsafe"

	"golang.org/x/sys/windows"
)

type powerModeGUID struct {
	Data1 uint32
	Data2 uint16
	Data3 uint16
	Data4 [8]byte
}

var (
	powerEfficiencyGUID = powerModeGUID{Data1: 0x961cc777, Data2: 0x2547, Data3: 0x4f9d, Data4: [8]byte{0x81, 0x74, 0x7d, 0x86, 0x18, 0x1b, 0x8a, 0x7a}}
	powerBalancedGUID   = powerModeGUID{}
	powerPerformanceGUID = powerModeGUID{Data1: 0xded574b5, Data2: 0x45a0, Data3: 0x4f42, Data4: [8]byte{0x87, 0x37, 0x46, 0x34, 0x5c, 0x09, 0xc2, 0x38}}
	powerProfileDLL = windows.NewLazySystemDLL("powrprof.dll")
	getACPowerMode = powerProfileDLL.NewProc("PowerGetUserConfiguredACPowerMode")
	getDCPowerMode = powerProfileDLL.NewProc("PowerGetUserConfiguredDCPowerMode")
	setACPowerMode = powerProfileDLL.NewProc("PowerSetUserConfiguredACPowerMode")
	setDCPowerMode = powerProfileDLL.NewProc("PowerSetUserConfiguredDCPowerMode")
)

func powerModeGUIDForValue(value float64) (powerModeGUID, error) {
	switch value {
	case powerModeBalanced:
		return powerBalancedGUID, nil
	case powerModeEfficiency:
		return powerEfficiencyGUID, nil
	case powerModePerformance:
		return powerPerformanceGUID, nil
	default:
		return powerModeGUID{}, fmt.Errorf("unsupported power mode value")
	}
}

func powerModeNameFromGUID(value powerModeGUID) string {
	switch value {
	case powerBalancedGUID:
		return "Balanced"
	case powerEfficiencyGUID:
		return "Best Power Efficiency"
	case powerPerformanceGUID:
		return "Best Performance"
	default:
		return "Unknown"
	}
}

func powerModeAPIsAvailable() error {
	for _, proc := range []*windows.LazyProc{getACPowerMode, getDCPowerMode, setACPowerMode, setDCPowerMode} {
		if err := proc.Find(); err != nil {
			return fmt.Errorf("Windows 11 power-mode API unavailable: %w", err)
		}
	}
	return nil
}

func readWindowsPowerMode() (PowerModeState, error) {
	state := PowerModeState{Platform: runtime.GOOS, AC: "Unknown", DC: "Unknown"}
	if err := powerModeAPIsAvailable(); err != nil {
		state.Message = "Windows 11 power-mode APIs are unavailable on this system."
		return state, err
	}

	var ac, dc powerModeGUID
	result, _, _ := getACPowerMode.Call(uintptr(unsafe.Pointer(&ac)))
	if result != 0 {
		return state, fmt.Errorf("read configured AC power mode failed with Windows error %d", result)
	}
	result, _, _ = getDCPowerMode.Call(uintptr(unsafe.Pointer(&dc)))
	if result != 0 {
		return state, fmt.Errorf("read configured DC power mode failed with Windows error %d", result)
	}
	state.Supported = true
	state.AC = powerModeNameFromGUID(ac)
	state.DC = powerModeNameFromGUID(dc)
	state.Message = "Configured power modes read successfully; effective performance can still be overridden by Windows or firmware."
	return state, nil
}

func getPlatformPowerMode() PowerModeState {
	state, err := readWindowsPowerMode()
	if err != nil {
		state.Supported = false
		if state.Message == "" {
			state.Message = err.Error()
		}
	}
	return state
}

func setPlatformPowerMode(supply string, value float64) (PowerModeState, error) {
	if supply != "AC" && supply != "DC" {
		return getPlatformPowerMode(), fmt.Errorf("power supply must be AC or DC")
	}
	target, err := powerModeGUIDForValue(value)
	if err != nil {
		return getPlatformPowerMode(), err
	}
	before, err := readWindowsPowerMode()
	if err != nil || !before.Supported {
		if err == nil {
			err = fmt.Errorf("Windows power-mode control is unsupported")
		}
		return before, err
	}

	proc := setACPowerMode
	if supply == "DC" {
		proc = setDCPowerMode
	}
	result, _, _ := proc.Call(uintptr(unsafe.Pointer(&target)))
	if result != 0 {
		return getPlatformPowerMode(), fmt.Errorf("set configured %s power mode failed with Windows error %d", supply, result)
	}

	after, readErr := readWindowsPowerMode()
	if readErr == nil {
		actual := after.AC
		if supply == "DC" {
			actual = after.DC
		}
		if actual == powerModeNameFromGUID(target) {
			after.Message = supply + " configured power mode applied and read back. Windows may still override effective performance."
			return after, nil
		}
	}

	// If readback does not confirm the requested setting, attempt to restore
	// only the supply mode this call changed. Never touch the other supply mode.
	previousName := before.AC
	if supply == "DC" {
		previousName = before.DC
	}
	var previousValue float64
	switch previousName {
	case "Balanced":
		previousValue = powerModeBalanced
	case "Best Power Efficiency":
		previousValue = powerModeEfficiency
	case "Best Performance":
		previousValue = powerModePerformance
	default:
		return after, fmt.Errorf("power mode readback did not confirm the requested state; prior mode unknown, manual verification required")
	}
	previous, _ := powerModeGUIDForValue(previousValue)
	_, _, _ = proc.Call(uintptr(unsafe.Pointer(&previous)))
	if readErr != nil {
		return getPlatformPowerMode(), fmt.Errorf("power mode readback failed; attempted to restore previous %s setting: %w", supply, readErr)
	}
	return getPlatformPowerMode(), fmt.Errorf("power mode readback did not match requested %s setting; attempted to restore previous setting", supply)
}
