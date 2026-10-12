//go:build !windows

package main

import (
	"fmt"
	"runtime"
)

func getPlatformPowerMode() PowerModeState {
	return PowerModeState{
		Supported: false,
		Platform:  runtime.GOOS,
		AC:        "Unavailable",
		DC:        "Unavailable",
		Message:   "Automated OS power-mode control is currently implemented only for supported Windows 11 desktop systems.",
	}
}

func setPlatformPowerMode(supply string, value float64) (PowerModeState, error) {
	return getPlatformPowerMode(), fmt.Errorf("OS power-mode control is not implemented for %s", runtime.GOOS)
}
