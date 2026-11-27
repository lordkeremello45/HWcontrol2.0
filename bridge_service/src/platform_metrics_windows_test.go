//go:build windows

package main

import "testing"

func TestApplyWindowsTemperatureMetricsPreservesPresentZeroAndSubzero(t *testing.T) {
	for _, temperature := range []float64{0, -5} {
		metrics := HardwareMetrics{}
		applyWindowsTemperatureMetrics(&metrics, windowsSensorMetrics{
			CPUTemperature: temperature,
			GPUTemperature: temperature,
			HasCPUTemperature: true,
			HasGPUTemperature: true,
			SensorSource: "LibreHardwareMonitor WMI",
		})
		if metrics.CPUTemperature != temperature || metrics.CPUTemperatureSource == "" {
			t.Fatalf("CPU temperature %v was not preserved: %+v", temperature, metrics)
		}
		if metrics.GPUTemperature != temperature || metrics.GPUTemperatureSource == "" {
			t.Fatalf("GPU temperature %v was not preserved: %+v", temperature, metrics)
		}
	}
}

func TestApplyWindowsTemperatureMetricsRejectsAbsentZeroAndMissingSource(t *testing.T) {
	metrics := HardwareMetrics{}
	applyWindowsTemperatureMetrics(&metrics, windowsSensorMetrics{
		CPUTemperature: 0,
		GPUTemperature: 0,
		HasCPUTemperature: false,
		HasGPUTemperature: false,
		SensorSource: "Windows WMI fallback",
	})
	if metrics.CPUTemperatureSource != "" || metrics.GPUTemperatureSource != "" {
		t.Fatalf("absent zero-valued sensors were published: %+v", metrics)
	}
	applyWindowsTemperatureMetrics(&metrics, windowsSensorMetrics{
		CPUTemperature: 55,
		GPUTemperature: 60,
		HasCPUTemperature: true,
		HasGPUTemperature: true,
	})
	if metrics.CPUTemperatureSource != "" || metrics.GPUTemperatureSource != "" {
		t.Fatalf("temperature values without a source were published: %+v", metrics)
	}
}

func TestApplyWindowsTemperatureMetricsHandlesNilMetrics(t *testing.T) {
	applyWindowsTemperatureMetrics(nil, windowsSensorMetrics{
		HasCPUTemperature: true,
		CPUTemperature: 50,
		SensorSource: "test",
	})
}
