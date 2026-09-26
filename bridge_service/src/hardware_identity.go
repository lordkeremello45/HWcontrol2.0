package main

type GPUIdentity struct {
	Vendor        string `json:"vendor"`
	Model         string `json:"model"`
	Driver        string `json:"driver"`
	DriverVersion string `json:"driverVersion"`
	PCIAddress    string `json:"pciAddress"`
	DeviceID      string `json:"deviceId"`
	MemoryBytes   uint64 `json:"memoryBytes"`
}

type HardwareIdentity struct {
	SystemManufacturer string
	SystemModel        string
	SystemVersion      string
	BIOSVendor         string
	BIOSVersion        string
	MotherboardVendor  string
	MotherboardModel   string
	MotherboardVersion string
	CPUManufacturer    string
	CPUModel           string
	CPUArchitecture    string
	CPUPhysicalCores   int
	CPUThreads         int
	GPUVendor          string
	GPUModel           string
	GPUDriver          string
	GPUDriverVersion   string
	GPUs               []GPUIdentity
	DetectionSource    string
	DetectionStatus    string
	SerialsExcluded    bool
}

func emptyHardwareIdentity() HardwareIdentity {
	return HardwareIdentity{CPUArchitecture: runtimeGOARCH(), DetectionStatus: "partial", SerialsExcluded: true}
}
