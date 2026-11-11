package main

import (
	"bytes"
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"math"
	"os/exec"
	"strconv"
	"strings"
	"sync"
	"time"
	"unicode"
)

const (
	liquidctlStatusTimeout = 2500 * time.Millisecond
	liquidctlMaxOutput     = 256 * 1024
)

type CoolingReading struct {
	Kind  string  `json:"kind"`
	Value float64 `json:"value"`
	Unit  string  `json:"unit"`
}

type LiquidCoolingDevice struct {
	ID       string           `json:"id"`
	Name     string           `json:"name"`
	Backend  string           `json:"backend"`
	State    string           `json:"state"`
	Readings []CoolingReading `json:"readings"`
	Reason   string           `json:"reason,omitempty"`
}

type LiquidCoolingStatus struct {
	State   string                `json:"state"`
	Backend string                `json:"backend"`
	Reason  string                `json:"reason,omitempty"`
	Devices []LiquidCoolingDevice `json:"devices"`
}

type liquidctlStatusRecord struct {
	Bus         string                 `json:"bus"`
	Address     string                 `json:"address"`
	Description string                 `json:"description"`
	Status      []liquidctlStatusValue `json:"status"`
}

type liquidctlStatusValue struct {
	Key   string `json:"key"`
	Value any    `json:"value"`
	Unit  string `json:"unit"`
}

type boundedLiquidctlOutput struct {
	bytes.Buffer
	limit int
}

func (b *boundedLiquidctlOutput) Write(value []byte) (int, error) {
	if b.Len()+len(value) > b.limit {
		return 0, fmt.Errorf("liquidctl output exceeded %d bytes", b.limit)
	}
	return b.Buffer.Write(value)
}

// discoverLiquidCoolingStatus uses the optional liquidctl CLI as a read-only
// telemetry adapter. It never initializes devices and never sends set commands.
func discoverLiquidCoolingStatus() LiquidCoolingStatus {
	status := LiquidCoolingStatus{State: "unavailable", Backend: "liquidctl", Devices: []LiquidCoolingDevice{}}
	executable, err := exec.LookPath("liquidctl")
	if err != nil {
		status.Reason = "optional liquidctl executable not found"
		return status
	}

	ctx, cancel := context.WithTimeout(context.Background(), liquidctlStatusTimeout)
	defer cancel()
	command := exec.CommandContext(ctx, executable, "status", "--json")
	command.Env = stableLiquidctlEnvironment(os.Environ())

	var output boundedLiquidctlOutput
	output.limit = liquidctlMaxOutput
	command.Stdout = &output
	var diagnostics boundedLiquidctlOutput
	diagnostics.limit = 16 * 1024
	command.Stderr = &diagnostics
	if err := command.Run(); err != nil {
		if ctx.Err() != nil {
			status.Reason = "liquidctl status command timed out"
		} else {
			detail := strings.ToLower(diagnostics.String())
			if strings.Contains(detail, "permission") || strings.Contains(detail, "access denied") {
				status.Reason = "liquidctl permission denied"
			} else {
				status.Reason = "liquidctl status command failed"
			}
		}
		return status
	}

	parsed, err := parseLiquidctlStatus(output.Bytes())
	if err != nil {
		status.Reason = "liquidctl returned invalid or unsupported JSON status"
		return status
	}
	return parsed
}

func stableLiquidctlEnvironment(environment []string) []string {
	// Do not pass service credentials or application-specific configuration to
	// an optional external process. liquidctl only needs process lookup,
	// Windows system paths and a writable temporary directory.
	allowed := map[string]bool{
		"PATH": true, "SYSTEMROOT": true, "WINDIR": true,
		"TMP": true, "TEMP": true, "TMPDIR": true,
	}
	values := make(map[string]string, len(allowed))
	for _, entry := range environment {
		key, value, ok := strings.Cut(entry, "=")
		if !ok {
			continue
		}
		key = strings.ToUpper(key)
		if allowed[key] && value != "" {
			if _, exists := values[key]; !exists {
				values[key] = key + "=" + value
			}
		}
	}
	result := make([]string, 0, len(values)+2)
	for _, key := range []string{"PATH", "SYSTEMROOT", "WINDIR", "TMP", "TEMP", "TMPDIR"} {
		if value, ok := values[key]; ok {
			result = append(result, value)
		}
	}
	return append(result, "LANG=C", "LC_ALL=C")
}

