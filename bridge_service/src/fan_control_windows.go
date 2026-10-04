//go:build windows

package main

func detectFanControl() FanControlInfo {
	return fanControlUnavailable("Windows vendor/EC fan-control backend is not yet validated")
}

func setFanControl(percent float64) error {
	return fanControlUnavailable("Windows fan-control backend is not available").asError()
}
