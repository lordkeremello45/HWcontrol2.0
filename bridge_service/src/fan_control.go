package main

import "fmt"

type FanControlInfo struct {
	Supported bool
	Backend   string
	Handle    string
	Reason    string
}

func fanControlUnavailable(reason string) FanControlInfo {
	return FanControlInfo{Supported: false, Backend: "monitor-only", Reason: reason}
}

func (i FanControlInfo) asError() error {
	if i.Reason == "" { return fmt.Errorf("fan control backend unavailable") }
	return fmt.Errorf("fan control backend unavailable: %s", i.Reason)
}

func validateFanPercent(percent float64) error {
	if percent < 0 || percent > 100 {
		return fmt.Errorf("fan percent must be between 0 and 100")
	}
	return nil
}
