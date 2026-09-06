package main

import (
	"encoding/json"
	"fmt"
	"math"
	"net"
	"os"
	"strings"
	"time"
)

// UI'dan (Dart) gelen komut yapısı
type Command struct {
	Action string  `json:"action"`
	Value  float64 `json:"value"`
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

func handleConnection(conn net.Conn) {
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
		go handleConnection(conn) // Her bağlantı için ayrı bir rutin (çoklu işlem)
	}
}
