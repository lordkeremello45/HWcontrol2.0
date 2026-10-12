//go:build linux

package main

import (
	"context"
	"fmt"
	"os/exec"
	"strconv"
	"strings"
	"time"
)

const (
	powerProfilesService   = "net.hadess.PowerProfiles"
	powerProfilesObject    = "/net/hadess/PowerProfiles"
	powerProfilesInterface = "net.hadess.PowerProfiles"
	activeProfileProperty  = "ActiveProfile"
)

var runPowerProfileCommand = func(ctx context.Context, args ...string) ([]byte, error) {
	return exec.CommandContext(ctx, "busctl", args...).CombinedOutput()
}

func parseBusctlString(output string) (string, error) {
	value := strings.TrimSpace(string(output))
	if !strings.HasPrefix(value, "s ") {
		return "", fmt.Errorf("unexpected busctl string property output")
	}
	decoded, err := strconv.Unquote(strings.TrimSpace(strings.TrimPrefix(value, "s ")))
	if err != nil || decoded == "" {
		return "", fmt.Errorf("invalid busctl string property output")
	}
	return decoded, nil
}

func linuxProfileName(value float64) (string, error) {
	switch value {
	case powerModeBalanced:
		return "balanced", nil
	case powerModeEfficiency:
		return "power-saver", nil
	case powerModePerformance:
		return "performance", nil
	default:
		return "", fmt.Errorf("unsupported Linux power profile value")
	}
}

func linuxProfileLabel(profile string) string {
	switch profile {
	case "power-saver":
		return "Power Saver"
	case "balanced":
		return "Balanced"
	case "performance":
		return "Performance"
	default:
		return profile
	}
}

func readLinuxPowerProfile() (string, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()
	output, err := runPowerProfileCommand(ctx, "--system", "get-property", powerProfilesService, powerProfilesObject, powerProfilesInterface, activeProfileProperty)
	if err != nil {
		detail := strings.TrimSpace(string(output))
		if detail == "" {
			detail = err.Error()
		}
		return "", fmt.Errorf("power-profiles-daemon is unavailable or denied access: %s", detail)
	}
	profile, err := parseBusctlString(output)
	if err != nil {
		return "", err
	}
	switch profile {
	case "power-saver", "balanced", "performance":
		return profile, nil
	default:
		return "", fmt.Errorf("power-profiles-daemon reported an unsupported active profile: %s", profile)
	}
}

func getPlatformPowerMode() PowerModeState {
	state := PowerModeState{
		Platform: "linux",
		AC:       "Unavailable",
		DC:       "Not separately managed by power-profiles-daemon",
	}
	profile, err := readLinuxPowerProfile()
	if err != nil {
		state.Message = err.Error()
		return state
	}
	state.Supported = true
	state.AC = linuxProfileLabel(profile)
	state.DC = "Same system profile"
	state.Message = "Linux active power profile read successfully. The system service, firmware, and thermal limits still determine effective performance."
	return state
}

func setPlatformPowerMode(supply string, value float64) (PowerModeState, error) {
	if supply != "SYSTEM" {
		return getPlatformPowerMode(), fmt.Errorf("Linux exposes one system power profile; AC/DC-specific changes are not supported")
	}
	target, err := linuxProfileName(value)
	if err != nil {
		return getPlatformPowerMode(), err
	}
	before, err := readLinuxPowerProfile()
	if err != nil {
		return getPlatformPowerMode(), err
	}
	if before == target {
		return getPlatformPowerMode(), nil
	}

	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	output, setErr := runPowerProfileCommand(ctx, "--system", "set-property", powerProfilesService, powerProfilesObject, powerProfilesInterface, activeProfileProperty, "s", target)
	cancel()
	if setErr != nil {
		detail := strings.TrimSpace(string(output))
		if detail == "" {
			detail = setErr.Error()
		}
		return getPlatformPowerMode(), fmt.Errorf("set Linux power profile failed: %s", detail)
	}

	after, readErr := readLinuxPowerProfile()
	if readErr == nil && after == target {
		state := getPlatformPowerMode()
		state.Message = "Linux power profile changed and read back successfully. This requests an OS profile; it does not guarantee maximum CPU/GPU performance."
		return state, nil
	}

	// Roll back only if the daemon still reports the value we requested.
	// Never overwrite a profile that another actor changed after our request.
	current, currentErr := readLinuxPowerProfile()
	if currentErr == nil && current == target {
		rollbackCtx, rollbackCancel := context.WithTimeout(context.Background(), 3*time.Second)
		_, _ = runPowerProfileCommand(rollbackCtx, "--system", "set-property", powerProfilesService, powerProfilesObject, powerProfilesInterface, activeProfileProperty, "s", before)
		rollbackCancel()
	}
	if readErr != nil {
		return getPlatformPowerMode(), fmt.Errorf("Linux power profile readback failed; rollback was attempted only if the active profile still matched our request: %w", readErr)
	}
	return getPlatformPowerMode(), fmt.Errorf("Linux power profile readback did not confirm requested profile %s", target)
}
