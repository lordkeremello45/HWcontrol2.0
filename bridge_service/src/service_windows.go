//go:build windows

package main

import (
	"context"
	"fmt"
	"log"
	"os"
	"os/signal"
	"time"

	"golang.org/x/sys/windows/svc"
)

const serviceShutdownTimeout = 10 * time.Second
const serviceStartupWaitHint = 30_000

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
	status <- svc.Status{State: svc.StartPending, WaitHint: serviceStartupWaitHint, CheckPoint: 1}

	done := make(chan error, 1)
	go func() {
		err := runBridge(context.Background(), bridge)
		done <- err
		close(bridge.stopped)
	}()

	startupTicker := time.NewTicker(5 * time.Second)
	defer startupTicker.Stop()
	checkpoint := uint32(1)

	stopService := func() {
		status <- svc.Status{State: svc.StopPending, WaitHint: uint32(serviceShutdownTimeout / time.Millisecond), CheckPoint: 1}
		bridge.requestStop()
		bridge.stopListener()
		select {
		case err := <-done:
			if err != nil {
				log.Printf("bridge stopped during shutdown: %v", err)
			}
		case <-time.After(serviceShutdownTimeout):
			log.Printf("graceful shutdown exceeded %s", serviceShutdownTimeout)
		}
		status <- svc.Status{State: svc.Stopped}
	}

	for {
		select {
		case <-bridge.ready:
			status <- svc.Status{State: svc.Running, Accepts: svc.AcceptStop | svc.AcceptShutdown}
			goto running
		case err := <-done:
			if err != nil {
				log.Printf("bridge failed before becoming ready: %v", err)
				status <- svc.Status{State: svc.Stopped, Win32ExitCode: 1}
				return false, 1
			}
			status <- svc.Status{State: svc.Stopped}
			return false, 0
		case req, ok := <-requests:
			if !ok {
				status <- svc.Status{State: svc.Stopped}
				return false, 0
			}
			switch req.Cmd {
			case svc.Interrogate:
				status <- svc.Status{State: svc.StartPending, WaitHint: serviceStartupWaitHint, CheckPoint: checkpoint}
			case svc.Stop, svc.Shutdown:
				stopService()
				return false, 0
			}
		case <-startupTicker.C:
			checkpoint++
			status <- svc.Status{State: svc.StartPending, WaitHint: serviceStartupWaitHint, CheckPoint: checkpoint}
		}
	}

running:
	for {
		select {
		case req, ok := <-requests:
			if !ok {
				status <- svc.Status{State: svc.Stopped}
				return false, 0
			}
			switch req.Cmd {
			case svc.Interrogate:
				status <- svc.Status{State: svc.Running, Accepts: svc.AcceptStop | svc.AcceptShutdown}
			case svc.Stop, svc.Shutdown:
				stopService()
				return false, 0
			}
		case err := <-done:
			if err != nil {
				log.Printf("bridge service stopped unexpectedly: %v", err)
				status <- svc.Status{State: svc.Stopped, Win32ExitCode: 1}
				return false, 1
			}
			status <- svc.Status{State: svc.Stopped}
			return false, 0
		}
	}
}

func installConsoleShutdown(bridge *bridgeService) func() {
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt)
	go func() {
		<-ctx.Done()
		bridge.requestStop()
		bridge.stopListener()
	}()
	return stop
}
