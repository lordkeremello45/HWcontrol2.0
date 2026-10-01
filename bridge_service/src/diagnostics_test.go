package main

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestValidateCommandAcceptsDiagnostics(t *testing.T) {
	if err := validateCommand(testCommand("Get Diagnostics", 0)); err != nil {
		t.Fatalf("Get Diagnostics rejected: %v", err)
	}
}

func TestDiagnosticsSnapshotContract(t *testing.T) {
	diagnostics := diagnosticsSnapshot()
	for _, key := range []string{
		"bridgeVersion",
		"platform",
		"architecture",
		"goVersion",
		"keyFileConfigured",
		"modelState",
		"modelSha256",
		"sensorSource",
		"hardwareControl",
		"thermalSafetyAvailable",
		"localOnly",
		"listenAddress",
		"uptimeSeconds",
		"healthStatus",
		"safetyState",
		"recoveryAction",
		"hardwareCapabilities",
		"hardwareAnomalies",
	} {
		if _, ok := diagnostics[key]; !ok {
			t.Fatalf("diagnostics key %q missing", key)
		}
	}
	if diagnostics["localOnly"] != true {
		t.Fatalf("diagnostics must report localOnly=true")
	}
	listen, ok := diagnostics["listenAddress"].(string)
	if !ok || (!strings.HasPrefix(listen, "127.0.0.1:") && !strings.HasSuffix(listen, ".sock")) {
		t.Fatalf("unexpected listenAddress: %#v", diagnostics["listenAddress"])
	}
}


func TestAppendCrashRecordPersistsRedactedLocalEvent(t *testing.T) {
	path := filepath.Join(t.TempDir(), "events.jsonl")
	if err := appendCrashRecord(path, "line1\nline2"); err != nil {
		t.Fatal(err)
	}
	data, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	if strings.Contains(string(data), "\nline2") {
		t.Fatal("diagnostic record contains an unsanitized newline")
	}
	if !strings.Contains(string(data), "line1 line2") {
		t.Fatalf("sanitized diagnostic record missing: %s", data)
	}
}
