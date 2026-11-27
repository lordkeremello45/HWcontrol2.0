//go:build linux

package main

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func writeSysfsFixture(t *testing.T, root, name, value string) {
	t.Helper()
	path := filepath.Join(root, filepath.FromSlash(name))
	if err := os.MkdirAll(filepath.Dir(path), 0755); err != nil { t.Fatal(err) }
	if err := os.WriteFile(path, []byte(value), 0644); err != nil { t.Fatal(err) }
}

func TestDiscoverLinuxHardwareDevicesBuildsGPUAndHwmonSensors(t *testing.T) {
	root := t.TempDir()
	pci := "bus/pci/devices/0000:01:00.0"
	writeSysfsFixture(t, root, pci+"/vendor", "0x10de")
	writeSysfsFixture(t, root, pci+"/device", "0x2684")
	writeSysfsFixture(t, root, pci+"/class", "0x030000")
	writeSysfsFixture(t, root, "class/hwmon/hwmon0/name", "nvidia")
	writeSysfsFixture(t, root, "class/hwmon/hwmon0/temp1_input", "52500")
	writeSysfsFixture(t, root, "class/hwmon/hwmon0/fan1_input", "1400")
	if err := os.Symlink(filepath.Join(root, pci), filepath.Join(root, "class/hwmon/hwmon0/device")); err != nil { t.Fatal(err) }

	devices := discoverLinuxHardwareDevices(root)
	if len(devices) != 1 { t.Fatalf("expected one GPU, got %d", len(devices)) }
	device := devices[0]
	if device.Identity.Vendor != "NVIDIA" || device.Identity.DeviceClass != "gpu" { t.Fatalf("unexpected identity: %+v", device.Identity) }
	if len(device.Sensors) != 2 { t.Fatalf("expected temperature and fan RPM sensors, got %d", len(device.Sensors)) }
	if err := device.Validate(); err != nil { t.Fatalf("discovered device failed validation: %v", err) }
	for _, sensor := range device.Sensors {
		if strings.Contains(sensor.Source, root) { t.Fatal("raw sysfs path leaked into sensor source") }
	}
}

func TestDiscoverLinuxHardwareDevicesKeepsPWMAsSeparateActuator(t *testing.T) {
	root := t.TempDir()
	writeSysfsFixture(t, root, "class/hwmon/hwmon1/name", "nct6798")
	writeSysfsFixture(t, root, "class/hwmon/hwmon1/fan1_input", "900")
	writeSysfsFixture(t, root, "class/hwmon/hwmon1/pwm1", "128")
	writeSysfsFixture(t, root, "class/hwmon/hwmon1/pwm1_enable", "2")
	devices := discoverLinuxHardwareDevices(root)
	if len(devices) != 1 { t.Fatalf("expected one controller, got %d", len(devices)) }
	if len(devices[0].Sensors) != 1 || devices[0].Sensors[0].Kind != "fan-speed" { t.Fatalf("fan RPM not represented as sensor: %+v", devices[0].Sensors) }
	if len(devices[0].Actuators) != 1 || devices[0].Actuators[0].Writable { t.Fatalf("PWM must remain a non-writable actuator outside manual mode: %+v", devices[0].Actuators) }
	if err := devices[0].Validate(); err != nil { t.Fatalf("discovered controller failed validation: %v", err) }
}

func TestDiscoverLinuxHardwareDevicesReturnsEmptyWithoutHardware(t *testing.T) {
	if got := discoverLinuxHardwareDevices(t.TempDir()); len(got) != 0 { t.Fatalf("expected empty discovery result, got %+v", got) }
}

func TestDiscoverLinuxHardwareDevicesDoesNotEnablePWMWithoutRPMFeedback(t *testing.T) {
	root := t.TempDir()
	writeSysfsFixture(t, root, "class/hwmon/hwmon2/name", "nct6798")
	writeSysfsFixture(t, root, "class/hwmon/hwmon2/pwm1", "128")
	writeSysfsFixture(t, root, "class/hwmon/hwmon2/pwm1_enable", "1")
	devices := discoverLinuxHardwareDevices(root)
	if len(devices) != 1 || len(devices[0].Actuators) != 1 {
		t.Fatalf("expected one monitor-only PWM actuator, got %+v", devices)
	}
	if devices[0].Actuators[0].Writable {
		t.Fatal("PWM without matching RPM feedback was marked writable")
	}
}

