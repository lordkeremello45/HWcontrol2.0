//go:build linux

package main

import (
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strconv"
	"strings"
)

type linuxFanTarget struct {
	id                string
	pwmPath           string
	fanInput          string
	name              string
	supported         bool
	reason            string
	fanRPM            float64
	rpmAvailable      bool
	fanPercent        float64
	percentAvailable  bool
}

func canonicalLinuxHwmonDevicePath(devicePath string) string {
	resolved := filepath.Clean(devicePath)
	hwmonName := filepath.Base(resolved)
	if strings.HasPrefix(hwmonName, "hwmon") {
		if _, err := strconv.Atoi(strings.TrimPrefix(hwmonName, "hwmon")); err == nil &&
			filepath.Base(filepath.Dir(resolved)) == "hwmon" {
			// Drop the enumeration-dependent hwmonX suffix when a resolved
			// sysfs link contains it, so profiles survive ordinary reordering.
			return filepath.Dir(filepath.Dir(resolved))
		}
	}
	return resolved
}

func stableLinuxFanChannelID(devicePath string, pwmNumber int) string {
	sum := sha256.Sum256([]byte(filepath.Clean(devicePath) + "#pwm" + strconv.Itoa(pwmNumber)))
	return hex.EncodeToString(sum[:8])
}

func parseLinuxPWMNumber(pwmPath string) (int, bool) {
	base := filepath.Base(pwmPath)
	if !strings.HasPrefix(base, "pwm") {
		return 0, false
	}
	number, err := strconv.Atoi(strings.TrimPrefix(base, "pwm"))
	return number, err == nil && number > 0
}

func pathWithinRoot(root, path string) bool {
	relative, err := filepath.Rel(filepath.Clean(root), filepath.Clean(path))
	return err == nil && relative != "." && relative != ".." &&
		!strings.HasPrefix(relative, ".."+string(filepath.Separator)) &&
		strings.HasPrefix(filepath.ToSlash(relative), "hwmon")
}

func linuxConfiguredPWMPaths(root string) ([]string, bool, error) {
	multiple := strings.TrimSpace(os.Getenv("HWCONTROL_HWMON_PWMS"))
	single := strings.TrimSpace(os.Getenv("HWCONTROL_HWMON_PWM"))
	configured := multiple
	if configured == "" {
		configured = single
	}
	if configured == "" {
		return nil, false, nil
	}

	paths := strings.Split(configured, ",")
	unique := make(map[string]struct{}, len(paths))
	cleanPaths := make([]string, 0, len(paths))
	for _, path := range paths {
		path = filepath.Clean(strings.TrimSpace(path))
		if path == "." || !filepath.IsAbs(path) || !pathWithinRoot(root, path) {
			return nil, true, fmt.Errorf("configured PWM targets must be absolute paths inside %s", root)
		}
		if _, exists := unique[path]; exists {
			continue
		}
		unique[path] = struct{}{}
		cleanPaths = append(cleanPaths, path)
	}
	if len(cleanPaths) == 0 {
		return nil, true, fmt.Errorf("no valid PWM targets configured")
	}
	return cleanPaths, true, nil
}

// discoverLinuxFanTargets is kept independent of /sys so the discovery rules
// can be exercised with temporary filesystem fixtures in unit tests.
func discoverLinuxFanTargets(root string, configured []string) []linuxFanTarget {
	root = filepath.Clean(root)
	var entries []string
	if configured != nil {
		entries = append(entries, configured...)
	} else {
		globbed, err := filepath.Glob(filepath.Join(root, "hwmon*", "pwm[0-9]*"))
		if err != nil {
			return nil
		}
		entries = globbed
	}
	sort.Strings(entries)

	targets := make([]linuxFanTarget, 0, len(entries))
	seenPaths := make(map[string]struct{}, len(entries))
	seenIDs := make(map[string]struct{}, len(entries))
	for _, entry := range entries {
		pwmPath := filepath.Clean(entry)
		if !pathWithinRoot(root, pwmPath) {
			continue
		}
		if _, seen := seenPaths[pwmPath]; seen {
			continue
		}
		seenPaths[pwmPath] = struct{}{}

		number, ok := parseLinuxPWMNumber(pwmPath)
		if !ok {
			continue
		}
		deviceDir := filepath.Dir(pwmPath)
		idPath, err := filepath.EvalSymlinks(deviceDir)
		if err != nil {
			idPath = deviceDir
		}
		target := linuxFanTarget{
			pwmPath:  pwmPath,
			fanInput: filepath.Join(deviceDir, fmt.Sprintf("fan%d_input", number)),
			name:     "hwmon",
		}
		if data, err := os.ReadFile(filepath.Join(deviceDir, "name")); err == nil {
			if value := strings.TrimSpace(string(data)); value != "" {
				target.name = value
			}
		}
		identityPath := canonicalLinuxHwmonDevicePath(idPath) + "#" + target.name
		target.id = stableLinuxFanChannelID(identityPath, number)
		if _, exists := seenIDs[target.id]; exists {
			// Rare drivers may expose two hwmon interfaces for one parent device;
			// retain unique command identities rather than crossing the channels.
			target.id = stableLinuxFanChannelID(idPath+"#"+target.name, number)
		}
		seenIDs[target.id] = struct{}{}

		if _, err := os.Stat(target.fanInput); err != nil {
			target.reason = fmt.Sprintf("matching fan%d_input RPM sensor is unavailable", number)
		} else if data, err := os.ReadFile(filepath.Join(deviceDir, fmt.Sprintf("pwm%d_enable", number))); err != nil {
			target.reason = "PWM control mode cannot be read"
		} else if enable, err := strconv.Atoi(strings.TrimSpace(string(data))); err != nil {
			target.reason = "PWM control mode is invalid"
		} else if enable != 1 {
			target.reason = fmt.Sprintf("PWM is not in manual mode (pwm%d_enable=%d); the application will not switch modes automatically", number, enable)
		} else {
			probe, err := os.OpenFile(pwmPath, os.O_WRONLY, 0)
			if err != nil {
				target.reason = "PWM control target is not writable by the bridge service"
			} else {
				_ = probe.Close()
				target.supported = true
			}
		}

		if data, err := os.ReadFile(target.fanInput); err == nil {
			if rpm, err := strconv.ParseFloat(strings.TrimSpace(string(data)), 64); err == nil && isFiniteNonNegative(rpm) {
				target.fanRPM = rpm
				target.rpmAvailable = true
			}
		}
		if data, err := os.ReadFile(pwmPath); err == nil {
			if pwm, err := strconv.Atoi(strings.TrimSpace(string(data))); err == nil && pwm >= 0 && pwm <= 255 {
				target.fanPercent = float64(pwm) * 100.0 / 255.0
				target.percentAvailable = true
			}
		}
		targets = append(targets, target)
	}
	return targets
}

