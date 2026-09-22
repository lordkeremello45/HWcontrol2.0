//go:build !windows

package main

import (
	"fmt"
	"net"
	"os"
	"path/filepath"
	"syscall"
)

const defaultBridgeSocket = "/var/lib/hwcontrol/bridge.sock"

func bridgeSocketPath() string {
	if configured := os.Getenv("HWCONTROL_SOCKET"); configured != "" {
		return configured
	}
	return defaultBridgeSocket
}

func listenBridge() (net.Listener, string, error) {
	if os.Getenv("HWCONTROL_TCP_COMPAT") == "1" {
		port := bridgePort()
		listener, err := net.Listen("tcp", "127.0.0.1:"+port)
		if err != nil {
			return nil, "127.0.0.1:" + port, fmt.Errorf("listen on compatibility TCP endpoint: %w", err)
		}
		return listener, "127.0.0.1:" + port, nil
	}

	path := bridgeSocketPath()
	if err := os.MkdirAll(filepath.Dir(path), 0750); err != nil {
		return nil, path, fmt.Errorf("create bridge socket directory: %w", err)
	}
	if info, err := os.Lstat(path); err == nil {
		if info.Mode()&os.ModeSymlink != 0 {
			return nil, path, fmt.Errorf("bridge socket must not be a symlink")
		}
		if info.Mode()&os.ModeSocket == 0 {
			return nil, path, fmt.Errorf("refusing to replace non-socket endpoint %s", path)
		}
		if err := os.Remove(path); err != nil {
			return nil, path, fmt.Errorf("remove stale bridge socket: %w", err)
		}
	} else if !os.IsNotExist(err) {
		return nil, path, fmt.Errorf("inspect bridge socket: %w", err)
	}

	listener, err := net.Listen("unix", path)
	if err != nil {
		return nil, path, fmt.Errorf("listen on unix socket %s: %w", path, err)
	}
	// Installed Unix services normally run as root while the GUI runs as the
	// installing desktop user. Bind the socket to the parent directory owner
	// and keep it private to that user/root.
	if info, err := os.Stat(filepath.Dir(path)); err == nil {
		if stat, ok := info.Sys().(*syscall.Stat_t); ok {
			if err := os.Chown(path, int(stat.Uid), int(stat.Gid)); err != nil {
				_ = listener.Close()
				_ = os.Remove(path)
				return nil, path, fmt.Errorf("set bridge socket ownership: %w", err)
			}
		}
	}
	if err := os.Chmod(path, 0600); err != nil {
		_ = listener.Close()
		_ = os.Remove(path)
		return nil, path, fmt.Errorf("protect bridge socket: %w", err)
	}
	return listener, path, nil
}

func cleanupBridgeEndpoint(endpoint string) {
	if os.Getenv("HWCONTROL_TCP_COMPAT") == "1" {
		return
	}
	_ = os.Remove(endpoint)
}

func bridgeEndpoint() string {
	if os.Getenv("HWCONTROL_TCP_COMPAT") == "1" {
		return "127.0.0.1:" + bridgePort()
	}
	return bridgeSocketPath()
}
