package main

import (
	"bufio"
	"bytes"
	"context"
	"crypto/hmac"
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log"
	"math"
	"net"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/shirou/gopsutil/v3/cpu"
	"github.com/shirou/gopsutil/v3/disk"
	"github.com/shirou/gopsutil/v3/host"
	"github.com/shirou/gopsutil/v3/mem"
)

type Command struct {
	Action    string  `json:"action"`
	Value     float64 `json:"value"`
	Target    string  `json:"target,omitempty"`
	Timestamp int64   `json:"timestamp"`
	Nonce     string  `json:"nonce"`
	Auth      string  `json:"auth"`
}

const (
	commandClockSkew       = 30 * time.Second
	minimumCommandInterval = 100 * time.Millisecond
	maxReplayNonces        = 4096
)

func commandPayload(cmd Command) string {
	payload := cmd.Action + "\n" +
		strconv.FormatFloat(cmd.Value, 'f', 6, 64) + "\n" +
		strconv.FormatInt(cmd.Timestamp, 10) + "\n" +
		cmd.Nonce
	// Keep existing untargeted command signatures compatible while including
	// the channel identifier in the authenticated payload for targeted writes.
	if cmd.Target != "" {
		payload += "\n" + cmd.Target
	}
	return payload
}

func signCommand(cmd Command, secret string) string {
	digest := hmac.New(sha256.New, []byte(secret))
	_, _ = digest.Write([]byte(commandPayload(cmd)))
	return hex.EncodeToString(digest.Sum(nil))
}

func authenticateCommand(cmd Command, secret string) bool {
	if secret == "" || cmd.Auth == "" {
		return false
	}
	provided, err := hex.DecodeString(cmd.Auth)
	if err != nil {
		return false
	}
	digest := hmac.New(sha256.New, []byte(secret))
	_, _ = digest.Write([]byte(commandPayload(cmd)))
	return hmac.Equal(digest.Sum(nil), provided)
}

type Response struct {
	Status  string `json:"status"`
	Message string `json:"message"`
	Data    any    `json:"data,omitempty"`
}

type HardwareMetrics struct {
	GameModeEnabled            bool            `json:"gameModeEnabled"`
	GameDetected               bool            `json:"gameDetected"`
	GameProcessName            string          `json:"gameProcessName"`
	GameProcessPID             uint32          `json:"gameProcessPid"`
	GameDetectedAt             string          `json:"gameDetectedAt"`
	GameSessionDurationSeconds int64           `json:"gameSessionDurationSeconds"`
	SystemManufacturer         string          `json:"systemManufacturer"`
	SystemModel                string          `json:"systemModel"`
	SystemVersion              string          `json:"systemVersion"`
	BIOSVendor                 string          `json:"biosVendor"`
	BIOSVersion                string          `json:"biosVersion"`
	MotherboardVendor          string          `json:"motherboardVendor"`
	MotherboardModel           string          `json:"motherboardModel"`
	MotherboardVersion         string          `json:"motherboardVersion"`
	CPUManufacturer            string          `json:"cpuManufacturer"`
	CPUModel                   string          `json:"cpuModel"`
	CPUArchitecture            string          `json:"cpuArchitecture"`
	CPUPhysicalCores           int             `json:"cpuPhysicalCores"`
	CPUThreads                 int             `json:"cpuThreads"`
	GPUModel                   string          `json:"gpuModel"`
	DetectionSource            string          `json:"detectionSource"`
	DetectionStatus            string          `json:"detectionStatus"`
	SerialsExcluded            bool            `json:"serialsExcluded"`
	CPUUsage                   float64         `json:"cpuUsage"`
	CPUPerCoreUsage            []float64       `json:"cpuPerCoreUsage"`
	CPUCoreCount               int             `json:"cpuCoreCount"`
	CPUFrequencyMHz            float64         `json:"cpuFrequencyMHz"`
	CPUTemperature             float64         `json:"cpuTemperature"`
	CPUTemperatureSource       string          `json:"cpuTemperatureSource,omitempty"`
	GPUTemperature             float64         `json:"gpuTemperature"`
	GPUTemperatureSource       string          `json:"gpuTemperatureSource,omitempty"`
	MetricsCollectedAt         string          `json:"metricsCollectedAt"`
	GPUUsage                   float64         `json:"gpuUsage"`
	GPUMemoryUsage             float64         `json:"gpuMemoryUsage"`
	GPUPowerLimitWatts         float64         `json:"gpuPowerLimitWatts"`
	GPUPState                  string          `json:"gpuPState"`
	GPUEncoderUsage            float64         `json:"gpuEncoderUsage"`
	GPUDecoderUsage            float64         `json:"gpuDecoderUsage"`
	FanPercent                 float64         `json:"fanPercent"`
	FanPercentSource           string          `json:"fanPercentSource,omitempty"`
	FanRPM                     float64         `json:"fanRpm"`
	FanRPMSource               string          `json:"fanRpmSource,omitempty"`
	MemoryUsage                float64         `json:"memoryUsage"`
	MemoryTotalBytes           uint64          `json:"memoryTotalBytes"`
	DiskUsage                  float64         `json:"diskUsage"`
	DiskTotalBytes             uint64          `json:"diskTotalBytes"`
	StorageVolumes             []StorageVolume `json:"storageVolumes"`
	PowerWatts                 float64         `json:"powerWatts"`
	Voltage                    float64         `json:"voltage"`
	UptimeSeconds              uint64          `json:"uptimeSeconds"`
	Platform                   string          `json:"platform"`
	GPUVendor                  string          `json:"gpuVendor"`
	GPUName                    string          `json:"gpuName"`
	GPUDriver                  string          `json:"gpuDriver"`
	GPUDriverProvider          string          `json:"gpuDriverProvider"`
	GPUDriverVersion           string          `json:"gpuDriverVersion"`
	GPUDriverStatus            string          `json:"gpuDriverStatus"`
	GPUDriverSource            string          `json:"gpuDriverSource"`
	GPUDriverAction            string          `json:"gpuDriverAction"`
	GPUDriverReason            string          `json:"gpuDriverReason"`
	GPUMemoryUsedBytes         uint64          `json:"gpuMemoryUsedBytes"`
	GPUMemoryTotalBytes        uint64          `json:"gpuMemoryTotalBytes"`
	GPUCoreClockMHz            float64         `json:"gpuCoreClockMHz"`
	GPUMemoryClockMHz          float64         `json:"gpuMemoryClockMHz"`
	SensorSource               string          `json:"sensorSource"`
	FanControlSupported        bool            `json:"fanControlSupported"`
	FanControlBackend          string          `json:"fanControlBackend"`
	FanChannels                []FanChannel    `json:"fanChannels"`
	HardwareControlMode        string          `json:"hardwareControlMode"`
	ThermalSafetyAvailable     bool            `json:"thermalSafetyAvailable"`
	Battery                    BatteryMetrics  `json:"battery"`
}

var errRequestTooLarge = errors.New("request too large")

const (
	bridgeVersion     = "2.1.0"
	nvidiaSMITimeout  = 3 * time.Second
	defaultBridgePort = "8080"
	connectionTimeout = 30 * time.Second
	maxRequestBytes   = 64 * 1024
)