func parseLiquidctlStatus(data []byte) (LiquidCoolingStatus, error) {
	status := LiquidCoolingStatus{State: "unavailable", Backend: "liquidctl", Devices: []LiquidCoolingDevice{}}
	if len(bytes.TrimSpace(data)) == 0 || len(data) > liquidctlMaxOutput {
		return status, fmt.Errorf("empty or oversized liquidctl response")
	}

	decoder := json.NewDecoder(bytes.NewReader(data))
	decoder.UseNumber()
	var records []liquidctlStatusRecord
	if err := decoder.Decode(&records); err != nil {
		return status, err
	}
	var trailing any
	if err := decoder.Decode(&trailing); err != io.EOF {
		if err == nil {
			return status, fmt.Errorf("unexpected trailing JSON value")
		}
		return status, err
	}
	if len(records) == 0 {
		status.Reason = "no supported liquid-cooling controllers detected"
		return status, nil
	}

	totalReadings := 0
	for index, record := range records {
		name := safeCoolingDeviceName(record.Description)
		if name == "" {
			name = "Liquid-cooling controller"
		}
		identity := strings.Join([]string{
			strings.TrimSpace(record.Bus),
			strings.TrimSpace(record.Address),
			name,
			strconv.Itoa(index),
		}, "\x00")
		digest := sha256.Sum256([]byte(identity))
		device := LiquidCoolingDevice{
			ID:       hex.EncodeToString(digest[:8]),
			Name:     name,
			Backend:  "liquidctl",
			State:    "partial",
			Readings: []CoolingReading{},
		}

		for _, raw := range record.Status {
			reading, ok := normalizeCoolingReading(raw)
			if !ok {
				continue
			}
			device.Readings = append(device.Readings, reading)
		}
		if len(device.Readings) > 0 {
			device.State = "available"
			totalReadings += len(device.Readings)
		} else {
			device.Reason = "controller detected, but no recognized cooling telemetry was reported"
		}
		status.Devices = append(status.Devices, device)
	}

	if totalReadings > 0 {
		status.State = "available"
	} else {
		status.State = "partial"
		status.Reason = "controllers detected, but coolant, pump, fan, flow or level telemetry was not recognized"
	}
	return status, nil
}

func safeCoolingDeviceName(value string) string {
	value = strings.TrimSpace(strings.Map(func(character rune) rune {
		if unicode.IsControl(character) {
			return -1
		}
		return character
	}, value))
	if len(value) > 160 {
		value = value[:160]
	}
	return value
}

func normalizeCoolingReading(raw liquidctlStatusValue) (CoolingReading, bool) {
	key := strings.ToLower(strings.TrimSpace(raw.Key))
	unit := strings.ToLower(strings.TrimSpace(raw.Unit))
	value, ok := coolingNumericValue(raw.Value)
	if !ok || math.IsNaN(value) || math.IsInf(value, 0) {
		return CoolingReading{}, false
	}

	switch {
	case (strings.Contains(key, "liquid temperature") || strings.Contains(key, "coolant temperature")) &&
		(unit == "°c" || unit == "c" || unit == "degc" || unit == "celsius" || unit == "°f" || unit == "f" || unit == "degf" || unit == "fahrenheit"):
		if unit == "°f" || unit == "f" || unit == "degf" || unit == "fahrenheit" {
			value = (value - 32) * 5 / 9
		}
		if value < -20 || value > 125 {
			return CoolingReading{}, false
		}
		return CoolingReading{Kind: "coolantTemperature", Value: value, Unit: "°C"}, true

	case strings.Contains(key, "pump") && (strings.Contains(key, "speed") || strings.Contains(key, "rpm")) && unit == "rpm":
		if value < 0 || value > 100000 {
			return CoolingReading{}, false
		}
		return CoolingReading{Kind: "pumpRPM", Value: value, Unit: "RPM"}, true

	case strings.Contains(key, "fan") && (strings.Contains(key, "speed") || strings.Contains(key, "rpm")) && unit == "rpm":
		if value < 0 || value > 100000 {
			return CoolingReading{}, false
		}
		return CoolingReading{Kind: "fanRPM", Value: value, Unit: "RPM"}, true

	case strings.Contains(key, "flow") && (unit == "l/min" || unit == "lpm"):
		if value < 0 || value > 1000 {
			return CoolingReading{}, false
		}
		return CoolingReading{Kind: "flowRate", Value: value, Unit: "L/min"}, true

	case (strings.Contains(key, "coolant level") || strings.Contains(key, "liquid level")) && unit == "%":
		if value < 0 || value > 100 {
			return CoolingReading{}, false
		}
		return CoolingReading{Kind: "coolantLevel", Value: value, Unit: "%"}, true
	default:
		return CoolingReading{}, false
	}
}

