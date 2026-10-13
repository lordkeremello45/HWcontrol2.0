package main

import (
	"sync"
	"time"
)

const maxSensorHistorySamples = 300

type SensorHistorySample struct {
	Timestamp             string  `json:"timestamp"`
	CPUTemperature        float64 `json:"cpuTemperature,omitempty"`
	CPUTemperatureSource  string  `json:"cpuTemperatureSource,omitempty"`
	GPUTemperature        float64 `json:"gpuTemperature,omitempty"`
	GPUTemperatureSource  string  `json:"gpuTemperatureSource,omitempty"`
	CPUUsage              float64 `json:"cpuUsage,omitempty"`
	GPUUsage              float64 `json:"gpuUsage,omitempty"`
	PowerWatts            float64 `json:"powerWatts,omitempty"`
	FanRPM                float64 `json:"fanRpm,omitempty"`
	MemoryUsage           float64 `json:"memoryUsage,omitempty"`
}

type sensorHistoryStore struct {
	mu sync.RWMutex
	samples []SensorHistorySample
}

var localSensorHistory sensorHistoryStore

func recordSensorHistory(metrics HardwareMetrics) {
	if metrics.MetricsCollectedAt == "" {
		return
	}
	sample := SensorHistorySample{
		Timestamp: metrics.MetricsCollectedAt,
		CPUTemperature: metrics.CPUTemperature,
		CPUTemperatureSource: metrics.CPUTemperatureSource,
		GPUTemperature: metrics.GPUTemperature,
		GPUTemperatureSource: metrics.GPUTemperatureSource,
		CPUUsage: metrics.CPUUsage,
		GPUUsage: metrics.GPUUsage,
		PowerWatts: metrics.PowerWatts,
		FanRPM: metrics.FanRPM,
		MemoryUsage: metrics.MemoryUsage,
	}
	localSensorHistory.mu.Lock()
	defer localSensorHistory.mu.Unlock()
	localSensorHistory.samples = append(localSensorHistory.samples, sample)
	if len(localSensorHistory.samples) > maxSensorHistorySamples {
		localSensorHistory.samples = append([]SensorHistorySample(nil), localSensorHistory.samples[len(localSensorHistory.samples)-maxSensorHistorySamples:]...)
	}
}

func sensorHistorySnapshot() map[string]any {
	localSensorHistory.mu.RLock()
	samples := append([]SensorHistorySample(nil), localSensorHistory.samples...)
	localSensorHistory.mu.RUnlock()
	return map[string]any{
		"localOnly": true,
		"persistent": false,
		"capacity": maxSensorHistorySamples,
		"sampleCount": len(samples),
		"samples": samples,
	}
}

func sensorHistoryAge(sample SensorHistorySample, now time.Time) (time.Duration, bool) {
	parsed, err := time.Parse(time.RFC3339Nano, sample.Timestamp)
	if err != nil || parsed.After(now.Add(time.Second)) {
		return 0, false
	}
	return now.Sub(parsed), true
}
