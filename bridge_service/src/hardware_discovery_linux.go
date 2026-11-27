//go:build linux

package main

import (
	"crypto/sha256"
	"encoding/hex"
	"os"
	"path/filepath"
	"sort"
	"strconv"
	"strings"
	"time"
)

// discoverLinuxHardwareDevices reads Linux sysfs without changing hardware state.
// root is injectable so discovery can be tested against a synthetic sysfs tree.
func discoverLinuxHardwareDevices(root string) []HardwareDevice {
	pciRoot := filepath.Join(root, "bus", "pci", "devices")
	hwmonRoot := filepath.Join(root, "class", "hwmon")
	pciEntries, _ := filepath.Glob(filepath.Join(pciRoot, "*"))
	hwmonEntries, _ := filepath.Glob(filepath.Join(hwmonRoot, "hwmon*"))
	sort.Strings(pciEntries)
	sort.Strings(hwmonEntries)

	devices := make([]HardwareDevice, 0, len(pciEntries)+len(hwmonEntries))
	byKey := make(map[string]int)
	pciPaths := make(map[string]int)
	seenFanChannelIDs := make(map[string]struct{})

	for _, entry := range pciEntries {
		vendorID := readFirstLine(filepath.Join(entry, "vendor"))
		classCode := readFirstLine(filepath.Join(entry, "class"))
		if vendorID == "" || !strings.HasPrefix(classCode, "0x03") {
			continue
		}
		productID := strings.TrimPrefix(readFirstLine(filepath.Join(entry, "device")), "0x")
		vendor := linuxHardwareVendor(vendorID)
		model := strings.TrimSpace(readFirstLine(filepath.Join(entry, "product_name")))
		if model == "" {
			model = vendor + " GPU"
		}
		device := HardwareDevice{
			ID: linuxHardwareDeviceID(entry, vendorID, productID, "gpu"),
			Identity: HardwareDeviceIdentity{Vendor: vendor, DeviceClass: "gpu", ProductID: productID, Model: model},
			Backend: "linux-sysfs",
			Capabilities: []HardwareCapabilityRef{{Name: "deviceDiscovery", Read: true, State: "available", Backend: "linux-sysfs"}},
		}
		if driver, err := filepath.EvalSymlinks(filepath.Join(entry, "driver")); err == nil {
			device.Identity.Driver = filepath.Base(driver)
		}
		resolvedPCI, resolveErr := filepath.EvalSymlinks(entry)
		if resolveErr == nil { pciPaths[filepath.Clean(resolvedPCI)] = len(devices) }
		pciPaths[filepath.Clean(entry)] = len(devices)
		byKey[device.ID] = len(devices)
		devices = append(devices, device)
	}

	for _, hwmon := range hwmonEntries {
		name := readFirstLine(filepath.Join(hwmon, "name"))
		if name == "" {
			name = "hwmon"
		}
		deviceLink := filepath.Join(hwmon, "device")
		resolvedDevice, err := filepath.EvalSymlinks(deviceLink)
		targetIndex, attached := pciPaths[filepath.Clean(resolvedDevice)]
		if err != nil || !attached {
			// Non-PCI hwmon controllers (typically motherboard/embedded
			// controllers) are represented independently and never guessed
			// to be a GPU.
			controllerKey := filepath.Clean(hwmon)
			if err == nil { controllerKey = filepath.Clean(resolvedDevice) }
			deviceID := linuxHardwareDeviceID(controllerKey, "hwmon", name, "controller")
			if index, exists := byKey[deviceID]; exists {
				targetIndex = index
			} else {
				device := HardwareDevice{
					ID: deviceID,
					Identity: linuxHwmonIdentity(name),
					Backend: "linux-hwmon",
					Capabilities: nil,
				}
				targetIndex = len(devices)
				byKey[deviceID] = targetIndex
				devices = append(devices, device)
			}
		}
		collectLinuxHwmonComponents(&devices[targetIndex], hwmon, name, seenFanChannelIDs)
	}

	validated := make([]HardwareDevice, 0, len(devices))
	seen := make(map[string]struct{}, len(devices))
	for _, device := range devices {
		if len(device.Sensors) == 0 && len(device.Actuators) == 0 && device.Identity.DeviceClass != "gpu" {
			continue
		}
		if _, exists := seen[device.ID]; exists {
			continue
		}
		if err := device.Validate(); err != nil {
			continue
		}
		seen[device.ID] = struct{}{}
		validated = append(validated, device)
	}
	return validated
}


func linuxHwmonIdentity(name string) HardwareDeviceIdentity {
	normalized := strings.ToLower(strings.TrimSpace(name))
	switch {
	case normalized == "coretemp":
		return HardwareDeviceIdentity{Vendor: "Intel", DeviceClass: "cpu", Model: "Intel CPU thermal sensor"}
	case normalized == "k10temp" || normalized == "zenpower":
		return HardwareDeviceIdentity{Vendor: "AMD", DeviceClass: "cpu", Model: "AMD CPU thermal sensor"}
	case normalized == "cpu_thermal" || normalized == "cpu-thermal":
		return HardwareDeviceIdentity{Vendor: "Unknown", DeviceClass: "cpu", Model: "CPU thermal sensor"}
	case strings.Contains(normalized, "nct") || strings.Contains(normalized, "it87") ||
		strings.Contains(normalized, "w836") || strings.Contains(normalized, "asus_ec") ||
		strings.Contains(normalized, "gigabyte_wmi") || strings.Contains(normalized, "dell_smm"):
		return HardwareDeviceIdentity{Vendor: "Unknown", DeviceClass: "motherboard-controller", Model: normalized}
	default:
		return HardwareDeviceIdentity{Vendor: "Unknown", DeviceClass: "embedded-controller", Model: normalized}
	}
}

