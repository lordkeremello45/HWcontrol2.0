package main

type SensorHealthService struct {
	Status string `json:"status"`
	SafetyState string `json:"safetyState"`
	ThermalTelemetryValid bool `json:"thermalTelemetryValid"`
	CPUTemperature float64 `json:"cpuTemperature"`
	GPUTemperature float64 `json:"gpuTemperature"`
	SensorSource string `json:"sensorSource"`
	HardwareControl string `json:"hardwareControl"`
	Anomalies []HardwareAnomaly `json:"anomalies"`
}
func sensorHealthSnapshot() SensorHealthService {
	m:=collectMetrics(); h:=evaluateHardwareHealth(m)
	return SensorHealthService{Status:h.Status,SafetyState:h.SafetyState,ThermalTelemetryValid:m.ThermalSafetyAvailable,CPUTemperature:m.CPUTemperature,GPUTemperature:m.GPUTemperature,SensorSource:m.SensorSource,HardwareControl:m.HardwareControlMode,Anomalies:h.Anomalies}
}
