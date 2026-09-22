//go:build !windows

package main

import (
    "net"
    "os"
    "path/filepath"
    "testing"
)

func TestListenBridgeUnixSocket(t *testing.T) {
    socketPath := filepath.Join(t.TempDir(), "bridge.sock")
    t.Setenv("HWCONTROL_SOCKET", socketPath)
    t.Setenv("HWCONTROL_TCP_COMPAT", "")
    
    listener, endpoint, err := listenBridge()
    if err != nil {
        t.Fatalf("listenBridge: %v", err)
    }
    if endpoint != socketPath {
        t.Fatalf("endpoint = %q, want %q", endpoint, socketPath)
    }
    if listener == nil {
        t.Fatal("listener is nil")
    }
    info, err := os.Stat(socketPath)
    if err != nil {
        t.Fatalf("stat socket: %v", err)
    }
    if info.Mode().Perm() != 0660 {
        t.Fatalf("socket mode = %o, want 660", info.Mode().Perm())
    }
    if _, ok := listener.Addr().(*net.UnixAddr); !ok {
        t.Fatalf("listener address type = %T, want *net.UnixAddr", listener.Addr())
    }
    _ = listener.Close()
    cleanupBridgeEndpoint(endpoint)
    if _, err := os.Stat(socketPath); !os.IsNotExist(err) {
        t.Fatalf("socket still exists after cleanup: %v", err)
    }
}
