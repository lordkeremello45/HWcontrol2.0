//go:build windows

package main

import (
	"fmt"
	"log"
	"os"
	"path/filepath"
	"time"

	"golang.org/x/sys/windows/svc"
)

func configureGuardianLog() func() {
	root := os.Getenv("ProgramData")
	if root == "" {
		root = "C:\\ProgramData"
	}
	path := filepath.Join(root, "HWControl", "security", "state", "guardian.log")
	if err := os.MkdirAll(filepath.Dir(path), 0700); err != nil {
		return func() {}
	}
	file, err := os.OpenFile(path, os.O_CREATE|os.O_APPEND|os.O_WRONLY, 0600)
	if err != nil {
		return func() {}
	}
	log.SetOutput(file)
	log.SetFlags(log.LstdFlags | log.LUTC)
	return func() { _ = file.Close() }
}

func runWindowsService() (bool, error) {
	isService, err := svc.IsWindowsService()
	if err != nil {
		return false, fmt.Errorf("detect security guardian service mode: %w", err)
	}
	if !isService {
		return false, nil
	}
	closeLog := configureGuardianLog()
	defer closeLog()
	return true, svc.Run("HWControlSecurityGuardian", guardianServiceHandler{})
}

type guardianServiceHandler struct{}

func (guardianServiceHandler) Execute(_ []string, requests <-chan svc.ChangeRequest, status chan<- svc.Status) (bool, uint32) {
	status <- svc.Status{State: svc.StartPending, WaitHint: 10_000, CheckPoint: 1}
	baseline, err := initializeGuardian()
	if err != nil {
		log.Printf("security guardian startup failed: %v", err)
		status <- svc.Status{State: svc.Stopped, Win32ExitCode: 1}
		return false, 1
	}

	ticker := time.NewTicker(2 * time.Second)
	defer ticker.Stop()
	status <- svc.Status{State: svc.Running, Accepts: svc.AcceptStop | svc.AcceptShutdown}

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
				status <- svc.Status{State: svc.StopPending, WaitHint: 10_000, CheckPoint: 1}
				status <- svc.Status{State: svc.Stopped}
				return false, 0
			}
		case <-ticker.C:
			if err := checkGuardianCanary(baseline); err != nil {
				log.Printf("security guardian integrity failure: %v", err)
				status <- svc.Status{State: svc.Stopped, Win32ExitCode: 1}
				return false, 1
			}
		}
	}
}
