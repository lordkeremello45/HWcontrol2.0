//go:build windows

package main

import (
	"fmt"
	"net"
	"os"
)

func listenBridge() (net.Listener, string, error) {
	// Flutter's dart:io Socket has no Windows named-pipe transport.
	// Keep the existing loopback TCP endpoint on Windows until a native
	// named-pipe client is introduced.
	port := bridgePort()
	listener, err := net.Listen("tcp", "127.0.0.1:"+port)
	if err != nil {
		return nil, "127.0.0.1:" + port, fmt.Errorf("listen on 127.0.0.1:%s: %w", port, err)
	}
	return listener, "127.0.0.1:" + port, nil
}

func cleanupBridgeEndpoint(endpoint string) {
	_ = os.Remove(endpoint)
}

func bridgeEndpoint() string { return "127.0.0.1:" + bridgePort() }