func TestLinuxHwmonIdentityClassifiesCPUAndMotherboardControllers(t *testing.T) {
	cases := []struct {
		name, class, vendor string
	}{
		{name: "coretemp", class: "cpu", vendor: "Intel"},
		{name: "k10temp", class: "cpu", vendor: "AMD"},
		{name: "zenpower", class: "cpu", vendor: "AMD"},
		{name: "nct6775", class: "motherboard-controller", vendor: "Unknown"},
		{name: "it8792", class: "motherboard-controller", vendor: "Unknown"},
		{name: "acpitz", class: "embedded-controller", vendor: "Unknown"},
	}
	for _, testCase := range cases {
		got := linuxHwmonIdentity(testCase.name)
		if got.DeviceClass != testCase.class || got.Vendor != testCase.vendor {
			t.Errorf("linuxHwmonIdentity(%q) = %+v; want class=%q vendor=%q", testCase.name, got, testCase.class, testCase.vendor)
		}
	}
}

func TestDiscoverLinuxHardwareDevicesDeduplicatesCapabilitiesAcrossHwmonEntries(t *testing.T) {
	root := t.TempDir()
	pci := filepath.Join(root, "bus/pci/devices/0000:01:00.0")
	writeSysfsFixture(t, root, "bus/pci/devices/0000:01:00.0/vendor", "0x10de")
	writeSysfsFixture(t, root, "bus/pci/devices/0000:01:00.0/device", "0x2684")
	writeSysfsFixture(t, root, "bus/pci/devices/0000:01:00.0/class", "0x030000")
	for index, temperature := range []string{"51000", "52000"} {
		hwmon := filepath.Join(root, "class/hwmon", "hwmon"+string(rune('0'+index)))
		if err := os.MkdirAll(hwmon, 0755); err != nil {
			t.Fatal(err)
		}
		if err := os.Symlink(pci, filepath.Join(hwmon, "device")); err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(filepath.Join(hwmon, "name"), []byte("nvidia"), 0644); err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(filepath.Join(hwmon, "temp1_input"), []byte(temperature), 0644); err != nil {
			t.Fatal(err)
		}
	}
	devices := discoverLinuxHardwareDevices(root)
	if len(devices) != 1 {
		t.Fatalf("expected both hwmon entries to merge into one GPU, got %d", len(devices))
	}
	if len(devices[0].Sensors) != 2 {
		t.Fatalf("expected both temperature sensors to be retained, got %+v", devices[0].Sensors)
	}
	if err := devices[0].Validate(); err != nil {
		t.Fatalf("merged GPU failed model validation: %v", err)
	}
	if len(devices[0].Capabilities) != 2 {
		t.Fatalf("expected one deviceDiscovery and one sensorRead capability, got %+v", devices[0].Capabilities)
	}
}

func TestDiscoverLinuxHardwareDevicesDropsRemovedHardwareOnNextScan(t *testing.T) {
	root := t.TempDir()
	pci := "bus/pci/devices/0000:01:00.0"
	hwmon := "class/hwmon/hwmon0"
	writeSysfsFixture(t, root, pci+"/vendor", "0x10de")
	writeSysfsFixture(t, root, pci+"/device", "0x2684")
	writeSysfsFixture(t, root, pci+"/class", "0x030000")
	writeSysfsFixture(t, root, hwmon+"/name", "nvidia")
	writeSysfsFixture(t, root, hwmon+"/temp1_input", "52000")
	if err := os.Symlink(filepath.Join(root, pci), filepath.Join(root, hwmon, "device")); err != nil {
		t.Fatal(err)
	}

	first := discoverLinuxHardwareDevices(root)
	if len(first) != 1 || first[0].Identity.DeviceClass != "gpu" {
		t.Fatalf("expected the initial GPU discovery, got %+v", first)
	}

	if err := os.RemoveAll(filepath.Join(root, "bus/pci/devices/0000:01:00.0")); err != nil {
		t.Fatal(err)
	}
	if err := os.RemoveAll(filepath.Join(root, hwmon)); err != nil {
		t.Fatal(err)
	}

	second := discoverLinuxHardwareDevices(root)
	if len(second) != 0 {
		t.Fatalf("removed hardware must not survive a fresh discovery scan: %+v", second)
	}
}

