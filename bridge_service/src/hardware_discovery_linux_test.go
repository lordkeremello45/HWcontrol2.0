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
