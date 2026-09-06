package main

import (
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"math"
	"net"
	"os"
	"strconv"
	"strings"
	"time"
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
}

func validateCommand(cmd Command) error {
	if strings.TrimSpace(cmd.Action) == "" {
		return fmt.Errorf("action is required")
	}
	if math.IsNaN(cmd.Value) || math.IsInf(cmd.Value, 0) || cmd.Value < 0 || cmd.Value > 100 {
		return fmt.Errorf("value must be between 0 and 100")
	}
	switch cmd.Action {
	case "Fan Hızı", "AI İşlem Gücü":
		return nil
	default:
		return fmt.Errorf("unsupported action: %s", cmd.Action)
	}
}

func handleConnection(conn net.Conn, secret string) {
	defer conn.Close()
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

		// Burada C++ tarafına veya donanım API'sine yönlendirme yapılacak
		// Şimdilik sadece "OK" dönüyoruz
		resp := Response{Status: "SUCCESS", Message: "Komut işlendi"}
		if err := encoder.Encode(resp); err != nil {
			return
		}
	}
}

func main() {
	secret := os.Getenv("HWCONTROL_KEY")
	if strings.TrimSpace(secret) == "" {
		fmt.Println("Bridge baslatilamadi: HWCONTROL_KEY ayarlanmamis")
		os.Exit(1)
	}

	// 8080 portunu dinle
	listener, err := net.Listen("tcp", "127.0.0.1:8080")
	if err != nil {
		fmt.Println("Bridge başlatılamadı:", err)
		os.Exit(1)
	}
	defer listener.Close()

	fmt.Println("Bridge Service 2.0 hazır, 127.0.0.1:8080 dinleniyor...")

	for {
		conn, err := listener.Accept()
		if err != nil {
			continue
		}
		go handleConnection(conn, secret) // Her bağlantı için ayrı bir rutin (çoklu işlem)
	}
}
