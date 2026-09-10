//go:build windows

package main

import (
	"context"
	"fmt"
	"log"
	"os"
	"os/signal"
	"syscall"
	"time"

	"golang.org/x/sys/windows/svc"
)

const serviceShutdownTimeout = 10 * time.Second

func runWindowsService() (bool, error) {
	isService, err := svc.IsWindowsService()
	if err != nil {
		return false, fmt.Errorf("detect Windows service mode: %w", err)
	}
	if !isService {
		return false, nil
	}
	return true, svc.Run("HWControlBridge", serviceHandler{})
}

type serviceHandler struct{}

func (serviceHandler) Execute(_ []string, requests <-chan svc.ChangeRequest, status chan<- svc.Status) (bool, uint32) {
	bridge := newBridgeService()
	status <- svc.Status{State: svc.StartPending, WaitHint: 10_000}

	ready := make(chan error, 1)
	go func() {
		err := runBridge(context.Background(), bridge)
		ready <- err
		close(bridge.stopped)
	}()

	select {
	case err := <-ready:
		if err != nil {
			log.Printf("bridge failed during startup: %v", err)
			status <- svc.Status{State: svc.Stopped, Win32ExitCode: 1}
			return false, 1
		}
		status <- svc.Status{State: svc.Stopped}
		return false, 0
	case <-time.After(10 * time.Second):
		status <- svc.Status{State: svc.Running, Accepts: svc.AcceptStop | svc.AcceptShutdown}
	}

	for {
		select {
		case req, ok := <-requests:
			if !ok {
				return false, 0
			}
			switch req.Cmd {
			case svc.Interrogate:
				status <- svc.Status{State: svc.Running, Accepts: svc.AcceptStop | svc.AcceptShutdown}
			case svc.Stop, svc.Shutdown:
				status <- svc.Status{State: svc.StopPending, WaitHint: uint32(serviceShutdownTimeout / time.Millisecond)}
				bridge.requestStop()
				bridge.stopListener()
				select {
				case <-bridge.stopped:
				case <-time.After(serviceShutdownTimeout):
					log.Printf("graceful shutdown exceeded %s", serviceShutdownTimeout)
				}
				status <- svc.Status{State: svc.Stopped}
				return false, 0
			}
		case err := <-ready:
			if err != nil {
				log.Printf("bridge stopped: %v", err)
				status <- svc.Status{State: svc.Stopped, Win32ExitCode: 1}
				return false, 1
			}
			status <- svc.Status{State: svc.Stopped}
			return false, 0
		}
	}
}

func installConsoleShutdown(bridge *bridgeService) func() {
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	go func() {
		<-ctx.Done()
		bridge.requestStop()
		bridge.stopListener()
	}()
	return stop
}
