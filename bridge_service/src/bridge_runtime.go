package main

import (
	"context"
	"fmt"
	"log"
	"net"
	"os"
	"path/filepath"
	"runtime"
	"sync"
	"time"
)

type bridgeService struct {
	stopOnce  sync.Once
	stopCh    chan struct{}
	stopped   chan struct{}
	ready     chan struct{}
	readyOnce sync.Once
	mu        sync.RWMutex
	listener  net.Listener
}

func newBridgeService() *bridgeService {
	return &bridgeService{
		stopCh:  make(chan struct{}),
		stopped: make(chan struct{}),
		ready:   make(chan struct{}),
	}
}

func (b *bridgeService) requestStop() {
	b.stopOnce.Do(func() { close(b.stopCh) })
}

func (b *bridgeService) signalReady() {
	if b == nil {
		return
	}
	b.readyOnce.Do(func() { close(b.ready) })
}

func (b *bridgeService) setListener(listener net.Listener) {
	b.mu.Lock()
	b.listener = listener
	b.mu.Unlock()
}

func (b *bridgeService) stopListener() {
	b.mu.Lock()
	listener := b.listener
	b.listener = nil
	b.mu.Unlock()
	if listener != nil {
		_ = listener.Close()
	}
}

const maxConcurrentConnections = 64

func defaultBridgeLogPath() string {
	if runtime.GOOS == "windows" {
		root := os.Getenv("ProgramData")
		if root == "" {
			root = "C:\\ProgramData"
		}
		return filepath.Join(root, "HWControl", "bridge.log")
	}
	return "hwcontrol.log"
}

func runBridge(ctx context.Context, service *bridgeService) error {
	logPath := os.Getenv("HWCONTROL_LOG")
	if logPath == "" {
		logPath = defaultBridgeLogPath()
	}
	if err := os.MkdirAll(filepath.Dir(logPath), 0700); err != nil {
		log.Printf("unable to create bridge log directory: %v", err)
	} else if logFile, err := os.OpenFile(logPath, os.O_CREATE|os.O_APPEND|os.O_WRONLY, 0600); err == nil {
		defer logFile.Close()
		log.SetOutput(redactingWriter{dst: logFile})
		log.SetFlags(log.LstdFlags | log.LUTC)
	} else {
		log.Printf("unable to open bridge log: %v", err)
	}

	log.Printf("bridge startup: loading command key")
	secret, err := loadOrCreateSecret()
	if err != nil {
		startupErr := fmt.Errorf("initialize bridge secret: %w", err)
		log.Printf("%v", startupErr)
		return startupErr
	}

	log.Printf("bridge startup: initializing security canary")
	if err := initializeDecoyService(); err != nil {
		startupErr := fmt.Errorf("initialize fetch-status canary: %w", err)
		log.Printf("%v", startupErr)
		return startupErr
	}

	log.Printf("bridge startup: establishing installation integrity baseline")
	integrityMonitor, err := newBridgeIntegrityMonitor()
	if err != nil {
		startupErr := fmt.Errorf("initialize bridge integrity monitor: %w", err)
		log.Printf("%v", startupErr)
		return startupErr
	}
	if integrityMonitor != nil {
		integrityMonitor.start(ctx.Done(), func(reason error) {
			log.Printf("SECURITY: bridge integrity violation detected: %v; entering fail-closed state", reason)
			if service != nil {
				service.requestStop()
				service.stopListener()
			}
		})
		defer integrityMonitor.stop()
	}

	log.Printf("bridge startup: binding loopback endpoint")
	listener, endpoint, err := listenBridge()
	if err != nil {
		log.Printf("bridge listener startup failed: %v", err)
		return err
	}
	defer listener.Close()
	defer cleanupBridgeEndpoint(endpoint)
	if service != nil {
		service.setListener(listener)
		service.signalReady()
		defer service.stopListener()
	}

	log.Printf("Bridge Service 2.0 ready, %s listening", endpoint)
	connectionSlots := make(chan struct{}, maxConcurrentConnections)

	for {
		checkDecoyIntegrity()
		if panicModeActive() {
			recordSecurityDiagnostic("panic-mode-active", "fetch-status canary requested fail-closed mode")
			if service != nil {
				service.requestStop()
				service.stopListener()
			}
			return fmt.Errorf("security panic mode active")
		}
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

		if deadlineListener, ok := listener.(interface{ SetDeadline(time.Time) error }); ok {
			_ = deadlineListener.SetDeadline(time.Now().Add(1 * time.Second))
		}
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
		select {
		case connectionSlots <- struct{}{}:
			go func() {
				defer func() { <-connectionSlots }()
				handleConnection(conn, secret)
			}()
		default:
			_ = conn.SetWriteDeadline(time.Now().Add(2 * time.Second))
			_, _ = conn.Write([]byte("{\"status\":\"ERROR\",\"message\":\"too many concurrent connections\"}\\n"))
			_ = conn.Close()
		}
	}
}
