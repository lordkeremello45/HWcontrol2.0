//go:build darwin

package main

func detectFanControl() FanControlInfo {
	return fanControlUnavailable("macOS Apple Silicon fan-control backend is not yet validated")
}

func setFanControl(percent float64) error {
	return fanControlUnavailable("macOS fan-control backend is not available").asError()
}
func listFanChannels() []FanChannel {
	return nil
}

func setFanControlChannel(id string, percent float64) error {
	return fanControlUnavailable("per-channel fan control backend is not validated on this platform").asError()
}