func collectMetrics() HardwareMetrics {
	metrics := HardwareMetrics{}
	if percentages, err := cpu.Percent(time.Second, true); err == nil && len(percentages) > 0 {
		var total float64
		for _, percentage := range percentages {
			total += percentage
		}
		metrics.CPUUsage = total / float64(len(percentages))
		metrics.CPUPerCoreUsage = append([]float64(nil), percentages...)
	}
	if infos, err := cpu.Info(); err == nil && len(infos) > 0 {
		metrics.CPUCoreCount = int(infos[0].Cores)
		metrics.CPUFrequencyMHz = infos[0].Mhz
	}
	if memory, err := mem.VirtualMemory(); err == nil {
		metrics.MemoryUsage = memory.UsedPercent
		metrics.MemoryTotalBytes = memory.Total
	}
	if usage, err := disk.Usage("/"); err == nil {
		metrics.DiskUsage = usage.UsedPercent
		metrics.DiskTotalBytes = usage.Total
	}
	if uptime, err := host.Uptime(); err == nil {
		metrics.UptimeSeconds = uptime
	}
	metrics.StorageVolumes = collectStorageVolumes()
	if temperatures, err := host.SensorsTemperatures(); err == nil {
		for _, sensor := range temperatures {
			key := strings.ToLower(sensor.SensorKey)
			if strings.Contains(key, "cpu") || strings.Contains(key, "package") || strings.Contains(key, "core") {
				if isValidTemperature(sensor.Temperature) && sensor.Temperature > 0 {
					metrics.CPUTemperature = sensor.Temperature
					metrics.CPUTemperatureSource = "gopsutil-host-sensors:" + sensor.SensorKey
				}
				break
			}
		}
	}
	if output, err := nvidiaSMIOutput(); err == nil {
		lines := strings.Split(strings.TrimSpace(string(output)), "\n")
		if len(lines) > 0 && strings.TrimSpace(lines[0]) != "" {
			parts := strings.Split(lines[0], ",")
			if len(parts) >= 16 {
				metrics.GPUName = strings.TrimSpace(parts[0])
				metrics.GPUDriver = strings.TrimSpace(parts[1])
				if value, parseErr := strconv.ParseFloat(strings.TrimSpace(parts[2]), 64); parseErr == nil && isValidTemperature(value) && value > 0 {
					metrics.GPUTemperature = value
					metrics.GPUTemperatureSource = "nvidia-smi"
				}
				metrics.GPUUsage, _ = strconv.ParseFloat(strings.TrimSpace(parts[3]), 64)
				metrics.GPUMemoryUsage, _ = strconv.ParseFloat(strings.TrimSpace(parts[4]), 64)
				if value, parseErr := strconv.ParseFloat(strings.TrimSpace(parts[5]), 64); parseErr == nil && isFiniteNonNegative(value) && value <= 100 {
					metrics.FanPercent = value
					metrics.FanPercentSource = "nvidia-smi"
				}
				metrics.PowerWatts, _ = strconv.ParseFloat(strings.TrimSpace(parts[6]), 64)
				metrics.GPUPowerLimitWatts, _ = strconv.ParseFloat(strings.TrimSpace(parts[7]), 64)
				metrics.Voltage, _ = strconv.ParseFloat(strings.TrimSpace(parts[8]), 64)
				memoryUsed, _ := strconv.ParseUint(strings.TrimSpace(parts[9]), 10, 64)
				memoryTotal, _ := strconv.ParseUint(strings.TrimSpace(parts[10]), 10, 64)
				metrics.GPUMemoryUsedBytes = memoryUsed * 1024 * 1024
				metrics.GPUMemoryTotalBytes = memoryTotal * 1024 * 1024
				metrics.GPUCoreClockMHz, _ = strconv.ParseFloat(strings.TrimSpace(parts[11]), 64)
				metrics.GPUMemoryClockMHz, _ = strconv.ParseFloat(strings.TrimSpace(parts[12]), 64)
				metrics.GPUPState = strings.TrimSpace(parts[13])
				metrics.GPUEncoderUsage, _ = strconv.ParseFloat(strings.TrimSpace(parts[14]), 64)
				metrics.GPUDecoderUsage, _ = strconv.ParseFloat(strings.TrimSpace(parts[15]), 64)
				metrics.GPUVendor = "NVIDIA"
				metrics.SensorSource = "nvidia-smi"
			}
		}
		if value, available := maxNvidiaGPUTemperatureFromMetricsOutput(output); available {
			metrics.GPUTemperature = value
			metrics.GPUTemperatureSource = "nvidia-smi:max-gpu-temperature"
		}
	}
	mergePlatformMetrics(&metrics)
	mergeBatteryMetrics(&metrics)
	metrics.FanChannels = listFanChannels()
	fanControl := detectFanControl()
	metrics.FanControlSupported = fanControl.Supported
	metrics.FanControlBackend = fanControl.Backend
	if fanControl.Supported || anyControllableFanChannel(metrics.FanChannels) {
		metrics.HardwareControlMode = "hardware-control"
	} else {
		metrics.HardwareControlMode = "monitor-only"
	}
	if metrics.CPUTemperatureSource == "" && metrics.CPUTemperature > 0 && isValidTemperature(metrics.CPUTemperature) && metrics.SensorSource != "" {
		metrics.CPUTemperatureSource = metrics.SensorSource
	}
	if metrics.GPUTemperatureSource == "" && metrics.GPUTemperature > 0 && isValidTemperature(metrics.GPUTemperature) && metrics.SensorSource != "" {
		metrics.GPUTemperatureSource = metrics.SensorSource
	}
	metrics.ThermalSafetyAvailable =
		(metrics.CPUTemperatureSource != "" && isValidTemperature(metrics.CPUTemperature) && metrics.CPUTemperature > 0) ||
		(metrics.GPUTemperatureSource != "" && isValidTemperature(metrics.GPUTemperature) && metrics.GPUTemperature > 0)
	game := collectGameModeState()
	metrics.GameModeEnabled = game.Enabled
	metrics.GameDetected = game.GameDetected
	metrics.GameProcessName = game.ProcessName
	metrics.GameProcessPID = game.PID
	metrics.GameDetectedAt = game.DetectedAt
	metrics.GameSessionDurationSeconds = game.SessionDurationSeconds
	identity := collectHardwareIdentity()
	metrics.SystemManufacturer = identity.SystemManufacturer
	metrics.SystemModel = identity.SystemModel
	metrics.SystemVersion = identity.SystemVersion
	metrics.BIOSVendor = identity.BIOSVendor
	metrics.BIOSVersion = identity.BIOSVersion
	metrics.MotherboardVendor = identity.MotherboardVendor
	metrics.MotherboardModel = identity.MotherboardModel
	metrics.MotherboardVersion = identity.MotherboardVersion
	metrics.CPUManufacturer = identity.CPUManufacturer
	metrics.CPUModel = identity.CPUModel
	metrics.CPUArchitecture = identity.CPUArchitecture
	metrics.CPUPhysicalCores = identity.CPUPhysicalCores
	metrics.CPUThreads = identity.CPUThreads
	metrics.GPUModel = identity.GPUModel
	metrics.DetectionSource = identity.DetectionSource
	metrics.DetectionStatus = identity.DetectionStatus
	metrics.SerialsExcluded = identity.SerialsExcluded
	mergeDriverInfo(&metrics)
	applyCompatibilityPolicy(&metrics)
	metrics.Platform = runtime.GOOS
	if metrics.SensorSource == "" {
		if metrics.CPUTemperatureSource != "" {
			metrics.SensorSource = "gopsutil-host-sensors"
		} else if metrics.GPUTemperatureSource != "" {
			metrics.SensorSource = metrics.GPUTemperatureSource
		}
	}
	metrics.MetricsCollectedAt = time.Now().UTC().Format(time.RFC3339Nano)
	recordSensorHistory(metrics)
	return metrics
}

// collectHardwareControlSafetyMetrics intentionally avoids the one-second
// CPU-utilization sampling used by collectMetrics. A multi-channel write must
// revalidate thermal safety on every command without multiplying that delay by
// the number of fans.
func maxNvidiaGPUTemperatureFromMetricsOutput(output []byte) (float64, bool) {
	var highest float64
	found := false
	for _, line := range strings.Split(string(output), "\n") {
		parts := strings.Split(line, ",")
		if len(parts) < 3 {
			continue
		}
		value, err := strconv.ParseFloat(strings.TrimSpace(parts[2]), 64)
		if err != nil || !isValidTemperature(value) || value <= 0 {
			continue
		}
		if !found || value > highest {
			highest = value
			found = true
		}
	}
	return highest, found
}

