//go:build windows

package main

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"
)

const (
	csharpHardwareIdentityMaxOutput = 1 << 20
	csharpHardwareIdentityTimeout  = 5 * time.Second
)

type csharpHardwareInventory struct {
	SchemaVersion      int             `json:"schemaVersion"`
	Platform           string          `json:"platform"`
	Status             string          `json:"status"`
	SystemManufacturer string          `json:"systemManufacturer"`
	SystemModel        string          `json:"systemModel"`
	SystemFamily       string          `json:"systemFamily"`
	BiosVendor         string          `json:"biosVendor"`
	BiosVersion        string          `json:"biosVersion"`
	MotherboardVendor  string          `json:"motherboardVendor"`
	MotherboardModel   string          `json:"motherboardModel"`
	MotherboardVersion string          `json:"motherboardVersion"`
	Cpus               []csharpCPU     `json:"cpus"`
	Gpus               []csharpGPU     `json:"gpus"`
	Warnings           []string        `json:"warnings"`
}

type csharpCPU struct {
	Manufacturer      string `json:"manufacturer"`
	Model             string `json:"model"`
	PhysicalCores     *int   `json:"physicalCores"`
	LogicalProcessors *int   `json:"logicalProcessors"`
}

type csharpGPU struct {
	Manufacturer   string `json:"manufacturer"`
	Model          string `json:"model"`
	DriverProvider string `json:"driverProvider"`
	DriverVersion  string `json:"driverVersion"`
}

func collectHardwareIdentity() HardwareIdentity {
	if identity, ok := collectHardwareIdentityWithCSharp(); ok {
		return identity
	}
	return collectHardwareIdentityWithPowerShell()
}

func collectHardwareIdentityWithCSharp() (HardwareIdentity, bool) {
	id := emptyHardwareIdentity()
	executable, err := os.Executable()
	if err != nil {
		return id, false
	}
	helper := filepath.Join(filepath.Dir(executable), "hwcontrol-hardware-identification.exe")
	info, err := os.Stat(helper)
	if err != nil || !info.Mode().IsRegular() {
		return id, false
	}

	ctx, cancel := context.WithTimeout(context.Background(), csharpHardwareIdentityTimeout)
	defer cancel()

	cmd := exec.CommandContext(ctx, helper)
	var stdout limitedHardwareOutput
	stdout.limit = csharpHardwareIdentityMaxOutput
	cmd.Stdout = &stdout
	if err := cmd.Run(); err != nil || ctx.Err() != nil || stdout.overflow {
		return id, false
	}

	inventory, err := parseCSharpHardwareInventory(stdout.Bytes())
	if err != nil || inventory.Status == "unavailable" {
		return id, false
	}

	id.DetectionSource = "Windows C# WMI collector"
	id.SystemManufacturer = safeHardwareText(inventory.SystemManufacturer)
	id.SystemModel = safeHardwareText(inventory.SystemModel)
	id.SystemVersion = safeHardwareText(inventory.SystemFamily)
	id.BIOSVendor = safeHardwareText(inventory.BiosVendor)
	id.BIOSVersion = safeHardwareText(inventory.BiosVersion)
	id.MotherboardVendor = safeHardwareText(inventory.MotherboardVendor)
	id.MotherboardModel = safeHardwareText(inventory.MotherboardModel)
	id.MotherboardVersion = safeHardwareText(inventory.MotherboardVersion)

	if len(inventory.Cpus) > 0 {
		cpu := inventory.Cpus[0]
		id.CPUManufacturer = safeHardwareText(cpu.Manufacturer)
		id.CPUModel = safeHardwareText(cpu.Model)
		if cpu.PhysicalCores != nil && *cpu.PhysicalCores >= 0 && *cpu.PhysicalCores <= 1024 {
			id.CPUPhysicalCores = *cpu.PhysicalCores
		}
		if cpu.LogicalProcessors != nil && *cpu.LogicalProcessors >= 0 && *cpu.LogicalProcessors <= 4096 {
			id.CPUThreads = *cpu.LogicalProcessors
		}
	}
	if len(inventory.Gpus) > 0 {
		gpu := inventory.Gpus[0]
		id.GPUVendor = safeHardwareText(gpu.Manufacturer)
		id.GPUModel = safeHardwareText(gpu.Model)
		id.GPUDriver = safeHardwareText(gpu.DriverProvider)
		id.GPUDriverVersion = safeHardwareText(gpu.DriverVersion)
	}

	if inventory.Status == "ok" && hasUsefulHardwareIdentity(id) {
		id.DetectionStatus = "ok"
	} else {
		id.DetectionStatus = "partial"
	}
	return id, true
}

func parseCSharpHardwareInventory(output []byte) (csharpHardwareInventory, error) {
	var inventory csharpHardwareInventory
	if len(output) == 0 || len(output) > csharpHardwareIdentityMaxOutput {
		return inventory, errors.New("invalid hardware identity output size")
	}
	decoder := json.NewDecoder(bytes.NewReader(output))
	if err := decoder.Decode(&inventory); err != nil {
		return inventory, err
	}
	var extra any
	if err := decoder.Decode(&extra); err != io.EOF {
		return inventory, errors.New("trailing data after hardware identity JSON")
	}
	if inventory.SchemaVersion != 1 || inventory.Platform != "windows" {
		return inventory, errors.New("unsupported hardware identity schema or platform")
	}
	if inventory.Status != "ok" && inventory.Status != "partial" && inventory.Status != "unavailable" {
		return inventory, errors.New("invalid hardware identity status")
	}
	if len(inventory.Cpus) > 64 || len(inventory.Gpus) > 128 || len(inventory.Warnings) > 128 {
		return inventory, errors.New("hardware identity collection exceeds limits")
	}
	for _, cpu := range inventory.Cpus {
		if cpu.PhysicalCores != nil && (*cpu.PhysicalCores < 0 || *cpu.PhysicalCores > 1024) {
			return inventory, errors.New("invalid physical core count")
		}
		if cpu.LogicalProcessors != nil && (*cpu.LogicalProcessors < 0 || *cpu.LogicalProcessors > 4096) {
			return inventory, errors.New("invalid logical processor count")
		}
	}
	return inventory, nil
}

type limitedHardwareOutput struct {
	bytes.Buffer
	limit    int
	overflow bool
}

func (b *limitedHardwareOutput) Write(p []byte) (int, error) {
	n := len(p)
	remaining := b.limit - b.Len()
	if remaining <= 0 {
		b.overflow = true
		return n, nil
	}
	if len(p) > remaining {
		b.overflow = true
		p = p[:remaining]
	}
	_, _ = b.Buffer.Write(p)
	return n, nil
}

func safeHardwareText(value string) string {
	value = strings.TrimSpace(value)
	if len(value) > 512 {
		value = value[:512]
	}
	return strings.Map(func(r rune) rune {
		if r < 0x20 && r != '\t' {
			return -1
		}
		return r
	}, value)
}

func hasUsefulHardwareIdentity(id HardwareIdentity) bool {
	return id.SystemModel != "" || id.MotherboardModel != "" || id.CPUModel != "" || id.GPUModel != ""
}
