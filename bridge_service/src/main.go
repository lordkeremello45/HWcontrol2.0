package main

import (
	"encoding/json"
	"fmt"
	"net"
	"os"
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

func handleConnection(conn net.Conn) {
	defer conn.Close()
	decoder := json.NewDecoder(conn)
	encoder := json.NewEncoder(conn)

	for {
		var cmd Command
		if err := decoder.Decode(&cmd); err != nil {
			return // Bağlantı koptu
		}

		fmt.Printf("Komut alındı: %s, Değer: %.2f\n", cmd.Action, cmd.Value)

		// Burada C++ tarafına veya donanım API'sine yönlendirme yapılacak
		// Şimdilik sadece "OK" dönüyoruz
		resp := Response{Status: "SUCCESS", Message: "Komut işlendi"}
		encoder.Encode(resp)
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