const nvidiaSafetyTemperatureTimeout = 1200 * time.Millisecond

func nvidiaSMITemperatureOutput() ([]byte, error) {
	ctx, cancel := context.WithTimeout(context.Background(), nvidiaSafetyTemperatureTimeout)
	defer cancel()
	return exec.CommandContext(ctx, "nvidia-smi", "--query-gpu=temperature.gpu", "--format=csv,noheader,nounits").Output()
}

func maxNvidiaGPUTemperature(output []byte) (float64, bool) {
	var highest float64
	found := false
	for _, line := range strings.Split(string(output), "\n") {
		value, err := strconv.ParseFloat(strings.TrimSpace(line), 64)
		if err != nil || !isValidTemperature(value) || value <= 0 {
			continue
		}
		if !found || value > highest {
			highest = value
			found = true
		}
	}
	return highest, found
}

func collectHardwareControlSafetyMetrics() HardwareMetrics {
	metrics := HardwareMetrics{}
	if temperatures, err := host.SensorsTemperatures(); err == nil {
		for _, sensor := range temperatures {
			key := strings.ToLower(sensor.SensorKey)
			if strings.Contains(key, "cpu") || strings.Contains(key, "package") || strings.Contains(key, "core") {
				if isValidTemperature(sensor.Temperature) && sensor.Temperature > 0 {
					metrics.CPUTemperature = sensor.Temperature
					metrics.CPUTemperatureSource = "gopsutil-host-sensors:" + sensor.SensorKey
				}
			}
			if strings.Contains(key, "gpu") || strings.Contains(key, "graphics") {
				if isValidTemperature(sensor.Temperature) && sensor.Temperature > 0 {
					metrics.GPUTemperature = sensor.Temperature
					metrics.GPUTemperatureSource = "gopsutil-host-sensors:" + sensor.SensorKey
				}
			}
		}
	}

	if output, err := nvidiaSMITemperatureOutput(); err == nil {
		if value, available := maxNvidiaGPUTemperature(output); available {
			metrics.GPUTemperature = value
			metrics.GPUTemperatureSource = "nvidia-smi:max-gpu-temperature"
			metrics.SensorSource = "nvidia-smi"
		}
	}

	mergePlatformMetrics(&metrics)
	if metrics.CPUTemperatureSource == "" && metrics.CPUTemperature > 0 && isValidTemperature(metrics.CPUTemperature) && metrics.SensorSource != "" {
		metrics.CPUTemperatureSource = metrics.SensorSource
	}
	if metrics.GPUTemperatureSource == "" && metrics.GPUTemperature > 0 && isValidTemperature(metrics.GPUTemperature) && metrics.SensorSource != "" {
		metrics.GPUTemperatureSource = metrics.SensorSource
	}
	if metrics.SensorSource == "" {
		if metrics.CPUTemperatureSource != "" {
			metrics.SensorSource = "gopsutil-host-sensors"
		} else if metrics.GPUTemperatureSource != "" {
			metrics.SensorSource = metrics.GPUTemperatureSource
		}
	}
	metrics.ThermalSafetyAvailable =
		(metrics.CPUTemperatureSource != "" && isValidTemperature(metrics.CPUTemperature) && metrics.CPUTemperature > 0) ||
			(metrics.GPUTemperatureSource != "" && isValidTemperature(metrics.GPUTemperature) && metrics.GPUTemperature > 0)
	metrics.FanChannels = listFanChannels()
	fanControl := detectFanControl()
	metrics.FanControlSupported = fanControl.Supported
	metrics.FanControlBackend = fanControl.Backend
	return metrics
}

func nvidiaSMIOutput() ([]byte, error) {
	ctx, cancel := context.WithTimeout(context.Background(), nvidiaSMITimeout)
	defer cancel()
	return exec.CommandContext(ctx, "nvidia-smi", "--query-gpu=name,driver_version,temperature.gpu,utilization.gpu,utilization.memory,fan.speed,power.draw,power.limit,voltage.gpu,memory.used,memory.total,clocks.gr,clocks.mem,pstate,utilization.encoder,utilization.decoder", "--format=csv,noheader,nounits").Output()
}

func modelDigest() string {
	modelPath := strings.TrimSpace(os.Getenv("HWCONTROL_MODEL"))
	if modelPath == "" {
		return "managed-by-gui"
	}
	file, err := os.Open(modelPath)
	if err != nil {
		return "unavailable"
	}
	defer file.Close()
	hasher := sha256.New()
	if _, err := io.Copy(hasher, file); err != nil {
		return "unavailable"
	}
	return hex.EncodeToString(hasher.Sum(nil))
}

const maxActionLength = 64

func validateCommand(cmd Command) error {
	action := strings.TrimSpace(cmd.Action)
	if action == "" {
		return fmt.Errorf("action is required")
	}
	if action != cmd.Action {
		return fmt.Errorf("action must not contain leading or trailing whitespace")
	}
	if len(action) > maxActionLength {
		return fmt.Errorf("action is too long")
	}
	if math.IsNaN(cmd.Value) || math.IsInf(cmd.Value, 0) || cmd.Value < 0 || cmd.Value > 100 {
		return fmt.Errorf("value must be between 0 and 100")
	}
	// HMAC canonicalization follows the Flutter protocol's six-decimal
	// representation. Reject values that round differently so sub-micro
	// changes cannot retain the same authentication tag.
	canonicalValue, err := strconv.ParseFloat(strconv.FormatFloat(cmd.Value, 'f', 6, 64), 64)
	if err != nil || canonicalValue != cmd.Value {
		return fmt.Errorf("value precision exceeds authenticated protocol precision")
	}
	if cmd.Timestamp <= 0 {
		return fmt.Errorf("timestamp is required")
	}
	age := time.Since(time.UnixMilli(cmd.Timestamp))
	if age > commandClockSkew || age < -commandClockSkew {
		return fmt.Errorf("command timestamp outside allowed window")
	}
	if len(cmd.Nonce) != 32 {
		return fmt.Errorf("nonce must contain 32 hexadecimal characters")
	}
	if _, err := hex.DecodeString(cmd.Nonce); err != nil {
		return fmt.Errorf("nonce must be hexadecimal")
	}
	if len(cmd.Auth) != sha256.Size*2 {
		return fmt.Errorf("auth must contain 64 hexadecimal characters")
	}
	if _, err := hex.DecodeString(cmd.Auth); err != nil {
		return fmt.Errorf("auth must be hexadecimal")
	}
	if len(cmd.Target) > 8192 {
		return fmt.Errorf("command target is too large")
	}
	if action == "Set Fan Channel" {
		if !validFanChannelID(cmd.Target) {
			return fmt.Errorf("Set Fan Channel requires a valid channel identifier")
		}
		if err := validateFanPercent(cmd.Value); err != nil {
			return err
		}
	} else if action == "Start Audio Studio" {
		if cmd.Value != 0 { return fmt.Errorf("audio start command value must be zero") }
		if _, err := decodeAudioStudioStartTarget(cmd.Target); err != nil { return err }
	} else if cmd.Target != "" {
		return fmt.Errorf("target is only accepted for fan-channel or audio-start commands")
	}
	switch action {
	case "Fan Hızı", "AI İşlem Gücü", "Set Game Mode", "Start Audio Studio":
		return nil
	case "Set Fan Channel":
		return validateFanPercent(cmd.Value)
	case "Set Power Mode AC", "Set Power Mode DC":
		return validatePowerModeRequest(action, cmd.Value)
	case "Set Power Profile":
		return validatePowerModeRequest("Set Power Mode AC", cmd.Value)
	case "Get Power Mode":
		if cmd.Value != 0 {
			return fmt.Errorf("read-only command value must be zero")
		}
		return nil
	case "Get Status", "Get Security", "Get Diagnostics", "Get Health", "Get Game Mode", "Get Update", "Get Sensor Health", "Get Sensor History", "Get Fan Channels", "Get Fetch Status", "Get Audio Devices", "Get Audio Studio Status", "Stop Audio Studio":
		if cmd.Value != 0 {
			return fmt.Errorf("read-only command value must be zero")
		}
		return nil
	default:
		return fmt.Errorf("unsupported action: %s", cmd.Action)
	}
}

