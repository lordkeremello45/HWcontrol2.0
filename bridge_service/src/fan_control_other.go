//go:build !linux && !windows && !darwin

package main

func detectFanControl() FanControlInfo {
	return fanControlUnavailable("platform fan-control backend is not implemented")
}

func setFanControl(percent float64) error {
	return fanControlUnavailable("platform fan-control backend is not available").asError()
}
