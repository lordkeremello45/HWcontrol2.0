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
	csharpHardwareIdentityTimeout   = 5 * time.Second
)

type csharpHardwareInventory struct {
	Collector          string      `json:"collector"`
	SchemaVersion      int         `json:"schemaVersion"`
	Platform           string      `json:"platform"`
	Status             string      `json:"status"`
	SystemManufacturer string      `json:"systemManufacturer"`
	SystemModel        string      `json:"systemModel"`
	SystemFamily       string      `json:"systemFamily"`
	BiosVendor         string      `json:"biosVendor"`
	BiosVersion        string      `json:"biosVersion"`
	MotherboardVendor  string      `json:"motherboardVendor"`
	MotherboardModel   string      `json:"motherboardModel"`
	MotherboardVersion string      `json:"motherboardVersion"`
	Cpus               []csharpCPU `json:"cpus"`
	Gpus               []csharpGPU `json:"gpus"`
	Warnings           []string    `json:"warnings"`
}

type csharpCPU struct {
	Manufacturer      string `json:"manufacturer"`
	Model             string `json:"model"`
	Architecture      string `json:"architecture"`
	VendorFamily      string `json:"vendorFamily"`
	PhysicalCores     *int   `json:"physicalCores"`
	LogicalProcessors *int   `json:"logicalProcessors"`
}

type csharpGPU struct {
	Manufacturer   string `json:"manufacturer"`
	Model          string `json:"model"`
	PciDeviceID    string `json:"pciDeviceId"`
	VendorFamily   string `json:"vendorFamily"`
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
		// WMI commonly reports integrated graphics before a discrete adapter.
		// Choose the most informative vendor/model for the legacy single-GPU
		// summary while retaining the complete inventory for future multi-GPU UI.
		gpu := preferredCSharpGPU(inventory.Gpus)
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

func preferredCSharpGPU(gpus []csharpGPU) csharpGPU {
	if len(gpus) == 0 {
		return csharpGPU{}
	}
	best := gpus[0]
	bestScore := csharpGPUPreferenceScore(best)
	for _, gpu := range gpus[1:] {
		score := csharpGPUPreferenceScore(gpu)
		if score > bestScore {
			best, bestScore = gpu, score
		}
	}
	return best
}

func csharpGPUPreferenceScore(gpu csharpGPU) int {
	vendor := strings.ToLower(strings.TrimSpace(gpu.Manufacturer + " " + gpu.VendorFamily))
	model := strings.ToLower(strings.TrimSpace(gpu.Model))
	score := 0
	switch {
	case strings.Contains(vendor, "nvidia") || strings.Contains(model, "geforce") || strings.Contains(model, "quadro"):
		score = 40
	case strings.Contains(vendor, "amd") || strings.Contains(vendor, "ati") ||
		strings.Contains(model, "radeon") || strings.Contains(model, "firepro"):
		score = 30
	case strings.Contains(vendor, "intel") || strings.Contains(model, "intel"):
		score = 20
	default:
		score = 10
	}
	if strings.Contains(model, "microsoft basic display") || strings.Contains(model, "remote display") {
		score -= 20
	}
	if strings.TrimSpace(gpu.DriverProvider) != "" {
		score++
	}
	if strings.TrimSpace(gpu.DriverVersion) != "" {
		score++
	}
	return score
}

func parseCSharpHardwareInventory(output []byte) (csharpHardwareInventory, error) {
	var inventory csharpHardwareInventory
	if len(output) == 0 || len(output) > csharpHardwareIdentityMaxOutput {
		return inventory, errors.New("invalid hardware identity output size")
	}
	decoder := json.NewDecoder(bytes.NewReader(output))
	decoder.DisallowUnknownFields()
	if err := decoder.Decode(&inventory); err != nil {
		return inventory, err
	}
	var extra any
	if err := decoder.Decode(&extra); err != io.EOF {
		return inventory, errors.New("trailing data after hardware identity JSON")
	}
	if err := validateHardwareIdentityPolicy(inventory); err != nil {
		return inventory, err
	}
	return inventory, nil
}

// validateHardwareIdentityPolicy is the Go-side runtime enforcement of the
// fail-closed hardware-identity contract specified in security/spark-core.
// Model strings are untrusted display metadata; they never authorize control.
func validateHardwareIdentityPolicy(inventory csharpHardwareInventory) error {
	if inventory.SchemaVersion != 1 || inventory.Platform != "windows" {
		return errors.New("unsupported hardware identity schema or platform")
	}
	if inventory.Status != "ok" && inventory.Status != "partial" && inventory.Status != "unavailable" {
		return errors.New("invalid hardware identity status")
	}
	if inventory.Status == "ok" && len(inventory.Cpus) == 0 && len(inventory.Gpus) == 0 &&
		strings.TrimSpace(inventory.SystemModel) == "" && strings.TrimSpace(inventory.MotherboardModel) == "" {
		return errors.New("empty inventory cannot be marked ok")
	}
	if len(inventory.Cpus) > 64 || len(inventory.Gpus) > 128 || len(inventory.Warnings) > 128 {
		return errors.New("hardware identity collection exceeds limits")
	}
	fields := []string{
		inventory.Collector, inventory.SystemManufacturer, inventory.SystemModel, inventory.SystemFamily,
		inventory.BiosVendor, inventory.BiosVersion, inventory.MotherboardVendor,
		inventory.MotherboardModel, inventory.MotherboardVersion,
	}
	for _, field := range fields {
		if len(field) > 512 {
			return errors.New("hardware identity text field exceeds limit")
		}
	}
	for _, warning := range inventory.Warnings {
		if len(warning) > 512 {
			return errors.New("hardware identity warning exceeds limit")
		}
	}
	for _, cpu := range inventory.Cpus {
		if len(cpu.Manufacturer) > 512 || len(cpu.Model) > 512 || len(cpu.Architecture) > 128 || len(cpu.VendorFamily) > 128 {
			return errors.New("CPU identity text field exceeds limit")
		}
		if cpu.PhysicalCores != nil && (*cpu.PhysicalCores < 0 || *cpu.PhysicalCores > 1024) {
			return errors.New("invalid physical core count")
		}
		if cpu.LogicalProcessors != nil && (*cpu.LogicalProcessors < 0 || *cpu.LogicalProcessors > 4096) {
			return errors.New("invalid logical processor count")
		}
		if cpu.PhysicalCores != nil && cpu.LogicalProcessors != nil && *cpu.PhysicalCores > *cpu.LogicalProcessors {
			return errors.New("physical core count exceeds logical processor count")
		}
	}
	for _, gpu := range inventory.Gpus {
		if len(gpu.Manufacturer) > 512 || len(gpu.Model) > 512 || len(gpu.DriverProvider) > 512 ||
			len(gpu.DriverVersion) > 128 || len(gpu.PciDeviceID) > 17 || len(gpu.VendorFamily) > 128 {
			return errors.New("GPU identity text field exceeds limit")
		}
		if gpu.PciDeviceID != "" && !validPCIDeviceToken(gpu.PciDeviceID) {
			return errors.New("invalid PCI vendor/device token")
		}
	}
	return nil
}

func validPCIDeviceToken(value string) bool {
	if len(value) != 17 || !strings.HasPrefix(value, "VEN_") || value[8:13] != "&DEV_" {
		return false
	}
	for _, i := range []int{4, 5, 6, 7, 13, 14, 15, 16} {
		c := value[i]
		if !((c >= '0' && c <= '9') || (c >= 'A' && c <= 'F')) {
			return false
		}
	}
	return true
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