const (
	criticalCPUTemperature = 95.0
	criticalGPUTemperature = 95.0
)

func validateThermalTelemetry(metrics HardwareMetrics) error {
	if !metrics.ThermalSafetyAvailable {
		return fmt.Errorf("hardware control blocked: no valid thermal telemetry available")
	}
	if metrics.CPUTemperature != 0 && !isValidTemperature(metrics.CPUTemperature) {
		return fmt.Errorf("hardware control blocked: CPU temperature telemetry is invalid")
	}
	if metrics.GPUTemperature != 0 && !isValidTemperature(metrics.GPUTemperature) {
		return fmt.Errorf("hardware control blocked: GPU temperature telemetry is invalid")
	}
	return nil
}

func hasCriticalThermalState(metrics HardwareMetrics) bool {
	return metrics.CPUTemperature >= criticalCPUTemperature ||
		metrics.GPUTemperature >= criticalGPUTemperature
}

func hardwareControlSafetyError(metrics HardwareMetrics) error {
	if err := validateThermalTelemetry(metrics); err != nil {
		return err
	}
	if hasCriticalThermalState(metrics) {
		return fmt.Errorf("hardware control blocked: critical temperature detected")
	}
	return nil
}

func validateFanControlRequest(cmd Command, metrics HardwareMetrics) error {
	if cmd.Action != "Fan Hızı" {
		return nil
	}
	if err := validateThermalTelemetry(metrics); err != nil {
		return err
	}
	if !metrics.FanControlSupported || metrics.FanControlBackend == "" || metrics.FanControlBackend == "monitor-only" {
		return fmt.Errorf("hardware fan control is unavailable")
	}
	if hasCriticalThermalState(metrics) && cmd.Value < 100 {
		return errors.New("critical temperature detected; only the 100% emergency cooling target is allowed")
	}
	return nil
}

func validateFanChannelControlRequest(cmd Command, metrics HardwareMetrics) error {
	if cmd.Action != "Set Fan Channel" {
		return nil
	}
	if !validFanChannelID(cmd.Target) {
		return fmt.Errorf("invalid fan-channel identifier")
	}
	if err := validateFanPercent(cmd.Value); err != nil {
		return err
	}
	if err := validateThermalTelemetry(metrics); err != nil {
		return err
	}

	found := false
	for _, channel := range metrics.FanChannels {
		if channel.ID != cmd.Target {
			continue
		}
		found = true
		if !channel.Supported || channel.Backend == "" || channel.Backend == "monitor-only" {
			return fmt.Errorf("fan channel is monitor-only: %s", channel.Reason)
		}
		break
	}
	if !found {
		return fmt.Errorf("fan channel was not detected; refresh hardware capabilities and try again")
	}
	if hasCriticalThermalState(metrics) && cmd.Value < 100 {
		return errors.New("critical temperature detected; only the 100% emergency cooling target is allowed")
	}
	return nil
}

func executeHardwareCommand(cmd Command) error {
	switch cmd.Action {
	case "Fan Hızı":
		if panicModeActive() {
			return fmt.Errorf("hardware control blocked: security panic mode active")
		}
		metrics := collectHardwareControlSafetyMetrics()
		if err := validateFanControlRequest(cmd, metrics); err != nil {
			return err
		}
		if err := setFanControl(cmd.Value); err != nil {
			return err
		}
		return nil
	case "Set Fan Channel":
		if panicModeActive() {
			return fmt.Errorf("hardware control blocked: security panic mode active")
		}
		channelPresent := false
		for _, channel := range listFanChannels() {
			if channel.ID == cmd.Target && channel.Supported {
				channelPresent = true
				break
			}
		}
		if !channelPresent {
			return fmt.Errorf("fan channel was not detected or is monitor-only")
		}
		metrics := collectHardwareControlSafetyMetrics()
		if err := validateFanChannelControlRequest(cmd, metrics); err != nil {
			return err
		}
		return setFanControlChannel(cmd.Target, cmd.Value)
	case "AI İşlem Gücü":
		if panicModeActive() {
			return fmt.Errorf("hardware control blocked: security panic mode active")
		}
		return fmt.Errorf("hardware control backend is not available on this build")
	case "Set Game Mode":
		if panicModeActive() {
			return fmt.Errorf("hardware control blocked: security panic mode active")
		}
		setGameModeEnabled(cmd.Value >= 50)
		return nil
	case "Set Power Mode AC", "Set Power Mode DC":
		if panicModeActive() {
			return fmt.Errorf("hardware control blocked: security panic mode active")
		}
		if err := validatePowerModeRequest(cmd.Action, cmd.Value); err != nil {
			return err
		}
		supply := "AC"
		if cmd.Action == "Set Power Mode DC" {
			supply = "DC"
		}
		_, err := setPlatformPowerMode(supply, cmd.Value)
		return err

	case "Set Power Profile":
		if panicModeActive() {
			return fmt.Errorf("hardware control blocked: security panic mode active")
		}
		if err := validatePowerModeRequest("Set Power Mode AC", cmd.Value); err != nil {
			return err
		}
		_, err := setPlatformPowerMode("SYSTEM", cmd.Value)
		return err
	default:
		return fmt.Errorf("action cannot be executed: %s", cmd.Action)
	}
}

func defaultKeyFile() string {
	if configured := strings.TrimSpace(os.Getenv("HWCONTROL_KEY_FILE")); configured != "" {
		return configured
	}
	switch runtime.GOOS {
	case "windows":
		root := os.Getenv("ProgramData")
		if root == "" {
			root = `C:\ProgramData`
		}
		return filepath.Join(root, "HWControl", "bridge.key")
	case "darwin":
		return filepath.Join("/Library", "Application Support", "HWControl", "bridge.key")
	default:
		return "/var/lib/hwcontrol/bridge.key"
	}
}

func validBridgeSecret(secret string) bool {
	if len(secret) != 64 {
		return false
	}
	_, err := hex.DecodeString(secret)
	return err == nil
}

func validateKeyFilePath(path string) error {
	if !filepath.IsAbs(path) {
		return fmt.Errorf("bridge key file path must be absolute")
	}
	info, err := os.Lstat(path)
	if os.IsNotExist(err) {
		return nil
	}
	if err != nil {
		return fmt.Errorf("inspect bridge key file: %w", err)
	}
	if info.Mode()&os.ModeSymlink != 0 {
		return fmt.Errorf("bridge key file must not be a symlink")
	}
	if runtime.GOOS != "windows" && info.Mode().Perm()&0022 != 0 {
		return fmt.Errorf("bridge key file is writable by group/others")
	}
	return nil
}