func TestLinuxHardwareActuatorIDMatchesFanChannelID(t *testing.T) {
	root := t.TempDir()
	hwmonRoot := filepath.Join(root, "class", "hwmon")
	hwmon := filepath.Join(hwmonRoot, "hwmon0")
	if err := os.MkdirAll(hwmon, 0755); err != nil {
		t.Fatal(err)
	}
	for name, value := range map[string]string{
		"name": "nct6775",
		"fan1_input": "1200",
		"pwm1": "128",
		"pwm1_enable": "1",
	} {
		if err := os.WriteFile(filepath.Join(hwmon, name), []byte(value+"\n"), 0644); err != nil {
			t.Fatal(err)
		}
	}

	devices := discoverLinuxHardwareDevices(root)
	if len(devices) != 1 || len(devices[0].Actuators) != 1 {
		t.Fatalf("expected one discovered hardware actuator, got %+v", devices)
	}
	channels := discoverLinuxFanTargets(hwmonRoot, nil)
	if len(channels) != 1 {
		t.Fatalf("expected one fan control channel, got %+v", channels)
	}
	if devices[0].Actuators[0].ID != channels[0].id {
		t.Fatalf("hardware actuator ID %q does not match fan channel ID %q", devices[0].Actuators[0].ID, channels[0].id)
	}
}

func TestLinuxHardwareActuatorIDsMatchMultipleFanChannelsOnSameParent(t *testing.T) {
	root := t.TempDir()
	hwmonRoot := filepath.Join(root, "class", "hwmon")
	parent := filepath.Join(root, "devices", "platform", "controller")
	if err := os.MkdirAll(filepath.Join(parent, "hwmon"), 0755); err != nil {
		t.Fatal(err)
	}
	for index, rpm := range []string{"1000", "1400"} {
		name := "hwmon" + string(rune('0'+index))
		target := filepath.Join(parent, "hwmon", name)
		if err := os.MkdirAll(target, 0755); err != nil {
			t.Fatal(err)
		}
		for file, value := range map[string]string{
			"name": "nct6775", "fan1_input": rpm, "pwm1": "128", "pwm1_enable": "1",
		} {
			if err := os.WriteFile(filepath.Join(target, file), []byte(value+"\n"), 0644); err != nil {
				t.Fatal(err)
			}
		}
		if err := os.Symlink(parent, filepath.Join(target, "device")); err != nil {
			t.Fatal(err)
		}
		if err := os.MkdirAll(hwmonRoot, 0755); err != nil {
			t.Fatal(err)
		}
		if err := os.Symlink(target, filepath.Join(hwmonRoot, name)); err != nil {
			t.Fatal(err)
		}
	}

	devices := discoverLinuxHardwareDevices(root)
	if len(devices) != 1 || len(devices[0].Actuators) != 2 {
		t.Fatalf("expected two actuators on one parent controller, got %+v", devices)
	}
	channels := discoverLinuxFanTargets(hwmonRoot, nil)
	if len(channels) != 2 {
		t.Fatalf("expected two independent fan channels, got %+v", channels)
	}
	actuatorIDs := map[string]struct{}{}
	for _, actuator := range devices[0].Actuators {
		actuatorIDs[actuator.ID] = struct{}{}
	}
	for _, channel := range channels {
		if _, ok := actuatorIDs[channel.id]; !ok {
			t.Fatalf("fan channel %q has no matching hardware actuator ID: %+v", channel.id, devices[0].Actuators)
		}
	}
}
