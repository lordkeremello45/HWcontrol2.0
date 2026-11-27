package main

import "runtime"

// HardwareAPI is the bridge's platform-neutral boundary to native hardware
// telemetry and actuator backends. Implementations must report only capabilities
// they can currently exercise and must fail closed when a backend is unavailable.
type HardwareAPI interface {
	PlatformID() string
	CollectPlatformMetrics(*HardwareMetrics)
	FanControlInfo() FanControlInfo
	FanChannels() []FanChannel
	SetFanPercent(float64) error
	SetFanChannel(string, float64) error
}

// nativeHardwareAPI adapts the existing OS-specific implementations to the
// shared HardwareAPI contract. Platform-specific behavior remains behind the
// build-tagged functions in platform_metrics_*.go and fan_control_*.go.
type nativeHardwareAPI struct{}

var _ HardwareAPI = nativeHardwareAPI{}

func hardwareAPI() HardwareAPI {
	return nativeHardwareAPI{}
}

func (nativeHardwareAPI) PlatformID() string {
	return runtime.GOOS
}

func (nativeHardwareAPI) CollectPlatformMetrics(metrics *HardwareMetrics) {
	if metrics == nil {
		return
	}
	mergePlatformMetrics(metrics)
}

func (nativeHardwareAPI) FanControlInfo() FanControlInfo {
	return detectFanControl()
}

func (nativeHardwareAPI) FanChannels() []FanChannel {
	return listFanChannels()
}

func (nativeHardwareAPI) SetFanPercent(percent float64) error {
	return setFanControl(percent)
}

func (nativeHardwareAPI) SetFanChannel(id string, percent float64) error {
	return setFanControlChannel(id, percent)
}