func loadOrCreateSecret() (string, error) {
	if secret := strings.TrimSpace(os.Getenv("HWCONTROL_KEY")); secret != "" && secret != "replace-me" {
		if !validBridgeSecret(secret) {
			return "", fmt.Errorf("HWCONTROL_KEY must contain exactly 64 hexadecimal characters")
		}
		return secret, nil
	}
	path := defaultKeyFile()
	if err := validateKeyFilePath(path); err != nil {
		return "", err
	}
	if data, err := os.ReadFile(path); err == nil {
		secret := strings.TrimSpace(string(data))
		if !validBridgeSecret(secret) {
			return "", fmt.Errorf("bridge key file contains an invalid secret")
		}
		return secret, nil
	} else if !os.IsNotExist(err) {
		return "", fmt.Errorf("read bridge key file: %w", err)
	}
	key := make([]byte, 32)
	if _, err := rand.Read(key); err != nil {
		return "", fmt.Errorf("generate bridge key: %w", err)
	}
	secret := hex.EncodeToString(key)
	if err := os.MkdirAll(filepath.Dir(path), 0750); err != nil {
		return "", fmt.Errorf("create key directory: %w", err)
	}

	// Create the key with O_EXCL so an attacker cannot pre-place a symlink at a
	// predictable temporary path and redirect the secret elsewhere.
	file, err := os.OpenFile(path, os.O_WRONLY|os.O_CREATE|os.O_EXCL, 0600)
	if err != nil {
		if os.IsExist(err) {
			data, readErr := os.ReadFile(path)
			if readErr != nil {
				return "", fmt.Errorf("read concurrently-created bridge key: %w", readErr)
			}
			loaded := strings.TrimSpace(string(data))
			if !validBridgeSecret(loaded) {
				return "", fmt.Errorf("bridge key file contains an invalid secret")
			}
			return loaded, nil
		}
		return "", fmt.Errorf("create bridge key: %w", err)
	}
	if _, err := file.WriteString(secret + "\n"); err != nil {
		_ = file.Close()
		_ = os.Remove(path)
		return "", fmt.Errorf("write bridge key: %w", err)
	}
	if err := file.Close(); err != nil {
		_ = os.Remove(path)
		return "", fmt.Errorf("close bridge key: %w", err)
	}
	if err := os.Chmod(path, 0600); err != nil && runtime.GOOS != "windows" {
		_ = os.Remove(path)
		return "", fmt.Errorf("protect bridge key: %w", err)
	}
	return secret, nil
}


type audioProbeDevice struct {
	Index     int    `json:"index"`
	NameHex   string `json:"nameHex"`
	IsDefault bool   `json:"isDefault"`
}

type audioProbeOutput struct {
	Capture  []audioProbeDevice `json:"capture"`
	Playback []audioProbeDevice `json:"playback"`
}

func decodeAudioDeviceProbeOutput(raw []byte) (map[string]any, error) {
	var output audioProbeOutput
	if err := json.Unmarshal(raw, &output); err != nil {
		return nil, fmt.Errorf("decode native audio device response: %w", err)
	}
	convert := func(devices []audioProbeDevice) ([]map[string]any, error) {
		result := make([]map[string]any, 0, len(devices))
		for _, device := range devices {
			if device.Index < 0 || len(device.NameHex) > 2048 {
				return nil, fmt.Errorf("native audio device response contains invalid fields")
			}
			nameBytes, err := hex.DecodeString(device.NameHex)
			if err != nil || len(nameBytes) == 0 {
				return nil, fmt.Errorf("native audio device response contains invalid device name")
			}
			name := strings.ToValidUTF8(string(nameBytes), "\\uFFFD")
			if strings.TrimSpace(name) == "" || strings.ContainsRune(name, 0) {
				return nil, fmt.Errorf("native audio device response contains an empty device name")
			}
			result = append(result, map[string]any{
				"index": device.Index, "name": name, "isDefault": device.IsDefault,
			})
		}
		return result, nil
	}
	capture, err := convert(output.Capture)
	if err != nil { return nil, err }
	playback, err := convert(output.Playback)
	if err != nil { return nil, err }
	return map[string]any{"capture": capture, "playback": playback, "localOnly": true}, nil
}

func resolveAudioProbePath() (string, error) {
	if configured := strings.TrimSpace(os.Getenv("HWCONTROL_AUDIO_PROBE")); configured != "" {
		if !filepath.IsAbs(configured) {
			return "", fmt.Errorf("HWCONTROL_AUDIO_PROBE must be an absolute path")
		}
		info, err := os.Stat(configured)
		if err != nil { return "", fmt.Errorf("inspect configured audio probe: %w", err) }
		if !info.Mode().IsRegular() { return "", fmt.Errorf("configured audio probe is not a regular file") }
		return configured, nil
	}
	executable, err := os.Executable()
	if err != nil { return "", fmt.Errorf("resolve bridge executable: %w", err) }
	name := "hwcontrol_audio_probe"
	if runtime.GOOS == "windows" { name += ".exe" }
	dir := filepath.Dir(executable)
	for _, candidate := range []string{
		filepath.Join(dir, name),
		filepath.Join(dir, "native", name),
		filepath.Join(dir, "bin", name),
		filepath.Join(dir, "..", "build", "audio_core", name),
		filepath.Join(dir, "..", "build-windows", "audio_core", "Release", name),
		filepath.Join(dir, "..", "build-windows", "audio_core", name),
	} {
		info, statErr := os.Stat(candidate)
		if statErr == nil && info.Mode().IsRegular() { return candidate, nil }
	}
	return "", fmt.Errorf("native audio probe is not packaged; build hwcontrol_audio_probe and place it beside the bridge or set HWCONTROL_AUDIO_PROBE")
}

func audioDeviceSnapshot() (map[string]any, error) {
	probe, err := resolveAudioProbePath()
	if err != nil { return nil, err }
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	command := exec.CommandContext(ctx, probe, "--json")
	output, err := command.Output()
	if ctx.Err() != nil { return nil, fmt.Errorf("native audio device enumeration timed out") }
	if err != nil { return nil, fmt.Errorf("native audio device enumeration failed: %w", err) }
	return decodeAudioDeviceProbeOutput(output)
}


type audioStudioStartRequest struct {
	CaptureIndex int `json:"captureIndex"`
	PlaybackIndex int `json:"playbackIndex"`
	MonitorOutput bool `json:"monitorOutput"`
	InputGain float64 `json:"inputGain"`
	GateThreshold float64 `json:"gateThreshold"`
	CompressorThreshold float64 `json:"compressorThreshold"`
	CompressorRatio float64 `json:"compressorRatio"`
	CompressorAttack float64 `json:"compressorAttack"`
	CompressorRelease float64 `json:"compressorRelease"`
	CompressorKnee float64 `json:"compressorKnee"`
	HighPassFrequency float64 `json:"highPassFrequency"`
	LimiterCeiling float64 `json:"limiterCeiling"`
	GateEnabled bool `json:"gateEnabled"`
	CompressorEnabled bool `json:"compressorEnabled"`
	HighPassEnabled bool `json:"highPassEnabled"`
	LimiterEnabled bool `json:"limiterEnabled"`
	EQGain []float64 `json:"eqGain"`
	EQFrequency []float64 `json:"eqFrequency"`
}

var audioProbeSessionMu sync.Mutex
var audioProbeSessionCmd *exec.Cmd
var audioProbeSessionInput io.WriteCloser
var audioProbeSessionOutput *bufio.Reader

