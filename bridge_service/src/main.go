package main

import (
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
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
	"time"

	"github.com/shirou/gopsutil/v3/cpu"
	"github.com/shirou/gopsutil/v3/disk"
	"github.com/shirou/gopsutil/v3/host"
	"github.com/shirou/gopsutil/v3/load"
	"github.com/shirou/gopsutil/v3/mem"
)

// UI'dan (Dart) gelen komut yapısı
type Command struct {
	Action string  `json:"action"`
	Value  float64 `json:"value"`
	Auth   string  `json:"auth"`
}

func commandPayload(cmd Command) string {
	return cmd.Action + "\n" + strconv.FormatFloat(cmd.Value, 'f', 6, 64)
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

// AI Engine'e veya Sürücüye gönderilecek cevap yapısı
type Response struct {
	Status  string `json:"status"`
	Message string `json:"message"`
	Data    any    `json:"data,omitempty"`
}

type HardwareMetrics struct {
	CPUUsage       float64 `json:"cpuUsage"`
	CPUTemperature float64 `json:"cpuTemperature"`
	GPUTemperature float64 `json:"gpuTemperature"`
	GPUUsage       float64 `json:"gpuUsage"`
	FanRPM         float64 `json:"fanRpm"`
	MemoryUsage    float64 `json:"memoryUsage"`
	DiskUsage      float64 `json:"diskUsage"`
	PowerWatts     float64 `json:"powerWatts"`
	Voltage        float64 `json:"voltage"`
	UptimeSeconds  uint64  `json:"uptimeSeconds"`
	Platform       string  `json:"platform"`
}

func collectMetrics() HardwareMetrics {
	metrics := HardwareMetrics{}
	if percentages, err := cpu.Percent(time.Second, false); err == nil && len(percentages) > 0 {
		metrics.CPUUsage = percentages[0]
	}
	if memory, err := mem.VirtualMemory(); err == nil {
		metrics.MemoryUsage = memory.UsedPercent
	}
	if usage, err := disk.Usage("/"); err == nil {
		metrics.DiskUsage = usage.UsedPercent
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
	if output, err := exec.Command("nvidia-smi", "--query-gpu=temperature.gpu,utilization.gpu,fan.speed,power.draw", "--format=csv,noheader,nounits").Output(); err == nil {
		parts := strings.Split(strings.TrimSpace(string(output)), ",")
		if len(parts) >= 4 {
			metrics.GPUTemperature, _ = strconv.ParseFloat(strings.TrimSpace(parts[0]), 64)
			metrics.GPUUsage, _ = strconv.ParseFloat(strings.TrimSpace(parts[1]), 64)
			fanPercent, _ := strconv.ParseFloat(strings.TrimSpace(parts[2]), 64)
			metrics.FanRPM = fanPercent
			metrics.PowerWatts, _ = strconv.ParseFloat(strings.TrimSpace(parts[3]), 64)
		}
	}
	if _, err := load.Avg(); err == nil {
		// load.Avg is intentionally queried to validate host metric access.
	}
	metrics.Platform = runtime.GOOS
	return metrics
}

func modelDigest() string {
	modelPath := os.Getenv("HWCONTROL_MODEL")
	if modelPath == "" {
		modelPath = filepath.Join("ai_core", "models", "gemma-2b-it-q4_k_m.gguf")
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
	switch cmd.Action {
	case "Fan Hızı", "AI İşlem Gücü", "Get Status", "Get Security":
		return nil
	default:
		return fmt.Errorf("unsupported action: %s", cmd.Action)
	}
}

func handleConnection(conn net.Conn, secret string) {
	defer conn.Close()
	defer func() {
		if recovered := recover(); recovered != nil {
			log.Printf("connection panic recovered: %v", recovered)
		}
	}()
	decoder := json.NewDecoder(conn)
	encoder := json.NewEncoder(conn)

	for {
		_ = conn.SetReadDeadline(time.Now().Add(30 * time.Second))
		var cmd Command
		if err := decoder.Decode(&cmd); err != nil {
			return // Bağlantı koptu
		}

		if err := validateCommand(cmd); err != nil {
			_ = encoder.Encode(Response{Status: "ERROR", Message: err.Error()})
			continue
		}
		if !authenticateCommand(cmd, secret) {
			_ = encoder.Encode(Response{Status: "ERROR", Message: "authentication failed"})
			continue
		}

		fmt.Printf("Komut alındı: %s, Değer: %.2f\n", cmd.Action, cmd.Value)
		if cmd.Action == "Get Status" {
			if err := encoder.Encode(Response{Status: "SUCCESS", Message: "Metrikler alındı", Data: collectMetrics()}); err != nil {
				return
			}
			continue
		}
		if cmd.Action == "Get Security" {
			if err := encoder.Encode(Response{Status: "SUCCESS", Message: "Güvenlik durumu alındı", Data: map[string]any{
				"hmac":        true,
				"modelSha256": modelDigest(),
			}}); err != nil {
				return
			}
			continue
		}

		// Burada C++ tarafına veya donanım API'sine yönlendirme yapılacak
		// Şimdilik sadece "OK" dönüyoruz
		resp := Response{Status: "SUCCESS", Message: "Komut işlendi"}
		if err := encoder.Encode(resp); err != nil {
			return
		}
	}
}

func main() {
	logPath := os.Getenv("HWCONTROL_LOG")
	if logPath == "" {
		logPath = "hwcontrol.log"
	}
	if logFile, err := os.OpenFile(logPath, os.O_CREATE|os.O_APPEND|os.O_WRONLY, 0600); err == nil {
		defer logFile.Close()
		log.SetOutput(logFile)
		log.SetFlags(log.LstdFlags | log.LUTC)
	} else {
		fmt.Println("Log dosyasi acilamadi:", err)
	}

	secret := os.Getenv("HWCONTROL_KEY")
	if strings.TrimSpace(secret) == "" {
		fmt.Println("Bridge baslatilamadi: HWCONTROL_KEY ayarlanmamis")
		os.Exit(1)
	}

	port := os.Getenv("HWCONTROL_PORT")
	if port == "" {
		port = "8080"
	}
	listener, err := net.Listen("tcp", "127.0.0.1:"+port)
	if err != nil {
		fmt.Println("Bridge başlatılamadı:", err)
		os.Exit(1)
	}
	defer listener.Close()

	fmt.Println("Bridge Service 2.0 hazır, 127.0.0.1:" + port + " dinleniyor...")

	for {
		conn, err := listener.Accept()
		if err != nil {
			continue
		}
		go handleConnection(conn, secret) // Her bağlantı için ayrı bir rutin (çoklu işlem)
	}
}
