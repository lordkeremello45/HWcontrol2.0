package main

import (
	"fmt"
	"math"
	"strings"
	"time"
)

// HardwareDevice is a privacy-preserving description of one physical device.
// Serial numbers, raw USB paths and filesystem paths must never enter this model.
type HardwareDevice struct {
	ID           string                 `json:"id"`
	Identity     HardwareDeviceIdentity `json:"identity"`
	Backend      string                 `json:"backend"`
	Capabilities []HardwareCapabilityRef `json:"capabilities"`
	Sensors      []HardwareSensor       `json:"sensors,omitempty"`
	Actuators    []HardwareActuator     `json:"actuators,omitempty"`
}

type HardwareDeviceIdentity struct {
	Vendor        string `json:"vendor"`
	DeviceClass   string `json:"deviceClass"`
	ProductID     string `json:"productId,omitempty"`
	Revision      string `json:"revision,omitempty"`
	Model         string `json:"model,omitempty"`
	Driver        string `json:"driver,omitempty"`
	DriverVersion string `json:"driverVersion,omitempty"`
}

type HardwareCapabilityRef struct {
	Name    string `json:"name"`
	Read    bool   `json:"read"`
	Write   bool   `json:"write"`
	State   string `json:"state"`
	Backend string `json:"backend"`
	Reason  string `json:"reason,omitempty"`
}

type HardwareSensor struct {
	ID         string    `json:"id"`
	Kind       string    `json:"kind"`
	Unit       string    `json:"unit"`
	Value      float64   `json:"value"`
	Source     string    `json:"source"`
	ObservedAt time.Time `json:"observedAt"`
	State      string    `json:"state"`
}

type HardwareActuator struct {
	ID       string  `json:"id"`
	Kind     string  `json:"kind"`
	Unit     string  `json:"unit"`
	Minimum  float64 `json:"minimum"`
	Maximum  float64 `json:"maximum"`
	Writable bool    `json:"writable"`
	Backend  string  `json:"backend"`
	Reason   string  `json:"reason,omitempty"`
}

func (d HardwareDevice) Validate() error {
	if !validFanChannelID(d.ID) {
		return fmt.Errorf("hardware device ID must be a 16-character opaque hex identifier")
	}
	if strings.TrimSpace(d.Identity.Vendor) == "" || strings.TrimSpace(d.Identity.DeviceClass) == "" {
		return fmt.Errorf("hardware vendor and device class are required")
	}
	if strings.TrimSpace(d.Backend) == "" {
		return fmt.Errorf("hardware backend is required")
	}
	seen := make(map[string]struct{}, len(d.Sensors)+len(d.Actuators))
	for _, sensor := range d.Sensors {
		if !validHardwareChildID(sensor.ID) || strings.TrimSpace(sensor.Kind) == "" ||
			strings.TrimSpace(sensor.Unit) == "" || strings.TrimSpace(sensor.Source) == "" {
			return fmt.Errorf("sensor requires a safe ID, kind, unit and source")
		}
		if _, ok := seen[sensor.ID]; ok {
			return fmt.Errorf("duplicate hardware component ID %q", sensor.ID)
		}
		seen[sensor.ID] = struct{}{}
		if sensor.State != "available" && sensor.State != "stale" && sensor.State != "unavailable" {
			return fmt.Errorf("sensor %q has invalid state %q", sensor.ID, sensor.State)
		}
		// Every state still carries a JSON number. Reject NaN and infinities
		// unconditionally because encoding/json cannot serialize them and one
		// malformed stale/unavailable sensor would fail the entire metrics response.
		if math.IsNaN(sensor.Value) || math.IsInf(sensor.Value, 0) {
			return fmt.Errorf("sensor %q requires a finite value", sensor.ID)
		}
		if sensor.State == "available" && sensor.ObservedAt.IsZero() {
			return fmt.Errorf("available sensor %q requires an observation timestamp", sensor.ID)
		}
	}
	for _, actuator := range d.Actuators {
		if !validHardwareChildID(actuator.ID) || strings.TrimSpace(actuator.Kind) == "" ||
			strings.TrimSpace(actuator.Unit) == "" || strings.TrimSpace(actuator.Backend) == "" {
			return fmt.Errorf("actuator requires a safe ID, kind, unit and backend")
		}
		if _, ok := seen[actuator.ID]; ok {
			return fmt.Errorf("duplicate hardware component ID %q", actuator.ID)
		}
		seen[actuator.ID] = struct{}{}
		if math.IsNaN(actuator.Minimum) || math.IsInf(actuator.Minimum, 0) ||
			math.IsNaN(actuator.Maximum) || math.IsInf(actuator.Maximum, 0) ||
			actuator.Minimum > actuator.Maximum {
			return fmt.Errorf("actuator %q has invalid bounds", actuator.ID)
		}
		if actuator.Writable && actuator.Reason != "" {
			return fmt.Errorf("writable actuator %q cannot have an unavailable reason", actuator.ID)
		}
		if !actuator.Writable && strings.TrimSpace(actuator.Reason) == "" {
			return fmt.Errorf("non-writable actuator %q must explain why", actuator.ID)
		}
	}
	for _, capability := range d.Capabilities {
		if strings.TrimSpace(capability.Name) == "" || strings.TrimSpace(capability.Backend) == "" {
			return fmt.Errorf("capability name and backend are required")
		}
		switch capability.State {
		case "available":
			if !capability.Read && !capability.Write {
				return fmt.Errorf("available capability %q must allow read or write", capability.Name)
			}
		case "unavailable", "permission_denied", "unsupported":
			if capability.Read || capability.Write {
				return fmt.Errorf("unavailable capability %q cannot allow operations", capability.Name)
			}
		default:
			return fmt.Errorf("capability %q has invalid state %q", capability.Name, capability.State)
		}
	}
	return nil
}

func validHardwareChildID(id string) bool {
	if len(id) == 0 || len(id) > 64 {
		return false
	}
	for _, r := range id {
		if !(r >= 'a' && r <= 'z') && !(r >= 'A' && r <= 'Z') &&
			!(r >= '0' && r <= '9') && r != '-' && r != '_' {
			return false
		}
	}
	return true
}
