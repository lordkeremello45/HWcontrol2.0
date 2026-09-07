package main

import (
	"strings"
	"testing"
)

func TestValidateCommandAcceptsDiagnostics(t *testing.T) {
	if err := validateCommand(Command{Action: "Get Diagnostics"}); err != nil {
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
		"keyFile",
		"modelState",
		"modelSha256",
		"sensorSource",
		"hardwareControl",
		"localOnly",
		"listenAddress",
		"uptimeSeconds",
	} {
		if _, ok := diagnostics[key]; !ok {
			t.Fatalf("diagnostics key %q missing", key)
		}
	}
	if diagnostics["localOnly"] != true {
		t.Fatalf("diagnostics must report localOnly=true")
	}
	listen, ok := diagnostics["listenAddress"].(string)
	if !ok || !strings.HasPrefix(listen, "127.0.0.1:") {
		t.Fatalf("unexpected listenAddress: %#v", diagnostics["listenAddress"])
	}
}
