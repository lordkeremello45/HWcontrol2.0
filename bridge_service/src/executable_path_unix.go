//go:build !windows

package main

import "os"

func platformExecutable(name string) string {
	if name == "" {
		return name
	}
	candidates := map[string][]string{
		"lspci":      {"/usr/sbin/lspci", "/usr/bin/lspci", "/sbin/lspci", "/bin/lspci"},
		"nvidia-smi": {"/usr/bin/nvidia-smi", "/usr/local/bin/nvidia-smi"},
		"sysctl":     {"/usr/sbin/sysctl", "/usr/bin/sysctl"},
		"ioreg":      {"/usr/sbin/ioreg"},
	}
	for _, candidate := range candidates[name] {
		if _, err := os.Stat(candidate); err == nil {
			return candidate
		}
	}
	return name
}
