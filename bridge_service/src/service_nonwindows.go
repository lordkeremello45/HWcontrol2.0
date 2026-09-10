//go:build !windows

package main

func runWindowsService() (bool, error) { return false, nil }

func installConsoleShutdown(_ *bridgeService) func() { return func() {} }
