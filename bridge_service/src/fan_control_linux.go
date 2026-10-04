//go:build linux

package main

import (
	"fmt"
	"os"
	"path/filepath"
	"strconv"
	"strings"
)

type linuxFanTarget struct {
	pwmPath  string
	fanInput string
	name     string
}

func linuxFanTargets() []linuxFanTarget {
	configured := strings.TrimSpace(os.Getenv("HWCONTROL_HWMON_PWM"))
	if configured != "" {
		if info, err := os.Stat(configured); err == nil && !info.IsDir() {
			return []linuxFanTarget{{pwmPath: configured, fanInput: "", name: "configured"}}
		}
		return nil
	}

	entries, err := filepath.Glob("/sys/class/hwmon/hwmon*/pwm[0-9]*")
	if err != nil {
		return nil
	}
	var targets []linuxFanTarget
	for _, pwmPath := range entries {
		base := filepath.Base(pwmPath)
		if len(base) < 4 || !strings.HasPrefix(base, "pwm") {
			continue
		}
		n, err := strconv.Atoi(strings.TrimPrefix(base, "pwm"))
		if err != nil || n <= 0 {
			continue
		}
		dir := filepath.Dir(pwmPath)
		fanInput := filepath.Join(dir, fmt.Sprintf("fan%d_input", n))
		if _, err := os.Stat(fanInput); err != nil {
			continue
		}
		enablePath := filepath.Join(dir, fmt.Sprintf("pwm%d_enable", n))
		data, err := os.ReadFile(enablePath)
		if err != nil {
			continue
		}
		enable, err := strconv.Atoi(strings.TrimSpace(string(data)))
		if err != nil || (enable != 1 && enable != 2) {
			continue
		}
		probe, err := os.OpenFile(pwmPath, os.O_WRONLY, 0)
		if err != nil {
			continue
		}
		_ = probe.Close()
		name := "hwmon"
		if data, err := os.ReadFile(filepath.Join(dir, "name")); err == nil {
			if value := strings.TrimSpace(string(data)); value != "" {
				name = value
			}
		}
		targets = append(targets, linuxFanTarget{pwmPath: pwmPath, fanInput: fanInput, name: name})
	}
	return targets
}

func detectFanControl() FanControlInfo {
	targets := linuxFanTargets()
	if len(targets) != 1 {
		if len(targets) == 0 {
			return fanControlUnavailable("no unambiguous writable hwmon PWM target")
		}
		return fanControlUnavailable("multiple hwmon PWM targets; set HWCONTROL_HWMON_PWM explicitly")
	}
	return FanControlInfo{Supported: true, Backend: "linux-hwmon", Handle: targets[0].pwmPath, Reason: targets[0].name}
}

func setFanControl(percent float64) error {
	if err := validateFanPercent(percent); err != nil {
		return err
	}
	info := detectFanControl()
	if !info.Supported || info.Handle == "" {
		return fmt.Errorf("linux hwmon fan control unavailable: %s", info.Reason)
	}
	value := int(percent * 255.0 / 100.0)
	if value < 0 {
		value = 0
	}
	if value > 255 {
		value = 255
	}
	return os.WriteFile(info.Handle, []byte(strconv.Itoa(value)+"\n"), 0200)
}