func validAudioStudioStartRequest(request audioStudioStartRequest) error {
	if request.CaptureIndex < 0 || request.CaptureIndex > 1024 || request.PlaybackIndex < 0 || request.PlaybackIndex > 1024 {
		return fmt.Errorf("audio device index is outside the allowed range")
	}
	ranges := []struct { name string; value, min, max float64 }{
		{"input gain", request.InputGain, -24, 12},
		{"gate threshold", request.GateThreshold, -90, 0},
		{"compressor threshold", request.CompressorThreshold, -60, 0},
		{"compressor ratio", request.CompressorRatio, 1, 20},
		{"compressor attack", request.CompressorAttack, 0.1, 200},
		{"compressor release", request.CompressorRelease, 1, 2000},
		{"compressor knee", request.CompressorKnee, 0, 24},
		{"high-pass frequency", request.HighPassFrequency, 20, 1000},
		{"limiter ceiling", request.LimiterCeiling, -24, 0},
	}
	for _, item := range ranges {
		if math.IsNaN(item.value) || math.IsInf(item.value, 0) || item.value < item.min || item.value > item.max {
			return fmt.Errorf("invalid audio %s", item.name)
		}
	}
	if len(request.EQGain) != 3 || len(request.EQFrequency) != 3 {
		return fmt.Errorf("audio EQ must contain exactly three bands")
	}
	for i := 0; i < 3; i++ {
		if math.IsNaN(request.EQGain[i]) || math.IsInf(request.EQGain[i], 0) || request.EQGain[i] < -12 || request.EQGain[i] > 12 {
			return fmt.Errorf("invalid audio EQ gain")
		}
		if math.IsNaN(request.EQFrequency[i]) || math.IsInf(request.EQFrequency[i], 0) || request.EQFrequency[i] < 20 || request.EQFrequency[i] > 18000 {
			return fmt.Errorf("invalid audio EQ frequency")
		}
	}
	return nil
}

func decodeAudioStudioStartTarget(target string) (audioStudioStartRequest, error) {
	var request audioStudioStartRequest
	if target == "" || len(target) > 8192 {
		return request, fmt.Errorf("audio start configuration is missing or too large")
	}
	raw, err := base64.RawURLEncoding.DecodeString(target)
	if err != nil { return request, fmt.Errorf("invalid audio start configuration encoding") }
	if err := json.Unmarshal(raw, &request); err != nil { return request, fmt.Errorf("invalid audio start configuration") }
	if err := validAudioStudioStartRequest(request); err != nil { return request, err }
	return request, nil
}

func audioStudioStartLine(request audioStudioStartRequest) string {
	boolNumber := func(value bool) int { if value { return 1 }; return 0 }
	values := []float64{
		request.InputGain, request.GateThreshold, request.CompressorThreshold,
		request.CompressorRatio, request.CompressorAttack, request.CompressorRelease,
		request.CompressorKnee, request.HighPassFrequency, request.LimiterCeiling,
	}
	for i := 0; i < 3; i++ { values = append(values, request.EQFrequency[i], request.EQGain[i]) }
	parts := []string{
		"start", strconv.Itoa(request.CaptureIndex), strconv.Itoa(request.PlaybackIndex),
		strconv.Itoa(boolNumber(request.MonitorOutput)),
	}
	for _, value := range values[:9] { parts = append(parts, strconv.FormatFloat(value, 'f', -1, 64)) }
	parts = append(parts,
		strconv.Itoa(boolNumber(request.GateEnabled)),
		strconv.Itoa(boolNumber(request.CompressorEnabled)),
		strconv.Itoa(boolNumber(request.HighPassEnabled)),
		strconv.Itoa(boolNumber(request.LimiterEnabled)))
	for _, value := range values[9:] { parts = append(parts, strconv.FormatFloat(value, 'f', -1, 64)) }
	return strings.Join(parts, " ")
}

func stopAudioProbeSessionLocked() {
	if audioProbeSessionInput != nil { _ = audioProbeSessionInput.Close() }
	if audioProbeSessionCmd != nil && audioProbeSessionCmd.Process != nil {
		_ = audioProbeSessionCmd.Process.Kill()
		_ = audioProbeSessionCmd.Wait()
	}
	audioProbeSessionCmd = nil
	audioProbeSessionInput = nil
	audioProbeSessionOutput = nil
}

func audioProbeControl(command string) (map[string]any, error) {
	audioProbeSessionMu.Lock()
	defer audioProbeSessionMu.Unlock()
	if audioProbeSessionCmd == nil {
		probe, err := resolveAudioProbePath()
		if err != nil { return nil, err }
		cmd := exec.Command(probe, "--server")
		stdin, err := cmd.StdinPipe()
		if err != nil { return nil, fmt.Errorf("open native audio control input: %w", err) }
		stdout, err := cmd.StdoutPipe()
		if err != nil { _ = stdin.Close(); return nil, fmt.Errorf("open native audio control output: %w", err) }
		if err := cmd.Start(); err != nil { _ = stdin.Close(); return nil, fmt.Errorf("start native audio control process: %w", err) }
		audioProbeSessionCmd = cmd
		audioProbeSessionInput = stdin
		audioProbeSessionOutput = bufio.NewReaderSize(stdout, 4096)
	}
	if _, err := io.WriteString(audioProbeSessionInput, command+"\n"); err != nil {
		stopAudioProbeSessionLocked()
		return nil, fmt.Errorf("send native audio command: %w", err)
	}
	type readResult struct { line string; err error }
	result := make(chan readResult, 1)
	reader := audioProbeSessionOutput
	go func() { line, err := reader.ReadString('\n'); result <- readResult{line: line, err: err} }()
	var line string
	select {
	case response := <-result:
		if response.err != nil { stopAudioProbeSessionLocked(); return nil, fmt.Errorf("read native audio response: %w", response.err) }
		line = response.line
	case <-time.After(5 * time.Second):
		stopAudioProbeSessionLocked()
		return nil, fmt.Errorf("native audio command timed out")
	}
	if len(line) > 65536 {
		stopAudioProbeSessionLocked()
		return nil, fmt.Errorf("native audio response exceeded the size limit")
	}
	var response struct {
		Status string `json:"status"`
		Message string `json:"message"`
		MessageHex string `json:"messageHex"`
		Data map[string]any `json:"data"`
	}
	if err := json.Unmarshal([]byte(line), &response); err != nil {
		stopAudioProbeSessionLocked()
		return nil, fmt.Errorf("invalid native audio response")
	}
	if response.Status != "SUCCESS" {
		if response.MessageHex != "" {
			if raw, err := hex.DecodeString(response.MessageHex); err == nil { response.Message = strings.ToValidUTF8(string(raw), "\\uFFFD") }
		}
		return nil, fmt.Errorf("native audio operation failed: %s", strings.ToValidUTF8(response.Message, "\\uFFFD"))
	}
	return response.Data, nil
}

