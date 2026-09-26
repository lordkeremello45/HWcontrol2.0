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
	Timestamp int64   `json:"timestamp"`
	Nonce     string  `json:"nonce"`
	Auth      string  `json:"auth"`
}

const (
	commandClockSkew = 30 * time.Second
	minimumCommandInterval = 100 * time.Millisecond
	maxReplayNonces = 4096
)

func commandPayload(cmd Command) string {
	return cmd.Action + "\n" +
		strconv.FormatFloat(cmd.Value, 'f', 6, 64) + "\n" +
		strconv.FormatInt(cmd.Timestamp, 10) + "\n" +
		cmd.Nonce
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
	GameModeEnabled     bool      `json:"gameModeEnabled"`
	GameDetected        bool      `json:"gameDetected"`
	GameProcessName     string    `json:"gameProcessName"`
	SystemManufacturer  string    `json:"systemManufacturer"`
	SystemModel         string    `json:"systemModel"`
	SystemVersion       string    `json:"systemVersion"`
	BIOSVendor          string    `json:"biosVendor"`
	BIOSVersion         string    `json:"biosVersion"`
	MotherboardVendor   string    `json:"motherboardVendor"`
	MotherboardModel    string    `json:"motherboardModel"`
	MotherboardVersion  string    `json:"motherboardVersion"`
	CPUManufacturer     string    `json:"cpuManufacturer"`
	CPUModel            string    `json:"cpuModel"`
	CPUArchitecture     string    `json:"cpuArchitecture"`
	CPUPhysicalCores    int       `json:"cpuPhysicalCores"`
	CPUThreads          int       `json:"cpuThreads"`
	GPUModel            string    `json:"gpuModel"`
	DetectionSource     string    `json:"detectionSource"`
	DetectionStatus     string    `json:"detectionStatus"`
	SerialsExcluded     bool      `json:"serialsExcluded"`
	CPUUsage            float64   `json:"cpuUsage"`
	CPUPerCoreUsage     []float64 `json:"cpuPerCoreUsage"`
	CPUCoreCount        int       `json:"cpuCoreCount"`
	CPUFrequencyMHz     float64   `json:"cpuFrequencyMHz"`
	CPUTemperature      float64   `json:"cpuTemperature"`
	GPUTemperature      float64   `json:"gpuTemperature"`
	GPUUsage            float64   `json:"gpuUsage"`
	GPUMemoryUsage      float64   `json:"gpuMemoryUsage"`
	GPUPowerLimitWatts  float64   `json:"gpuPowerLimitWatts"`
	GPUPState           string    `json:"gpuPState"`
	GPUEncoderUsage     float64   `json:"gpuEncoderUsage"`
	GPUDecoderUsage     float64   `json:"gpuDecoderUsage"`
	FanPercent          float64   `json:"fanPercent"`
	FanRPM              float64   `json:"fanRpm"`
	MemoryUsage         float64   `json:"memoryUsage"`
	MemoryTotalBytes    uint64    `json:"memoryTotalBytes"`
	DiskUsage           float64   `json:"diskUsage"`
	DiskTotalBytes      uint64    `json:"diskTotalBytes"`
	PowerWatts          float64   `json:"powerWatts"`
	Voltage             float64   `json:"voltage"`
	UptimeSeconds       uint64    `json:"uptimeSeconds"`
	Platform            string    `json:"platform"`
	GPUVendor           string    `json:"gpuVendor"`
	GPUName             string    `json:"gpuName"`
	GPUDriver           string    `json:"gpuDriver"`
	GPUDriverProvider   string    `json:"gpuDriverProvider"`
	GPUDriverVersion    string    `json:"gpuDriverVersion"`
	GPUDriverStatus     string    `json:"gpuDriverStatus"`
	GPUDriverSource     string    `json:"gpuDriverSource"`
	GPUDriverAction     string    `json:"gpuDriverAction"`
	GPUDriverReason     string    `json:"gpuDriverReason"`
	GPUMemoryUsedBytes  uint64    `json:"gpuMemoryUsedBytes"`
	GPUMemoryTotalBytes uint64    `json:"gpuMemoryTotalBytes"`
	GPUCoreClockMHz     float64   `json:"gpuCoreClockMHz"`
	GPUMemoryClockMHz   float64   `json:"gpuMemoryClockMHz"`
	SensorSource        string    `json:"sensorSource"`
	FanControlSupported bool      `json:"fanControlSupported"`
	FanControlBackend   string    `json:"fanControlBackend"`
	HardwareControlMode   string  `json:"hardwareControlMode"`
	ThermalSafetyAvailable bool   `json:"thermalSafetyAvailable"`
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
	if temperatures, err := host.SensorsTemperatures(); err == nil {
		for _, sensor := range temperatures {
			key := strings.ToLower(sensor.SensorKey)
			if strings.Contains(key, "cpu") || strings.Contains(key, "package") || strings.Contains(key, "core") {
				metrics.CPUTemperature = sensor.Temperature
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
				metrics.GPUTemperature, _ = strconv.ParseFloat(strings.TrimSpace(parts[2]), 64)
				metrics.GPUUsage, _ = strconv.ParseFloat(strings.TrimSpace(parts[3]), 64)
				metrics.GPUMemoryUsage, _ = strconv.ParseFloat(strings.TrimSpace(parts[4]), 64)
				metrics.FanPercent, _ = strconv.ParseFloat(strings.TrimSpace(parts[5]), 64)
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
	}
	mergePlatformMetrics(&metrics)
	metrics.FanControlSupported = false
	metrics.FanControlBackend = "monitor-only"
	metrics.HardwareControlMode = "monitor-only"
	metrics.ThermalSafetyAvailable = metrics.CPUTemperature > 0 || metrics.GPUTemperature > 0
	game := collectGameModeState()
	metrics.GameModeEnabled = game.Enabled
	metrics.GameDetected = game.GameDetected
	metrics.GameProcessName = game.ProcessName
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

func validateCommand(cmd Command) error {
	if strings.TrimSpace(cmd.Action) == "" {
		return fmt.Errorf("action is required")
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
	switch cmd.Action {
	case "Fan Hızı", "AI İşlem Gücü", "Get Status", "Get Security", "Get Diagnostics", "Get Health", "Get Game Mode", "Set Game Mode":
		return nil
	default:
		return fmt.Errorf("unsupported action: %s", cmd.Action)
	}
}

const (
	criticalCPUTemperature = 95.0
	criticalGPUTemperature = 95.0
)

func hardwareControlSafetyError(metrics HardwareMetrics) error {
	if metrics.CPUTemperature >= criticalCPUTemperature || metrics.GPUTemperature >= criticalGPUTemperature {
		return fmt.Errorf("hardware control blocked: critical temperature detected")
	}
	return nil
}

func validateFanControlRequest(cmd Command, metrics HardwareMetrics) error {
	if cmd.Action != "Fan Hızı" {
		return nil
	}
	if !metrics.ThermalSafetyAvailable {
		return fmt.Errorf("hardware control blocked: no valid thermal sensor available")
	}
	if err := hardwareControlSafetyError(metrics); err != nil {
		return err
	}
	if !metrics.FanControlSupported || metrics.FanControlBackend == "" || metrics.FanControlBackend == "monitor-only" {
		return fmt.Errorf("hardware fan control is unavailable")
	}
	return nil
}

func executeHardwareCommand(cmd Command) error {
	switch cmd.Action {
	case "Fan Hızı":
		metrics := collectMetrics()
		if err := validateFanControlRequest(cmd, metrics); err != nil {
			return err
		}
		return fmt.Errorf("hardware control backend is not available on this build")
	case "AI İşlem Gücü":
		return fmt.Errorf("hardware control backend is not available on this build")
	case "Set Game Mode":
		setGameModeEnabled(cmd.Value >= 50)
		return nil
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
	tmp := path + ".tmp"
	if err := os.WriteFile(tmp, []byte(secret+"\n"), 0600); err != nil {
		return "", fmt.Errorf("write bridge key: %w", err)
	}
	if err := os.Chmod(tmp, 0600); err != nil && runtime.GOOS != "windows" {
		_ = os.Remove(tmp)
		return "", fmt.Errorf("protect bridge key: %w", err)
	}
	if err := os.Rename(tmp, path); err != nil {
		_ = os.Remove(tmp)
		return "", fmt.Errorf("commit bridge key: %w", err)
	}
	return secret, nil
}

func diagnosticsSnapshot() map[string]any {
	metrics := collectMetrics()
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
		"bridgeVersion":       bridgeVersion,
		"platform":            runtime.GOOS,
		"architecture":        runtime.GOARCH,
		"goVersion":           runtime.Version(),
		"keyFile":             defaultKeyFile(),
		"keyConfigured":       strings.TrimSpace(os.Getenv("HWCONTROL_KEY")) != "" && strings.TrimSpace(os.Getenv("HWCONTROL_KEY")) != "replace-me",
		"modelPath":           modelPath,
		"modelState":          modelState,
		"modelSha256":         modelDigest(),
		"sensorSource":        metrics.SensorSource,
		"gpuVendor":           metrics.GPUVendor,
		"gpuDriver":           metrics.GPUDriver,
		"gpuDriverStatus":     metrics.GPUDriverStatus,
		"hardwareControl":     metrics.FanControlSupported,
		"fanControlBackend":   metrics.FanControlBackend,
		"hardwareControlMode":   metrics.HardwareControlMode,
		"thermalSafetyAvailable": metrics.ThermalSafetyAvailable,
		"localOnly":           true,
		"listenAddress":       bridgeEndpoint(),
		"uptimeSeconds":       metrics.UptimeSeconds,
		"gameMode":            collectGameModeState(),
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
		now := time.Now()
		if !lastCommandAt.IsZero() && now.Sub(lastCommandAt) < minimumCommandInterval {
			_ = conn.SetWriteDeadline(now.Add(connectionTimeout))
			if err := encoder.Encode(Response{Status: "ERROR", Message: "command rate limit exceeded"}); err != nil {
				return
			}
			continue
		}
		lastCommandAt = now
		if cmd.Action == "Get Status" {
			_ = conn.SetWriteDeadline(time.Now().Add(connectionTimeout))
			if err := encoder.Encode(Response{Status: "SUCCESS", Message: "Metrikler alındı", Data: collectMetrics()}); err != nil {
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
				"hmac":        true,
				"modelSha256": modelDigest(),
				"keyFile":     defaultKeyFile(),
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
