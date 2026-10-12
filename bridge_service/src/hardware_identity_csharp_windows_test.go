//go:build windows

package main

import (
	"bytes"
	"strings"
	"testing"
)

func TestParseCSharpHardwareInventory(t *testing.T) {
	input := `{"schemaVersion":1,"platform":"windows","status":"ok","systemModel":"Example PC","cpus":[{"manufacturer":"GenuineIntel","model":"Intel Core i7","physicalCores":8,"logicalProcessors":16}],"gpus":[{"manufacturer":"NVIDIA","model":"GeForce RTX"}],"warnings":[]}`
	inventory, err := parseCSharpHardwareInventory([]byte(input))
	if err != nil {
		t.Fatalf("valid inventory rejected: %v", err)
	}
	if inventory.SystemModel != "Example PC" || len(inventory.Cpus) != 1 || len(inventory.Gpus) != 1 {
		t.Fatalf("unexpected parsed inventory: %+v", inventory)
	}
}

func TestParseCSharpHardwareInventoryRejectsInvalidInput(t *testing.T) {
	oversizedModel := `{"schemaVersion":1,"platform":"windows","status":"partial","systemModel":"` + strings.Repeat("x", 513) + `"}`
	tests := []struct {
		name  string
		input string
	}{
		{name: "wrong schema", input: `{"schemaVersion":2,"platform":"windows","status":"ok"}`},
		{name: "wrong platform", input: `{"schemaVersion":1,"platform":"linux","status":"ok"}`},
		{name: "invalid status", input: `{"schemaVersion":1,"platform":"windows","status":"unknown"}`},
		{name: "negative core count", input: `{"schemaVersion":1,"platform":"windows","status":"ok","cpus":[{"physicalCores":-1}]}`},
		{name: "trailing value", input: `{"schemaVersion":1,"platform":"windows","status":"ok"} {}`},
		{name: "malformed JSON", input: `{"schemaVersion":`},
		{name: "unknown field", input: `{"schemaVersion":1,"platform":"windows","status":"ok","unexpectedSecret":"x"}`},
		{name: "oversized model", input: oversizedModel},
		{name: "physical cores exceed logical", input: `{"schemaVersion":1,"platform":"windows","status":"ok","cpus":[{"physicalCores":16,"logicalProcessors":8}]}`},
		{name: "invalid PCI token", input: `{"schemaVersion":1,"platform":"windows","status":"partial","gpus":[{"pciDeviceId":"VEN_BAD&DEV_1234"}]}`},
	}
	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			if _, err := parseCSharpHardwareInventory([]byte(test.input)); err == nil {
				t.Fatal("invalid inventory was accepted")
			}
		})
	}
	if _, err := parseCSharpHardwareInventory([]byte(strings.Repeat("x", csharpHardwareIdentityMaxOutput+1))); err == nil {
		t.Fatal("oversized output was accepted")
	}
}

func TestLimitedHardwareOutput(t *testing.T) {
	var output limitedHardwareOutput
	output.limit = 4
	n, err := output.Write([]byte("abcdef"))
	if err != nil || n != 6 {
		t.Fatalf("unexpected writer result: n=%d err=%v", n, err)
	}
	if !output.overflow || !bytes.Equal(output.Bytes(), []byte("abcd")) {
		t.Fatalf("output was not bounded: overflow=%v output=%q", output.overflow, output.Bytes())
	}
}
