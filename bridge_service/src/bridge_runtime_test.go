package main

import (
	"context"
	"net"
	"os"
	"path/filepath"
	"testing"
	"time"
)

func TestRunBridgeGracefulShutdown(t *testing.T) {
	tmp := t.TempDir()
	keyPath := filepath.Join(tmp, "bridge.key")
	logPath := filepath.Join(tmp, "bridge.log")

	oldPort, hadPort := os.LookupEnv("HWCONTROL_PORT")
	oldKey, hadKey := os.LookupEnv("HWCONTROL_KEY_FILE")
	oldLog, hadLog := os.LookupEnv("HWCONTROL_LOG")
	t.Cleanup(func() {
		if hadPort { _ = os.Setenv("HWCONTROL_PORT", oldPort) } else { _ = os.Unsetenv("HWCONTROL_PORT") }
		if hadKey { _ = os.Setenv("HWCONTROL_KEY_FILE", oldKey) } else { _ = os.Unsetenv("HWCONTROL_KEY_FILE") }
		if hadLog { _ = os.Setenv("HWCONTROL_LOG", oldLog) } else { _ = os.Unsetenv("HWCONTROL_LOG") }
	})

	probe, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil { t.Fatalf("reserve test port: %v", err) }
	port := probe.Addr().(*net.TCPAddr).Port
	_ = probe.Close()

	_ = os.Setenv("HWCONTROL_PORT", formatTestPort(port))
	_ = os.Setenv("HWCONTROL_KEY_FILE", keyPath)
	_ = os.Setenv("HWCONTROL_LOG", logPath)
	_ = os.Unsetenv("HWCONTROL_KEY")

	bridge := newBridgeService()
	done := make(chan error, 1)
	go func() { done <- runBridge(context.Background(), bridge) }()

	deadline := time.Now().Add(5 * time.Second)
	for time.Now().Before(deadline) {
		conn, err := net.DialTimeout("tcp", "127.0.0.1:"+formatTestPort(port), 100*time.Millisecond)
		if err == nil {
			_ = conn.Close()
			break
		}
		time.Sleep(50 * time.Millisecond)
	}

	bridge.requestStop()
	bridge.stopListener()

	select {
	case err := <-done:
		if err != nil { t.Fatalf("bridge did not shut down cleanly: %v", err) }
	case <-time.After(3 * time.Second):
		t.Fatal("bridge graceful shutdown timed out")
	}
}

func formatTestPort(port int) string {
	return strconv.Itoa(port)
}
