package main

import (
	"context"
	"fmt"
	"log"
	"net"
	"os"
	"time"
)

func runBridge(ctx context.Context, service *bridgeService) error {
	logPath := os.Getenv("HWCONTROL_LOG")
	if logPath == "" {
		logPath = "hwcontrol.log"
	}
	if logFile, err := os.OpenFile(logPath, os.O_CREATE|os.O_APPEND|os.O_WRONLY, 0600); err == nil {
		defer logFile.Close()
		log.SetOutput(logFile)
		log.SetFlags(log.LstdFlags | log.LUTC)
	}

	secret, err := loadOrCreateSecret()
	if err != nil {
		return fmt.Errorf("initialize bridge secret: %w", err)
	}

	port := bridgePort()
	listener, err := net.Listen("tcp", "127.0.0.1:"+port)
	if err != nil {
		return fmt.Errorf("listen on 127.0.0.1:%s: %w", port, err)
	}
	defer listener.Close()
	if service != nil {
		service.setListener(listener)
		defer service.stopListener()
	}

	fmt.Println("Bridge Service 2.0 hazır, 127.0.0.1:" + port + " dinleniyor...")

	for {
		if service != nil {
			select {
			case <-service.stopCh:
				log.Printf("graceful shutdown requested")
				return nil
			default:
			}
		}
		select {
		case <-ctx.Done():
			log.Printf("context shutdown requested: %v", ctx.Err())
			return nil
		default:
		}

		_ = listener.(*net.TCPListener).SetDeadline(time.Now().Add(1 * time.Second))
		conn, err := listener.Accept()
		if err != nil {
			if ne, ok := err.(net.Error); ok && ne.Timeout() {
				continue
			}
			if service != nil {
				select {
				case <-service.stopCh:
					return nil
				default:
				}
			}
			return fmt.Errorf("listener stopped: %w", err)
		}
		go handleConnection(conn, secret)
	}
}
