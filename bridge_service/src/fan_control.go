package main

import (
	"encoding/hex"
	"fmt"
)

type FanControlInfo struct {
	Supported bool
	Backend   string
	Handle    string
	Reason    string
}

// FanChannel is a capability report for one independently addressable fan
// output. ID is an opaque, validated identifier; it is never a filesystem path.
type FanChannel struct {
	ID               string  `json:"id"`
	Name             string  `json:"name"`
	Backend          string  `json:"backend"`
	Supported        bool    `json:"supported"`
	FanRPM           float64 `json:"fanRpm"`
	RPMAvailable     bool    `json:"rpmAvailable"`
	FanPercent       float64 `json:"fanPercent"`
	PercentAvailable bool    `json:"percentAvailable"`
	Reason           string  `json:"reason,omitempty"`
}

func fanControlUnavailable(reason string) FanControlInfo {
	return FanControlInfo{Supported: false, Backend: "monitor-only", Reason: reason}
}

func (i FanControlInfo) asError() error {
	if i.Reason == "" {
		return fmt.Errorf("fan control backend unavailable")
	}
	return fmt.Errorf("fan control backend unavailable: %s", i.Reason)
}

func validateFanPercent(percent float64) error {
	if !isFiniteNonNegative(percent) || percent <= 0 || percent > 100 {
		return fmt.Errorf("fan percent must be greater than 0 and at most 100; zero can stop the fan")
	}
	return nil
}

func validFanChannelID(id string) bool {
	if len(id) != 16 {
		return false
	}
	_, err := hex.DecodeString(id)
	return err == nil
}

func anyControllableFanChannel(channels []FanChannel) bool {
	for _, channel := range channels {
		if channel.Supported && validFanChannelID(channel.ID) && channel.Backend != "" && channel.Backend != "monitor-only" {
			return true
		}
	}
	return false
}
