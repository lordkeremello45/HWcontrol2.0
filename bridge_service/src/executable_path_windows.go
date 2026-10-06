//go:build windows

package main

import (
	"os"
	"path/filepath"
)

func platformExecutable(name string) string {
	if filepath.IsAbs(name) {
		return name
	}
	root := os.Getenv("SystemRoot")
	if root == "" {
		root = "C:\\Windows"
	}
	switch name {
	case "powershell.exe":
		return filepath.Join(root, "System32", "WindowsPowerShell", "v1.0", "powershell.exe")
	case "nvidia-smi.exe", "nvidia-smi":
		return filepath.Join(root, "System32", "nvidia-smi.exe")
	default:
		return name
	}
}
