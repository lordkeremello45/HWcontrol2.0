package main

type SensorHealthService struct {
	Status                string            `json:"status"`
	SafetyState           string            `json:"safetyState"`
	ThermalTelemetryValid bool              `json:"thermalTelemetryValid"`
	CPUTemperature        float64           `json:"cpuTemperature,omitempty"`
	CPUTemperatureSource  string            `json:"cpuTemperatureSource,omitempty"`
	GPUTemperature        float64           `json:"gpuTemperature,omitempty"`
	GPUTemperatureSource  string            `json:"gpuTemperatureSource,omitempty"`
	MetricsCollectedAt    string            `json:"metricsCollectedAt,omitempty"`
	SensorSource          string            `json:"sensorSource"`
	HardwareControl       string            `json:"hardwareControl"`
	Anomalies             []HardwareAnomaly `json:"anomalies"`
}

func sensorHealthSnapshot() SensorHealthService {
	metrics := collectMetrics()
	health := evaluateHardwareHealth(metrics)
	return SensorHealthService{
		Status:                health.Status,
		SafetyState:           health.SafetyState,
		ThermalTelemetryValid: metrics.ThermalSafetyAvailable,
		CPUTemperature:        metrics.CPUTemperature,
		CPUTemperatureSource:  metrics.CPUTemperatureSource,
		GPUTemperature:        metrics.GPUTemperature,
		GPUTemperatureSource:  metrics.GPUTemperatureSource,
		MetricsCollectedAt:    metrics.MetricsCollectedAt,
		SensorSource:          metrics.SensorSource,
		HardwareControl:       metrics.HardwareControlMode,
		Anomalies:             health.Anomalies,
	}
}
