package main

type HardwareIdentity struct {
	SystemManufacturer string
	SystemModel string
	SystemVersion string
	BIOSVendor string
	BIOSVersion string
	MotherboardVendor string
	MotherboardModel string
	MotherboardVersion string
	CPUManufacturer string
	CPUModel string
	CPUArchitecture string
	CPUPhysicalCores int
	CPUThreads int
	GPUVendor string
	GPUModel string
	GPUDriver string
	GPUDriverVersion string
	DetectionSource string
	DetectionStatus string
	SerialsExcluded bool
}

func emptyHardwareIdentity() HardwareIdentity {
	return HardwareIdentity{CPUArchitecture: runtimeGOARCH(), DetectionStatus: "partial", SerialsExcluded: true}
}
