package main

import (
	"bufio"
	"context"
	"crypto/hmac"
	"crypto/rand"
	"crypto/sha256"
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
	Target    string          `json:"target,omitempty"`
	Payload   json.RawMessage `json:"payload,omitempty"`
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
	if len(cmd.Payload) > 0 && string(cmd.Payload) != "null" {
		payload += "\n" + string(cmd.Payload)
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
	GameModeEnabled        bool      `json:"gameModeEnabled"`
	GameDetected           bool      `json:"gameDetected"`
	GameProcessName        string    `json:"gameProcessName"`
	GameProcessPID          uint32    `json:"gameProcessPid"`
	GameDetectedAt          string    `json:"gameDetectedAt"`
	GameSessionDurationSeconds int64 `json:"gameSessionDurationSeconds"`
	SystemManufacturer     string    `json:"systemManufacturer"`
	SystemModel            string    `json:"systemModel"`
	SystemVersion          string    `json:"systemVersion"`
	BIOSVendor             string    `json:"biosVendor"`
	BIOSVersion            string    `json:"biosVersion"`
	MotherboardVendor      string    `json:"motherboardVendor"`
	MotherboardModel       string    `json:"motherboardModel"`
	MotherboardVersion     string    `json:"motherboardVersion"`
	CPUManufacturer        string    `json:"cpuManufacturer"`
	CPUModel               string    `json:"cpuModel"`
	CPUArchitecture        string    `json:"cpuArchitecture"`
	CPUPhysicalCores       int       `json:"cpuPhysicalCores"`
	CPUThreads             int       `json:"cpuThreads"`
	GPUModel               string    `json:"gpuModel"`
	DetectionSource        string    `json:"detectionSource"`
	DetectionStatus        string    `json:"detectionStatus"`
	SerialsExcluded        bool      `json:"serialsExcluded"`
	CPUUsage               float64   `json:"cpuUsage"`
	CPUPerCoreUsage        []float64 `json:"cpuPerCoreUsage"`
	CPUCoreCount           int       `json:"cpuCoreCount"`
	CPUFrequencyMHz        float64   `json:"cpuFrequencyMHz"`
	CPUTemperature         float64   `json:"cpuTemperature"`
	CPUTemperatureSource   string    `json:"cpuTemperatureSource,omitempty"`
	GPUTemperature         float64   `json:"gpuTemperature"`
	GPUTemperatureSource   string    `json:"gpuTemperatureSource,omitempty"`
	MetricsCollectedAt     string    `json:"metricsCollectedAt"`
	GPUUsage               float64   `json:"gpuUsage"`
	GPUMemoryUsage         float64   `json:"gpuMemoryUsage"`
	GPUPowerLimitWatts     float64   `json:"gpuPowerLimitWatts"`
	GPUPState              string    `json:"gpuPState"`
	GPUEncoderUsage        float64   `json:"gpuEncoderUsage"`
	GPUDecoderUsage        float64   `json:"gpuDecoderUsage"`
	FanPercent             float64   `json:"fanPercent"`
	FanPercentSource       string    `json:"fanPercentSource,omitempty"`
	FanRPM                 float64   `json:"fanRpm"`
	FanRPMSource           string    `json:"fanRpmSource,omitempty"`
	MemoryUsage            float64   `json:"memoryUsage"`
	MemoryTotalBytes       uint64    `json:"memoryTotalBytes"`
	DiskUsage              float64   `json:"diskUsage"`
	DiskTotalBytes         uint64    `json:"diskTotalBytes"`
	StorageVolumes         []StorageVolume `json:"storageVolumes"`
	PowerWatts             float64   `json:"powerWatts"`
	Voltage                float64   `json:"voltage"`
	UptimeSeconds          uint64    `json:"uptimeSeconds"`
	Platform               string    `json:"platform"`
	GPUVendor              string    `json:"gpuVendor"`
	GPUName                string    `json:"gpuName"`
	GPUDriver              string    `json:"gpuDriver"`
	GPUDriverProvider      string    `json:"gpuDriverProvider"`
	GPUDriverVersion       string    `json:"gpuDriverVersion"`
	GPUDriverStatus        string    `json:"gpuDriverStatus"`
	GPUDriverSource        string    `json:"gpuDriverSource"`
	GPUDriverAction        string    `json:"gpuDriverAction"`
	GPUDriverReason        string    `json:"gpuDriverReason"`
	GPUMemoryUsedBytes     uint64    `json:"gpuMemoryUsedBytes"`
	GPUMemoryTotalBytes    uint64    `json:"gpuMemoryTotalBytes"`
	GPUCoreClockMHz        float64   `json:"gpuCoreClockMHz"`
	GPUMemoryClockMHz      float64   `json:"gpuMemoryClockMHz"`
	SensorSource           string    `json:"sensorSource"`
	FanControlSupported    bool      `json:"fanControlSupported"`
	FanControlBackend      string    `json:"fanControlBackend"`
	FanChannels            []FanChannel `json:"fanChannels"`
	HardwareControlMode    string    `json:"hardwareControlMode"`
	ThermalSafetyAvailable bool      `json:"thermalSafetyAvailable"`
	Battery                BatteryMetrics `json:"battery"`
}



type audioDeviceRecord struct {
	Index int `json:"index"`
	NameHex string `json:"nameHex"`
	IsDefault bool `json:"isDefault"`
}

type audioDevice struct {
	Index int `json:"index"`
	Name string `json:"name"`
	IsDefault bool `json:"isDefault"`
}

func runAudioDeviceProbe() (map[string]any, error) {
	executable, err := os.Executable()
	if err != nil { return nil, fmt.Errorf("could not locate HWcontrol installation") }
	name := "hwcontrol_audio_probe"
	if runtime.GOOS == "windows" { name += ".exe" }
	probePath := filepath.Join(filepath.Dir(executable), name)
	info, err := os.Stat(probePath)
	if err != nil || !info.Mode().IsRegular() {
		return nil, fmt.Errorf("native audio device probe is not installed beside the bridge")
	}
	if runtime.GOOS != "windows" && info.Mode().Perm()&0111 == 0 {
		return nil, fmt.Errorf("native audio device probe is not executable")
	}
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	cmd := exec.CommandContext(ctx, probePath, "--json")
	cmd.Stderr = io.Discard
	output, err := cmd.Output()
	if ctx.Err() != nil { return nil, fmt.Errorf("audio device enumeration timed out") }
	if err != nil || len(output) > 64*1024 {
		return nil, fmt.Errorf("native audio device enumeration failed")
	}
	var raw struct {
		Capture []audioDeviceRecord `json:"capture"`
		Playback []audioDeviceRecord `json:"playback"`
	}
	if err := json.Unmarshal(output, &raw); err != nil {
		return nil, fmt.Errorf("native audio device probe returned invalid data")
	}
	decode := func(records []audioDeviceRecord) ([]audioDevice, error) {
		result := make([]audioDevice, 0, len(records))
		for _, record := range records {
			if record.Index < 0 || len(record.NameHex) > 1024 || len(record.NameHex)%2 != 0 {
				return nil, fmt.Errorf("native audio device metadata is invalid")
			}
			nameBytes, err := hex.DecodeString(record.NameHex)
			if err != nil || len(nameBytes) > 512 {
				return nil, fmt.Errorf("native audio device name is invalid")
			}
			result = append(result, audioDevice{Index: record.Index, Name: string(nameBytes), IsDefault: record.IsDefault})
		}
		return result, nil
	}
	capture, err := decode(raw.Capture)
	if err != nil { return nil, err }
	playback, err := decode(raw.Playback)
	if err != nil { return nil, err }
	return map[string]any{"capture": capture, "playback": playback, "localOnly": true}, nil
}

type AudioProfileRequest struct {
	DeviceType string `json:"deviceType"`
	Model string `json:"model"`
	Manufacturer string `json:"manufacturer,omitempty"`
	Usage string `json:"usage"`
	SampleRateHz uint32 `json:"sampleRateHz"`
	Channels uint32 `json:"channels"`
	SpecificationsVerified bool `json:"specificationsVerified"`
}

func validateAudioProfilePayload(raw json.RawMessage) error {
	var request AudioProfileRequest
	decoder := json.NewDecoder(strings.NewReader(string(raw)))
	decoder.DisallowUnknownFields()
	if err := decoder.Decode(&request); err != nil {
		return fmt.Errorf("invalid audio profile payload")
	}
	var trailing any
	if err := decoder.Decode(&trailing); err != io.EOF {
		return fmt.Errorf("audio profile payload contains trailing data")
	}
	if len(strings.TrimSpace(request.Model)) == 0 || len(request.Model) > 120 || len(request.Manufacturer) > 80 {
		return fmt.Errorf("device model/manufacturer length is invalid")
	}
	for _, value := range []string{request.Model, request.Manufacturer} {
		for _, r := range value {
			if r < 0x20 || r == 0x7f {
				return fmt.Errorf("device labels must not contain control characters")
			}
		}
	}
	switch request.DeviceType {
	case "microphone", "speaker", "headphones", "headset":
	default:
		return fmt.Errorf("unsupported audio device type")
	}
	switch request.Usage {
	case "voice", "gaming", "music", "movie", "meeting", "streaming":
	default:
		return fmt.Errorf("unsupported audio usage")
	}
	if request.SampleRateHz < 8000 || request.SampleRateHz > 192000 || request.Channels < 1 || request.Channels > 8 {
		return fmt.Errorf("audio capabilities are outside supported bounds")
	}
	return nil
}

func runLocalAudioProfileAdvisor(request AudioProfileRequest) (string, error) {
	payload, err := json.Marshal(request)
	if err != nil { return "", fmt.Errorf("could not encode audio profile") }
	if err := validateAudioProfilePayload(payload); err != nil { return "", err }
	executable, err := os.Executable()
	if err != nil { return "", fmt.Errorf("could not locate HWcontrol installation") }
	name := "ai_engine"
	if runtime.GOOS == "windows" { name += ".exe" }
	advisorPath := filepath.Join(filepath.Dir(executable), name)
	info, err := os.Stat(advisorPath)
	if err != nil || !info.Mode().IsRegular() {
		return "", fmt.Errorf("local Gemma engine is not installed beside the bridge")
	}
	if runtime.GOOS != "windows" && info.Mode().Perm()&0111 == 0 {
		return "", fmt.Errorf("local Gemma engine is not executable")
	}
	ctx, cancel := context.WithTimeout(context.Background(), 90*time.Second)
	defer cancel()
	cmd := exec.CommandContext(ctx, advisorPath, "--stdio")
	stdin, err := cmd.StdinPipe()
	if err != nil { return "", fmt.Errorf("could not open local AI input") }
	stdout, err := cmd.StdoutPipe()
	if err != nil { return "", fmt.Errorf("could not open local AI output") }
	cmd.Stderr = io.Discard
	if err := cmd.Start(); err != nil { return "", fmt.Errorf("could not start local Gemma engine") }
	modelHex := hex.EncodeToString([]byte(request.Model))
	manufacturerHex := hex.EncodeToString([]byte(request.Manufacturer))
	verified := "0"
	if request.SpecificationsVerified { verified = "1" }
	line := fmt.Sprintf("AUDIO type=%s usage=%s rate=%d channels=%d model_hex=%s",
		request.DeviceType, request.Usage, request.SampleRateHz, request.Channels, modelHex)
	if manufacturerHex != "" {
		line += " manufacturer_hex=" + manufacturerHex
	}
	line += " verified=" + verified + "\n"
	if _, err := io.WriteString(stdin, line); err != nil {
		_ = cmd.Process.Kill()
		_ = cmd.Wait()
		return "", fmt.Errorf("could not submit audio profile to local Gemma")
	}
	_ = stdin.Close()
	reader := bufio.NewReaderSize(stdout, 4096)
	response, readErr := reader.ReadString('\n')
	waitErr := cmd.Wait()
	if ctx.Err() != nil { return "", fmt.Errorf("local Gemma recommendation timed out") }
	if readErr != nil || waitErr != nil {
		return "", fmt.Errorf("local Gemma engine failed; check that its model is installed")
	}
	response = strings.TrimSpace(response)
	if !strings.HasPrefix(response, "AUDIO_OK|") {
		return "", fmt.Errorf("local Gemma did not return a valid audio recommendation")
	}
	response = strings.TrimPrefix(response, "AUDIO_OK|")
	if len(response) == 0 || len(response) > 1200 {
		return "", fmt.Errorf("local Gemma recommendation was empty or too large")
	}
	return response, nil
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
	if len(action) > maxActionLength {
		return fmt.Errorf("action is too long")
	}
	if math.IsNaN(cmd.Value) || math.IsInf(cmd.Value, 0) || cmd.Value < 0 || cmd.Value > 100 {
		return fmt.Errorf("value must be between 0 and 100")
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
	if action == "Set Fan Channel" {
		if !validFanChannelID(cmd.Target) {
			return fmt.Errorf("Set Fan Channel requires a valid channel identifier")
		}
		if err := validateFanPercent(cmd.Value); err != nil {
			return err
		}
	} else if cmd.Target != "" {
		return fmt.Errorf("target is only accepted for Set Fan Channel")
	}
	if len(cmd.Payload) > 2048 {
		return fmt.Errorf("payload is too large")
	}
	if action != "Get Audio Profile" && len(cmd.Payload) > 0 && string(cmd.Payload) != "null" {
		return fmt.Errorf("payload is only accepted for Get Audio Profile")
	}
	switch action {
	case "Fan Hızı", "AI İşlem Gücü", "Set Game Mode":
		return nil
	case "Set Fan Channel":
		return validateFanPercent(cmd.Value)
	case "Set Power Mode AC", "Set Power Mode DC":
		return validatePowerModeRequest(action, cmd.Value)
	case "Set Power Profile":
		return validatePowerModeRequest("Set Power Mode AC", cmd.Value)
	case "Get Audio Devices":
		if cmd.Value != 0 || len(cmd.Payload) > 0 { return fmt.Errorf("Get Audio Devices is read-only") }
		return nil
	case "Get Audio Profile":
		if cmd.Value != 0 || len(cmd.Payload) == 0 || string(cmd.Payload) == "null" {
			return fmt.Errorf("Get Audio Profile requires a payload and zero command value")
		}
		return validateAudioProfilePayload(cmd.Payload)
	case "Get Power Mode":
		if cmd.Value != 0 {
			return fmt.Errorf("read-only command value must be zero")
		}
		return nil
	case "Get Status", "Get Security", "Get Diagnostics", "Get Health", "Get Game Mode", "Get Update", "Get Sensor Health", "Get Sensor History", "Get Fan Channels", "Get Fetch Status":
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
	if len(replayNonces) >= maxReplayNonces {
		var oldestNonce string
		var oldestExpiry time.Time
		for key, expiresAt := range replayNonces {
			if oldestNonce == "" || expiresAt.Before(oldestExpiry) {
				oldestNonce = key
				oldestExpiry = expiresAt
			}
		}
		if oldestNonce != "" {
			delete(replayNonces, oldestNonce)
		}
	}
	replayNonces[nonce] = now.Add(commandClockSkew)
	return true
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
		if err := json.Unmarshal(line, &cmd); err != nil {
			_ = conn.SetWriteDeadline(time.Now().Add(connectionTimeout))
			_ = encoder.Encode(Response{Status: "ERROR", Message: "invalid request"})
			continue
		}
		if err := validateCommand(cmd); err != nil {
			_ = conn.SetWriteDeadline(time.Now().Add(connectionTimeout))
			if err := encoder.Encode(Response{Status: "ERROR", Message: err.Error()}); err != nil {
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
		if !consumeCommandNonce(cmd.Nonce, time.Now()) {
			_ = conn.SetWriteDeadline(time.Now().Add(connectionTimeout))
			if err := encoder.Encode(Response{Status: "ERROR", Message: "replayed command rejected"}); err != nil {
				return
			}
			continue
		}
		authFailures = 0
		if panicModeActive() {
			switch cmd.Action {
			case "Get Status", "Get Security", "Get Diagnostics", "Get Health", "Get Game Mode", "Get Update", "Get Sensor Health", "Get Sensor History", "Get Fan Channels", "Get Fetch Status", "Get Power Mode":
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
			data, err := runAudioDeviceProbe()
			_ = conn.SetWriteDeadline(time.Now().Add(connectionTimeout))
			if err != nil {
				if encoder.Encode(Response{Status: "ERROR", Message: err.Error()}) != nil { return }
			} else if encoder.Encode(Response{Status: "SUCCESS", Message: "Local audio devices enumerated", Data: data}) != nil { return }
			continue
		}
		if cmd.Action == "Get Audio Profile" {
			var request AudioProfileRequest
			if err := json.Unmarshal(cmd.Payload, &request); err != nil {
				_ = conn.SetWriteDeadline(time.Now().Add(connectionTimeout))
				if encoder.Encode(Response{Status: "ERROR", Message: "invalid audio profile payload"}) != nil { return }
				continue
			}
			recommendation, err := runLocalAudioProfileAdvisor(request)
			_ = conn.SetWriteDeadline(time.Now().Add(connectionTimeout))
			if err != nil {
				if encoder.Encode(Response{Status: "ERROR", Message: err.Error()}) != nil { return }
			} else if encoder.Encode(Response{Status: "SUCCESS", Message: "Local Gemma audio recommendation generated", Data: map[string]any{
				"recommendation": recommendation,
				"localOnly": true,
				"requiresApproval": true,
			}}) != nil { return }
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