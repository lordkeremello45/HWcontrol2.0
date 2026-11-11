package main

import (
	"os"
	"path/filepath"
	"strings"
)

// hardwareToolEnvironmentFrom creates a small environment for OS/vendor
// inspection tools. Service credentials and application-private variables
// are intentionally not inherited by external processes.
func hardwareToolEnvironmentFrom(environment []string) []string {
	allowed := map[string]bool{
		"PATH": true, "SYSTEMROOT": true, "WINDIR": true, "SYSTEMDRIVE": true,
		"PROGRAMFILES": true, "PROGRAMDATA": true, "TMP": true, "TEMP": true, "TMPDIR": true,
	}
	values := make(map[string]string, len(allowed))
	for _, entry := range environment {
		key, value, ok := strings.Cut(entry, "=")
		if !ok {
			continue
		}
		key = strings.ToUpper(key)
		if allowed[key] && value != "" {
			if _, exists := values[key]; !exists {
				values[key] = value
			}
		}
	}
	root := values["SYSTEMROOT"]
	if root == "" {
		root = values["WINDIR"]
	}
	if root != "" {
		values["SYSTEMROOT"], values["WINDIR"] = root, root
	}
	result := make([]string, 0, len(values)+4)
	for _, key := range []string{
		"PATH", "SYSTEMROOT", "WINDIR", "SYSTEMDRIVE",
		"PROGRAMFILES", "PROGRAMDATA", "TMP", "TEMP", "TMPDIR",
	} {
		if value, ok := values[key]; ok {
			result = append(result, key+"="+value)
		}
	}
	if root != "" {
		modulePaths := []string{
			filepath.Join(root, "System32", "WindowsPowerShell", "v1.0", "Modules"),
		}
		if programFiles := values["PROGRAMFILES"]; programFiles != "" {
			modulePaths = append(modulePaths, filepath.Join(programFiles, "WindowsPowerShell", "Modules"))
		}
		result = append(result, "PSModulePath="+strings.Join(modulePaths, string(os.PathListSeparator)))
	}
	return append(result, "LANG=C", "LC_ALL=C")
}

func hardwareToolEnvironment() []string {
	return hardwareToolEnvironmentFrom(os.Environ())
}