func diagnosticsSnapshot() map[string]any {
	metrics := collectMetrics()
	health := evaluateHardwareHealth(metrics)
	modelPath := strings.TrimSpace(os.Getenv("HWCONTROL_MODEL"))
	modelState := "managed-by-gui"
	if modelPath != "" {
		modelState = "missing"
		if info, err := os.Stat(modelPath); err == nil {
			modelState = "present"
			if info.Size() <= 0 {
				modelState = "invalid"
			}
		}
	}
	return map[string]any{
		"bridgeVersion":          bridgeVersion,
		"platform":               runtime.GOOS,
		"architecture":           runtime.GOARCH,
		"goVersion":              runtime.Version(),
		"keyFileConfigured":      strings.TrimSpace(os.Getenv("HWCONTROL_KEY_FILE")) != "",
		"keyConfigured":          strings.TrimSpace(os.Getenv("HWCONTROL_KEY")) != "" && strings.TrimSpace(os.Getenv("HWCONTROL_KEY")) != "replace-me",
		"bridgeIntegrityHealthy":  bridgeIntegrityHealthy(),
		"bridgeIntegrityMonitor":  strings.TrimSpace(os.Getenv("HWCONTROL_KEY")) == "" || strings.TrimSpace(os.Getenv("HWCONTROL_KEY")) == "replace-me",
		"bridgeIntegrityTargets":  bridgeIntegrityTargetCount.Load(),
		"modelPathConfigured":    modelPath != "",
		"modelState":             modelState,
		"modelSha256":            modelDigest(),
		"sensorSource":           metrics.SensorSource,
		"gpuVendor":              metrics.GPUVendor,
		"gpuDriver":              metrics.GPUDriver,
		"gpuDriverStatus":        metrics.GPUDriverStatus,
		"hardwareControl":        hasValidatedFanControl(metrics),
		"fanControlBackend":      metrics.FanControlBackend,
		"hardwareControlMode":    metrics.HardwareControlMode,
		"fanChannels":             metrics.FanChannels,
		"thermalSafetyAvailable": metrics.ThermalSafetyAvailable,
		"localOnly":              true,
		"listenAddress":          bridgeEndpoint(),
		"uptimeSeconds":          metrics.UptimeSeconds,
		"healthStatus":            health.Status,
		"safetyState":              health.SafetyState,
		"recoveryAction":           health.RecoveryAction,
		"hardwareCapabilities":     health.Capabilities,
		"hardwareAnomalies":        health.Anomalies,
		"services":                 serviceCatalogSnapshot(),
		"fetchStatus":              fetchStatusSnapshot(),
		"diagnosticService":        diagnosticServiceSnapshot(),
		"panicMode":                panicModeActive(),
		"gameMode": func() map[string]any {
			state := collectGameModeState()
			return map[string]any{
				"enabled": state.Enabled,
				"gameDetected": state.GameDetected,
				"processName": state.ProcessName,
				"pid": state.PID,
				"detectedAt": state.DetectedAt,
				"sessionDurationSeconds": state.SessionDurationSeconds,
				"optimizationMode": state.OptimizationMode,
			}
		}(),

		"hardwareIdentity": map[string]any{
			"systemManufacturer": metrics.SystemManufacturer,
			"systemModel":        metrics.SystemModel,
			"systemVersion":      metrics.SystemVersion,
			"biosVendor":         metrics.BIOSVendor,
			"biosVersion":        metrics.BIOSVersion,
			"motherboardVendor":  metrics.MotherboardVendor,
			"motherboardModel":   metrics.MotherboardModel,
			"motherboardVersion": metrics.MotherboardVersion,
			"cpuManufacturer":    metrics.CPUManufacturer,
			"cpuModel":           metrics.CPUModel,
			"cpuArchitecture":    metrics.CPUArchitecture,
			"cpuPhysicalCores":   metrics.CPUPhysicalCores,
			"cpuThreads":         metrics.CPUThreads,
			"gpuVendor":          metrics.GPUVendor,
			"gpuModel":           metrics.GPUModel,
			"gpuDriver":          metrics.GPUDriver,
			"gpuDriverVersion":   metrics.GPUDriverVersion,
			"detectionSource":    metrics.DetectionSource,
			"detectionStatus":    metrics.DetectionStatus,
			"serialsExcluded":    metrics.SerialsExcluded,
		},
	}
}

func bridgePort() string {
	port := strings.TrimSpace(os.Getenv("HWCONTROL_PORT"))
	if port == "" {
		return defaultBridgePort
	}
	parsed, err := strconv.Atoi(port)
	if err != nil || parsed < 1 || parsed > 65535 {
		return defaultBridgePort
	}
	return strconv.Itoa(parsed)
}

func readBoundedRequest(reader *bufio.Reader, limit int) ([]byte, error) {
	var line []byte
	for {
		fragment, err := reader.ReadSlice('\n')
		line = append(line, fragment...)
		if len(line) > limit {
			return nil, errRequestTooLarge
		}
		if err == nil {
			return line, nil
		}
		if errors.Is(err, bufio.ErrBufferFull) {
			continue
		}
		return nil, err
	}
}

var replayMu sync.Mutex
var replayNonces = map[string]time.Time{}

func consumeCommandNonce(nonce string, now time.Time) bool {
	replayMu.Lock()
	defer replayMu.Unlock()
	for key, expiresAt := range replayNonces {
		if now.After(expiresAt) {
			delete(replayNonces, key)
		}
	}
	if _, exists := replayNonces[nonce]; exists {
		return false
	}
	// Never evict a still-valid nonce to admit a new one: eviction would
	// make a previously accepted authenticated command replayable. When the
	// bounded cache is saturated, fail closed until entries expire.
	if len(replayNonces) >= maxReplayNonces {
		return false
	}
	replayNonces[nonce] = now.Add(commandClockSkew)
	return true
}

func decodeCommandStrict(line []byte, cmd *Command) error {
	decoder := json.NewDecoder(bytes.NewReader(line))
	decoder.DisallowUnknownFields()
	if err := decoder.Decode(cmd); err != nil {
		return err
	}
	var trailing any
	if err := decoder.Decode(&trailing); !errors.Is(err, io.EOF) {
		if err == nil {
			return errors.New("multiple JSON values are not allowed")
		}
		return err
	}
	return nil
}

