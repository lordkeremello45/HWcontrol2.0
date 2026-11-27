package main

import (
	"math"
	"testing"
	"time"
)

func validTestHardwareDevice() HardwareDevice {
	return HardwareDevice{
		ID:       "0123456789abcdef",
		Identity: HardwareDeviceIdentity{Vendor: "NVIDIA", DeviceClass: "gpu", ProductID: "2684", Model: "Test GPU"},
		Backend:  "test-adapter",
		Capabilities: []HardwareCapabilityRef{
			{Name: "gpuTemperature", Read: true, State: "available", Backend: "test-adapter"},
		},
		Sensors: []HardwareSensor{
			{ID: "gpu-temp", Kind: "temperature", Unit: "celsius", Value: 52.5, Source: "test-adapter", ObservedAt: time.Now(), State: "available"},
		},
		Actuators: []HardwareActuator{
			{ID: "fan-0", Kind: "fan-speed", Unit: "percent", Minimum: 20, Maximum: 100, Writable: false, Backend: "test-adapter", Reason: "read-only test fixture"},
		},
	}
}

func TestHardwareDeviceModelAcceptsValidDevice(t *testing.T) {
	if err := validTestHardwareDevice().Validate(); err != nil {
		t.Fatalf("valid device rejected: %v", err)
	}
}

func TestHardwareDeviceModelRejectsUnsafeIdentifiers(t *testing.T) {
	device := validTestHardwareDevice()
	device.ID = "../../sys/class/hwmon"
	if err := device.Validate(); err == nil {
		t.Fatal("path-like device identifier was accepted")
	}

	device = validTestHardwareDevice()
	device.Sensors[0].ID = "../temp"
	if err := device.Validate(); err == nil {
		t.Fatal("path-like sensor identifier was accepted")
	}
}

func TestHardwareDeviceModelRejectsInvalidSensorValues(t *testing.T) {
	for _, value := range []float64{math.NaN(), math.Inf(1), math.Inf(-1)} {
		device := validTestHardwareDevice()
		device.Sensors[0].Value = value
		if err := device.Validate(); err == nil {
			t.Fatalf("non-finite sensor value %v was accepted", value)
		}
	}

	device := validTestHardwareDevice()
	device.Sensors[0].ObservedAt = time.Time{}
	if err := device.Validate(); err == nil {
		t.Fatal("available sensor without timestamp was accepted")
	}
}

func TestHardwareDeviceModelRejectsDuplicateComponentIDs(t *testing.T) {
	device := validTestHardwareDevice()
	device.Actuators[0].ID = device.Sensors[0].ID
	if err := device.Validate(); err == nil {
		t.Fatal("duplicate component ID was accepted")
	}
}

func TestHardwareDeviceModelRejectsUnsafeWritableActuator(t *testing.T) {
	device := validTestHardwareDevice()
	device.Actuators[0].Writable = true
	device.Actuators[0].Reason = "not validated"
	if err := device.Validate(); err == nil {
		t.Fatal("writable actuator with an unavailable reason was accepted")
	}
}

func TestHardwareDeviceModelRejectsInvalidCapabilityState(t *testing.T) {
	device := validTestHardwareDevice()
	device.Capabilities[0] = HardwareCapabilityRef{
		Name: "gpuTemperature", Read: true, State: "unsupported", Backend: "test-adapter",
	}
	if err := device.Validate(); err == nil {
		t.Fatal("unsupported capability with read permission was accepted")
	}
}

func TestHardwareDeviceModelRejectsNonFiniteValuesForEverySensorState(t *testing.T) {
	for _, state := range []string{"stale", "unavailable"} {
		for _, value := range []float64{math.NaN(), math.Inf(1), math.Inf(-1)} {
			device := validTestHardwareDevice()
			device.Sensors[0].State = state
			device.Sensors[0].Value = value
			if err := device.Validate(); err == nil {
				t.Fatalf("non-finite value %v was accepted for sensor state %q", value, state)
			}
		}
	}
}

func TestHardwareDeviceModelRejectsDuplicateCapabilitiesPerBackend(t *testing.T) {
	device := validTestHardwareDevice()
	device.Capabilities = append(device.Capabilities, device.Capabilities[0])
	if err := device.Validate(); err == nil {
		t.Fatal("duplicate capability declaration for the same backend was accepted")
	}
}

func TestHardwareDeviceModelRejectsMismatchedSensorKindAndUnit(t *testing.T) {
	cases := []struct {
		kind string
		unit string
	}{
		{kind: "temperature", unit: "rpm"},
		{kind: "utilization", unit: "bytes"},
		{kind: "memory-used", unit: "percent"},
		{kind: "clock", unit: "watts"},
		{kind: "unknown-sensor", unit: "raw"},
	}
	for _, testCase := range cases {
		device := validTestHardwareDevice()
		device.Sensors[0].Kind = testCase.kind
		device.Sensors[0].Unit = testCase.unit
		if err := device.Validate(); err == nil {
			t.Errorf("accepted invalid sensor kind/unit %q/%q", testCase.kind, testCase.unit)
		}
	}
}

func TestHardwareDeviceModelRejectsOutOfRangeSensorValues(t *testing.T) {
	cases := []struct {
		kind string
		unit string
		value float64
	}{
		{kind: "temperature", unit: "celsius", value: 126},
		{kind: "temperature", unit: "celsius", value: -21},
		{kind: "utilization", unit: "percent", value: 100.1},
		{kind: "fan-speed", unit: "rpm", value: -1},
		{kind: "power", unit: "watts", value: -0.1},
	}
	for _, testCase := range cases {
		device := validTestHardwareDevice()
		device.Sensors[0].Kind = testCase.kind
		device.Sensors[0].Unit = testCase.unit
		device.Sensors[0].Value = testCase.value
		if err := device.Validate(); err == nil {
			t.Errorf("accepted out-of-range %s value %v", testCase.kind, testCase.value)
		}
	}
}

func TestHardwareDeviceModelRejectsUsedMemoryAboveTotal(t *testing.T) {
	device := validTestHardwareDevice()
	device.Sensors = []HardwareSensor{
		{ID: "memory-used", Kind: "memory-used", Unit: "bytes", Value: 2048, Source: "test", ObservedAt: time.Now(), State: "available"},
		{ID: "memory-total", Kind: "memory-total", Unit: "bytes", Value: 1024, Source: "test", ObservedAt: time.Now(), State: "available"},
	}
	if err := device.Validate(); err == nil {
		t.Fatal("memory-used greater than memory-total was accepted")
	}
}
