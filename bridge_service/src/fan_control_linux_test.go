//go:build linux

package main

import (
	"os"
	"path/filepath"
	"strconv"
	"testing"
)

func writeFanFixture(t *testing.T, root, hwmon, name string, number, enable, pwm int, rpm *int) string {
	t.Helper()
	dir := filepath.Join(root, hwmon)
	if err := os.MkdirAll(dir, 0755); err != nil {
		t.Fatalf("create hwmon fixture: %v", err)
	}
	if err := os.WriteFile(filepath.Join(dir, "name"), []byte(name+"\n"), 0644); err != nil {
		t.Fatalf("write hwmon name: %v", err)
	}
	pwmPath := filepath.Join(dir, "pwm"+itoa(number))
	if err := os.WriteFile(pwmPath, []byte(itoa(pwm)+"\n"), 0644); err != nil {
		t.Fatalf("write PWM value: %v", err)
	}
	if err := os.WriteFile(filepath.Join(dir, "pwm"+itoa(number)+"_enable"), []byte(itoa(enable)+"\n"), 0644); err != nil {
		t.Fatalf("write PWM mode: %v", err)
	}
	if rpm != nil {
		if err := os.WriteFile(filepath.Join(dir, "fan"+itoa(number)+"_input"), []byte(itoa(*rpm)+"\n"), 0644); err != nil {
			t.Fatalf("write fan RPM: %v", err)
		}
	}
	return pwmPath
}

func itoa(value int) string {
	return strconv.Itoa(value)
}

func TestLinuxFanDiscoveryEnumeratesIndependentChannels(t *testing.T) {
	root := t.TempDir()
	rpm1, rpm2 := 1450, 980
	writeFanFixture(t, root, "hwmon0", "nct6775", 1, 1, 127, &rpm1)
	writeFanFixture(t, root, "hwmon0", "nct6775", 2, 1, 200, &rpm2)

	targets := discoverLinuxFanTargets(root, nil)
	if len(targets) != 2 {
		t.Fatalf("discovery returned %d targets, want 2", len(targets))
	}
	if !targets[0].supported || !targets[1].supported {
		t.Fatalf("manual-mode channels with RPM telemetry should be supported: %+v", targets)
	}
	if targets[0].id == targets[1].id || !validFanChannelID(targets[0].id) || !validFanChannelID(targets[1].id) {
		t.Fatalf("channels must have unique opaque IDs: %+v", targets)
	}
	if targets[0].name != "nct6775" || !targets[0].rpmAvailable || targets[0].fanRPM != float64(rpm1) {
		t.Fatalf("unexpected first-channel metadata: %+v", targets[0])
	}
	if !targets[0].percentAvailable || targets[0].fanPercent < 49 || targets[0].fanPercent > 50 {
		t.Fatalf("PWM duty percentage was not decoded: %+v", targets[0])
	}
}

func TestLinuxFanDiscoveryKeepsAutomaticChannelsMonitorOnly(t *testing.T) {
	root := t.TempDir()
	rpm := 1200
	writeFanFixture(t, root, "hwmon2", "it8792", 1, 2, 190, &rpm)

	targets := discoverLinuxFanTargets(root, nil)
	if len(targets) != 1 {
		t.Fatalf("discovery returned %d targets, want 1", len(targets))
	}
	if targets[0].supported {
		t.Fatal("automatic-mode PWM must not be taken over without explicit platform validation")
	}
	if targets[0].reason == "" {
		t.Fatal("unsupported channel must explain why it is monitor-only")
	}
}

func TestLinuxFanDiscoveryReportsMissingRPMSensor(t *testing.T) {
	root := t.TempDir()
	writeFanFixture(t, root, "hwmon3", "testchip", 1, 1, 100, nil)

	targets := discoverLinuxFanTargets(root, nil)
	if len(targets) != 1 {
		t.Fatalf("discovery returned %d targets, want 1", len(targets))
	}
	if targets[0].supported {
		t.Fatal("channel without matching RPM feedback must remain monitor-only")
	}
	if targets[0].reason == "" {
		t.Fatal("missing RPM feedback must include an explanation")
	}
}

func TestLinuxFanDiscoveryHonorsExplicitChannelSelection(t *testing.T) {
	root := t.TempDir()
	rpm1, rpm2 := 1200, 1700
	first := writeFanFixture(t, root, "hwmon0", "testchip", 1, 1, 120, &rpm1)
	writeFanFixture(t, root, "hwmon1", "testchip", 1, 1, 170, &rpm2)

	targets := discoverLinuxFanTargets(root, []string{first})
	if len(targets) != 1 || targets[0].pwmPath != first {
		t.Fatalf("explicit selection returned %+v; want only %s", targets, first)
	}
}

func TestFanChannelIDIgnoresHwmonEnumerationSuffix(t *testing.T) {
	firstPath := canonicalLinuxHwmonDevicePath("/sys/devices/platform/controller/hwmon/hwmon4")
	secondPath := canonicalLinuxHwmonDevicePath("/sys/devices/platform/controller/hwmon/hwmon9")
	if firstPath != secondPath {
		t.Fatalf("canonical paths differ across hwmon enumeration: %q != %q", firstPath, secondPath)
	}
	first := stableLinuxFanChannelID(firstPath+"#testchip", 1)
	second := stableLinuxFanChannelID(secondPath+"#testchip", 1)
	if first != second {
		t.Fatal("fan profile identifier changed with the hwmon enumeration index")
	}
}

func TestStableLinuxFanChannelIDIsDeterministic(t *testing.T) {
	first := stableLinuxFanChannelID("/sys/devices/platform/test-hwmon", 2)
	second := stableLinuxFanChannelID("/sys/devices/platform/test-hwmon", 2)
	other := stableLinuxFanChannelID("/sys/devices/platform/test-hwmon", 3)
	if first != second {
		t.Fatal("same physical channel must produce the same identifier")
	}
	if first == other {
		t.Fatal("different PWM outputs must not share an identifier")
	}
	if !validFanChannelID(first) {
		t.Fatalf("generated identifier is invalid: %q", first)
	}
}