func handleConnection(conn net.Conn, secret string) {
	defer conn.Close()
	defer func() {
		if recovered := recover(); recovered != nil {
			log.Printf("connection panic recovered: %v", recovered)
		}
	}()
	reader := bufio.NewReaderSize(conn, 4096)
	encoder := json.NewEncoder(conn)
	authFailures := 0
	invalidRequests := 0
	var lastCommandAt time.Time
	for {
		_ = conn.SetReadDeadline(time.Now().Add(connectionTimeout))
		line, err := readBoundedRequest(reader, maxRequestBytes)
		if err != nil {
			if errors.Is(err, errRequestTooLarge) {
				_ = conn.SetWriteDeadline(time.Now().Add(connectionTimeout))
				_ = encoder.Encode(Response{Status: "ERROR", Message: "request too large"})
			}
			return
		}
		if !bridgeIntegrityHealthy() {
			_ = conn.SetWriteDeadline(time.Now().Add(connectionTimeout))
			_ = encoder.Encode(Response{Status: "ERROR", Message: "bridge integrity check failed; service is fail-closed"})
			return
		}
		var cmd Command
		if err := decodeCommandStrict(line, &cmd); err != nil {
			invalidRequests++
			_ = conn.SetWriteDeadline(time.Now().Add(connectionTimeout))
			if writeErr := encoder.Encode(Response{Status: "ERROR", Message: "invalid request"}); writeErr != nil || invalidRequests >= 5 {
				return
			}
			continue
		}
		if err := validateCommand(cmd); err != nil {
			invalidRequests++
			_ = conn.SetWriteDeadline(time.Now().Add(connectionTimeout))
			if writeErr := encoder.Encode(Response{Status: "ERROR", Message: err.Error()}); writeErr != nil || invalidRequests >= 5 {
				return
			}
			continue
		}
		if !authenticateCommand(cmd, secret) {
			authFailures++
			_ = conn.SetWriteDeadline(time.Now().Add(connectionTimeout))
			if err := encoder.Encode(Response{Status: "ERROR", Message: "authentication failed"}); err != nil || authFailures >= 5 {
				return
			}
			continue
		}
		invalidRequests = 0
		if !consumeCommandNonce(cmd.Nonce, time.Now()) {
			invalidRequests++
			_ = conn.SetWriteDeadline(time.Now().Add(connectionTimeout))
			if err := encoder.Encode(Response{Status: "ERROR", Message: "nonce rejected by replay protection"}); err != nil || invalidRequests >= 5 {
				return
			}
			continue
		}
		authFailures = 0
		if panicModeActive() {
			switch cmd.Action {
			case "Get Status", "Get Security", "Get Diagnostics", "Get Health", "Get Game Mode", "Get Update", "Get Sensor Health", "Get Sensor History", "Get Fan Channels", "Get Fetch Status", "Get Power Mode", "Get Audio Devices":
				// Read-only diagnostics remain available so the user can see why the system entered panic mode.
			default:
				_ = conn.SetWriteDeadline(time.Now().Add(connectionTimeout))
				if err := encoder.Encode(Response{Status: "ERROR", Message: "security panic mode active; hardware-control request denied"}); err != nil { return }
				continue
			}
		}
		now := time.Now()
		if !lastCommandAt.IsZero() && now.Sub(lastCommandAt) < minimumCommandInterval {
			_ = conn.SetWriteDeadline(now.Add(connectionTimeout))
			if err := encoder.Encode(Response{Status: "ERROR", Message: "command rate limit exceeded"}); err != nil {
				return
			}
			continue
		}
		lastCommandAt = now
		if cmd.Action == "Get Audio Devices" {
			data, audioErr := audioDeviceSnapshot()
			_ = conn.SetWriteDeadline(time.Now().Add(connectionTimeout))
			if audioErr != nil {
				if err := encoder.Encode(Response{Status: "ERROR", Message: audioErr.Error()}); err != nil { return }
			} else {
				if err := encoder.Encode(Response{Status: "SUCCESS", Message: "Native audio endpoints enumerated locally", Data: data}); err != nil { return }
			}
			continue
		}
		if cmd.Action == "Start Audio Studio" || cmd.Action == "Stop Audio Studio" || cmd.Action == "Get Audio Studio Status" {
			var control string
			switch cmd.Action {
			case "Start Audio Studio":
				request, requestErr := decodeAudioStudioStartTarget(cmd.Target)
				if requestErr != nil {
					_ = conn.SetWriteDeadline(time.Now().Add(connectionTimeout))
					if err := encoder.Encode(Response{Status: "ERROR", Message: requestErr.Error()}); err != nil { return }
					continue
				}
				control = audioStudioStartLine(request)
			case "Stop Audio Studio":
				control = "stop"
			default:
				control = "status"
			}
			data, audioErr := audioProbeControl(control)
			_ = conn.SetWriteDeadline(time.Now().Add(connectionTimeout))
			if audioErr != nil {
				if err := encoder.Encode(Response{Status: "ERROR", Message: audioErr.Error()}); err != nil { return }
			} else {
				message := "Audio studio status retrieved"
				if cmd.Action == "Start Audio Studio" { message = "Native audio processing started" }
				if cmd.Action == "Stop Audio Studio" { message = "Native audio processing stopped" }
				if err := encoder.Encode(Response{Status: "SUCCESS", Message: message, Data: data}); err != nil { return }
			}
			continue
		}
		if cmd.Action == "Get Update" {
			status := checkForUpdates(context.Background())
			_ = conn.SetWriteDeadline(time.Now().Add(connectionTimeout))
			if err := encoder.Encode(Response{Status: "SUCCESS", Message: "Update Service durumu alındı", Data: status}); err != nil { return }
			continue
		}
		if cmd.Action == "Get Sensor Health" {
			_ = conn.SetWriteDeadline(time.Now().Add(connectionTimeout))
			if err := encoder.Encode(Response{Status: "SUCCESS", Message: "SensorHealth durumu alındı", Data: sensorHealthSnapshot()}); err != nil { return }
			continue
		}
		if cmd.Action == "Get Sensor History" {
			_ = conn.SetWriteDeadline(time.Now().Add(connectionTimeout))
			if err := encoder.Encode(Response{Status: "SUCCESS", Message: "Yerel sensör geçmişi alındı", Data: sensorHistorySnapshot()}); err != nil { return }
			continue
		}
		if cmd.Action == "Get Fetch Status" {
			checkDecoyIntegrity()
			_ = conn.SetWriteDeadline(time.Now().Add(connectionTimeout))
			if err := encoder.Encode(Response{Status: "SUCCESS", Message: "Fetch Status durumu alındı", Data: fetchStatusSnapshot()}); err != nil { return }
			continue
		}
		if cmd.Action == "Get Fan Channels" {
			_ = conn.SetWriteDeadline(time.Now().Add(connectionTimeout))
			if err := encoder.Encode(Response{
				Status:  "SUCCESS",
				Message: "Fan channel capabilities retrieved",
				Data: map[string]any{
					"channels": listFanChannels(),
					"localOnly": true,
				},
			}); err != nil {
				return
			}
			continue
		}
		if cmd.Action == "Get Status" {
			_ = conn.SetWriteDeadline(time.Now().Add(connectionTimeout))
			if err := encoder.Encode(Response{Status: "SUCCESS", Message: "Metrikler alındı", Data: collectMetrics()}); err != nil {
				return
			}
			continue
		}
		if cmd.Action == "Get Power Mode" {
			state := getPlatformPowerMode()
			_ = conn.SetWriteDeadline(time.Now().Add(connectionTimeout))
			if err := encoder.Encode(Response{Status: "SUCCESS", Message: state.Message, Data: state}); err != nil {
				return
			}
			continue
		}
		if cmd.Action == "Get Health" {
			_ = conn.SetWriteDeadline(time.Now().Add(connectionTimeout))
			if err := encoder.Encode(Response{Status: "SUCCESS", Message: "Health durumu alındı", Data: healthSnapshot()}); err != nil {
				return
			}
			continue
		}
		if cmd.Action == "Get Game Mode" {
			_ = conn.SetWriteDeadline(time.Now().Add(connectionTimeout))
			if err := encoder.Encode(Response{Status: "SUCCESS", Message: "Game Mode durumu alındı", Data: collectGameModeState()}); err != nil {
				return
			}
			continue
		}
		if cmd.Action == "Get Security" {
			_ = conn.SetWriteDeadline(time.Now().Add(connectionTimeout))
			if err := encoder.Encode(Response{Status: "SUCCESS", Message: "Güvenlik durumu alındı", Data: map[string]any{
				"hmac":              true,
				"bridgeIntegrity":   bridgeIntegrityHealthy(),
				"modelSha256":       modelDigest(),
				"keyFileConfigured": strings.TrimSpace(os.Getenv("HWCONTROL_KEY_FILE")) != "",
				"panicMode":          panicModeActive(),
				"services":           serviceCatalogSnapshot(),
			}}); err != nil {
				return
			}
			continue
		}
		if cmd.Action == "Get Diagnostics" {
			_ = conn.SetWriteDeadline(time.Now().Add(connectionTimeout))
			if err := encoder.Encode(Response{Status: "SUCCESS", Message: "Diagnostics hazır", Data: diagnosticsSnapshot()}); err != nil {
				return
			}
			continue
		}
		if err := executeHardwareCommand(cmd); err != nil {
			_ = conn.SetWriteDeadline(time.Now().Add(connectionTimeout))
			if err := encoder.Encode(Response{Status: "ERROR", Message: err.Error()}); err != nil {
				return
			}
			continue
		}
		// Every accepted command must receive a response. Previously successful
		// control commands could leave the GUI waiting until its timeout.
		if cmd.Action == "Set Power Mode AC" || cmd.Action == "Set Power Mode DC" {
			state := getPlatformPowerMode()
			_ = conn.SetWriteDeadline(time.Now().Add(connectionTimeout))
			if err := encoder.Encode(Response{Status: "SUCCESS", Message: state.Message, Data: state}); err != nil {
				return
			}
			continue
		}
		_ = conn.SetWriteDeadline(time.Now().Add(connectionTimeout))
		if err := encoder.Encode(Response{Status: "SUCCESS", Message: cmd.Action + " applied", Data: map[string]any{"action": cmd.Action, "value": cmd.Value}}); err != nil {
			return
		}
	}
}
func main() {
	handled, err := runWindowsService()
	if err != nil {
		fmt.Println("Windows service başlatılamadı:", err)
		os.Exit(1)
	}
	if handled {
		return
	}

	bridge := newBridgeService()
	stopSignals := installConsoleShutdown(bridge)
	defer stopSignals()
	if err := runBridge(context.Background(), bridge); err != nil {
		fmt.Println("Bridge başlatılamadı:", err)
		os.Exit(1)
	}
}