func linuxFanChannelTargets() []linuxFanTarget {
	root := "/sys/class/hwmon"
	configured, hasConfiguration, err := linuxConfiguredPWMPaths(root)
	if err != nil {
		return nil
	}
	if hasConfiguration {
		return discoverLinuxFanTargets(root, configured)
	}
	return discoverLinuxFanTargets(root, nil)
}

func linuxFanTargets() []linuxFanTarget {
	all := linuxFanChannelTargets()
	targets := make([]linuxFanTarget, 0, len(all))
	for _, target := range all {
		if target.supported {
			targets = append(targets, target)
		}
	}
	return targets
}

func listFanChannels() []FanChannel {
	targets := linuxFanChannelTargets()
	channels := make([]FanChannel, 0, len(targets))
	for _, target := range targets {
		channels = append(channels, FanChannel{
			ID:               target.id,
			Name:             fmt.Sprintf("%s PWM %s", target.name, strings.TrimPrefix(filepath.Base(target.pwmPath), "pwm")),
			Backend:          "linux-hwmon",
			Supported:        target.supported,
			FanRPM:           target.fanRPM,
			RPMAvailable:     target.rpmAvailable,
			FanPercent:       target.fanPercent,
			PercentAvailable: target.percentAvailable,
			Reason:           target.reason,
		})
	}
	return channels
}

func detectFanControl() FanControlInfo {
	targets := linuxFanTargets()
	if len(targets) == 0 {
		return fanControlUnavailable("no writable manual-mode hwmon PWM target with a matching RPM sensor")
	}
	if len(targets) != 1 {
		return fanControlUnavailable("multiple fan channels detected; use individual fan-channel control")
	}
	return FanControlInfo{Supported: true, Backend: "linux-hwmon", Handle: targets[0].pwmPath, Reason: targets[0].name}
}

func writeLinuxFanTarget(target linuxFanTarget, percent float64) error {
	value := int(percent * 255.0 / 100.0)
	if value < 0 {
		value = 0
	}
	if value > 255 {
		value = 255
	}
	if err := os.WriteFile(target.pwmPath, []byte(strconv.Itoa(value)+"\n"), 0200); err != nil {
		return fmt.Errorf("write %s: %w", filepath.Base(target.pwmPath), err)
	}
	return nil
}

func setFanControlChannel(id string, percent float64) error {
	if err := validateFanPercent(percent); err != nil {
		return err
	}
	if !validFanChannelID(id) {
		return fmt.Errorf("invalid fan-channel identifier")
	}
	for _, target := range linuxFanTargets() {
		if target.id == id {
			return writeLinuxFanTarget(target, percent)
		}
	}
	return fmt.Errorf("fan channel is not currently supported or its hardware mapping changed")
}

func setFanControl(percent float64) error {
	if err := validateFanPercent(percent); err != nil {
		return err
	}
	info := detectFanControl()
	if !info.Supported || info.Handle == "" {
		return fmt.Errorf("linux hwmon fan control unavailable: %s", info.Reason)
	}
	return os.WriteFile(info.Handle, []byte(strconv.Itoa(int(percent*255.0/100.0))+"\n"), 0200)
}