func linuxHardwareVendor(id string) string {
	switch strings.ToLower(id) {
	case "0x10de":
		return "NVIDIA"
	case "0x1002":
		return "AMD"
	case "0x8086":
		return "Intel"
	default:
		return "PCI-" + strings.TrimPrefix(strings.ToLower(id), "0x")
	}
}

func linuxHardwareDeviceID(path, vendorID, productID, class string) string {
	sum := sha256.Sum256([]byte(strings.Join([]string{filepath.Clean(path), strings.ToLower(vendorID), strings.ToLower(productID), class}, "|")))
	return hex.EncodeToString(sum[:8])
}

func collectLinuxHwmonComponents(device *HardwareDevice, hwmon, source string, seenFanChannelIDs map[string]struct{}) {
	entries, _ := filepath.Glob(filepath.Join(hwmon, "temp*_input"))
	for _, input := range entries {
		base := strings.TrimSuffix(filepath.Base(input), "_input")
		value, ok := readFloatFile(input)
		if !ok {
			continue
		}
		value /= 1000 // Linux hwmon temperature inputs are millidegrees Celsius.
		if !isValidTemperature(value) {
			continue
		}
		label := readFirstLine(filepath.Join(hwmon, base+"_label"))
		if label == "" {
			label = base
		}
		appendUniqueHardwareSensor(device, HardwareSensor{
			ID: safeHardwareComponentID(filepath.Base(hwmon) + "-" + source + "-" + base + "-temperature"), Kind: "temperature", Unit: "celsius",
			Value: value, Source: "linux-hwmon:" + source + ":" + label, ObservedAt: time.Now().UTC(), State: "available",
		})
	}
	fanEntries, _ := filepath.Glob(filepath.Join(hwmon, "fan*_input"))
	for _, input := range fanEntries {
		base := strings.TrimSuffix(filepath.Base(input), "_input")
		value, ok := readFloatFile(input)
		if !ok || !isFiniteNonNegative(value) {
			continue
		}
		label := readFirstLine(filepath.Join(hwmon, base+"_label"))
		if label == "" {
			label = base
		}
		appendUniqueHardwareSensor(device, HardwareSensor{
			ID: safeHardwareComponentID(filepath.Base(hwmon) + "-" + source + "-" + base + "-rpm"), Kind: "fan-speed", Unit: "rpm",
			Value: value, Source: "linux-hwmon:" + source + ":" + label, ObservedAt: time.Now().UTC(), State: "available",
		})
	}
	pwmEntries, _ := filepath.Glob(filepath.Join(hwmon, "pwm[0-9]*"))
	for _, pwm := range pwmEntries {
		base := filepath.Base(pwm)
		channelNumber, validNumber := parseLinuxPWMNumber(pwm)
		if !validNumber {
			continue
		}
		number := strconv.Itoa(channelNumber)
		enable := readFirstLine(filepath.Join(hwmon, base+"_enable"))
		writable := false
		reason := "manual PWM mode is not active; discovery will not change it"
		fanInput := filepath.Join(hwmon, "fan"+number+"_input")
		if rpm, ok := readFloatFile(fanInput); !ok || !isFiniteNonNegative(rpm) {
			reason = "matching fan RPM sensor is unavailable or invalid"
		} else if enable == "1" {
			file, err := os.OpenFile(pwm, os.O_WRONLY, 0)
			if err == nil {
				writable = true
				_ = file.Close()
				reason = ""
			} else {
				reason = "PWM target is not writable by the bridge service"
			}
		} else if enable == "" {
			reason = "PWM control mode is unavailable"
		}
		channelID := linuxFanChannelID(hwmon, source, channelNumber, seenFanChannelIDs)
		appendUniqueHardwareActuator(device, HardwareActuator{
			ID: channelID, Kind: "fan-pwm", Unit: "raw-0-255",
			Minimum: 0, Maximum: 255, Writable: writable, Backend: "linux-hwmon", Reason: reason,
		})
	}
	if len(device.Sensors) > 0 {
		appendUniqueHardwareCapability(device, HardwareCapabilityRef{Name: "sensorRead", Read: true, State: "available", Backend: "linux-hwmon"})
	}
	if len(device.Actuators) > 0 {
		for _, actuator := range device.Actuators {
			if actuator.Writable {
				appendUniqueHardwareCapability(device, HardwareCapabilityRef{Name: "fanPwmWrite", Write: true, State: "available", Backend: "linux-hwmon"})
				break
			}
		}
	}
}

func appendUniqueHardwareSensor(device *HardwareDevice, sensor HardwareSensor) {
	for _, existing := range device.Sensors {
		if existing.ID == sensor.ID {
			return
		}
	}
	device.Sensors = append(device.Sensors, sensor)
}

func appendUniqueHardwareActuator(device *HardwareDevice, actuator HardwareActuator) {
	for _, existing := range device.Actuators {
		if existing.ID == actuator.ID {
			return
		}
	}
	device.Actuators = append(device.Actuators, actuator)
}

func safeHardwareComponentID(value string) string {
	var b strings.Builder
	for _, r := range strings.ToLower(value) {
		if (r >= 'a' && r <= 'z') || (r >= '0' && r <= '9') || r == '-' || r == '_' {
			b.WriteRune(r)
		} else {
			b.WriteByte('-')
		}
	}
	id := strings.Trim(b.String(), "-")
	if id == "" {
		return "component"
	}
	if len(id) > 64 {
		return id[:64]
	}
	return id
}

func discoverRuntimeHardwareDevices() []HardwareDevice {
	return discoverLinuxHardwareDevices("/sys")
}