func coolingNumericValue(value any) (float64, bool) {
	switch typed := value.(type) {
	case float64:
		return typed, true
	case json.Number:
		parsed, err := typed.Float64()
		return parsed, err == nil
	case string:
		parsed, err := strconv.ParseFloat(strings.TrimSpace(typed), 64)
		return parsed, err == nil
	default:
		return 0, false
	}
}

func coolingHasReading(status LiquidCoolingStatus, kind string) bool {
	for _, device := range status.Devices {
		for _, reading := range device.Readings {
			if reading.Kind == kind {
				return true
			}
		}
	}
	return false
}

type liquidCoolingStatusCache struct {
	mu          sync.RWMutex
	status      LiquidCoolingStatus
	initialized bool
}

var runtimeLiquidCoolingStatusCache liquidCoolingStatusCache

func storeLiquidCoolingStatus(status LiquidCoolingStatus) {
	copyOfStatus := status
	copyOfStatus.Devices = append([]LiquidCoolingDevice(nil), status.Devices...)
	for index := range copyOfStatus.Devices {
		copyOfStatus.Devices[index].Readings = append([]CoolingReading(nil), copyOfStatus.Devices[index].Readings...)
	}
	runtimeLiquidCoolingStatusCache.mu.Lock()
	runtimeLiquidCoolingStatusCache.status = copyOfStatus
	runtimeLiquidCoolingStatusCache.initialized = true
	runtimeLiquidCoolingStatusCache.mu.Unlock()
}

func cachedLiquidCoolingStatus() LiquidCoolingStatus {
	runtimeLiquidCoolingStatusCache.mu.RLock()
	defer runtimeLiquidCoolingStatusCache.mu.RUnlock()
	if !runtimeLiquidCoolingStatusCache.initialized {
		return LiquidCoolingStatus{
			State: "unavailable", Backend: "liquidctl",
			Reason:  "liquid-cooling telemetry has not been queried yet",
			Devices: []LiquidCoolingDevice{},
		}
	}
	status := runtimeLiquidCoolingStatusCache.status
	status.Devices = append([]LiquidCoolingDevice(nil), status.Devices...)
	for index := range status.Devices {
		status.Devices[index].Readings = append([]CoolingReading(nil), status.Devices[index].Readings...)
	}
	return status
}

func addLiquidCoolingCapabilities(capabilities map[string]HardwareCapability, status LiquidCoolingStatus) {
	if capabilities == nil {
		return
	}
	capabilities["liquidCooling"] = capability(status.State == "available", status.Backend, status.Reason)
	for _, item := range []struct {
		capability string
		reading    string
		reason     string
	}{
		{capability: "coolantTemperature", reading: "coolantTemperature", reason: "No validated coolant-temperature reading is exposed"},
		{capability: "pumpRPM", reading: "pumpRPM", reason: "No validated pump-RPM reading is exposed"},
		{capability: "coolingFanRPM", reading: "fanRPM", reason: "No validated liquid-cooling fan-RPM reading is exposed"},
		{capability: "coolingFlowRate", reading: "flowRate", reason: "No validated coolant-flow reading is exposed"},
		{capability: "coolantLevel", reading: "coolantLevel", reason: "No validated coolant-level reading is exposed"},
		{capability: "leakDetection", reading: "leakDetection", reason: "No validated leak-detection sensor is exposed"},
	} {
		capabilities[item.capability] = capability(coolingHasReading(status, item.reading), status.Backend, item.reason)
	}
}
