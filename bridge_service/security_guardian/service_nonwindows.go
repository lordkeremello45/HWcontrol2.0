//go:build !windows

package main

func runWindowsService() (bool, error) {
	return false, nil
}
