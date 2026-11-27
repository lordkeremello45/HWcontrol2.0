package main

import (
	"runtime"
	"testing"
)

func TestNativeHardwareAPIImplementsPlatformNeutralContract(t *testing.T) {
	var api HardwareAPI = hardwareAPI()
	if api == nil {
		t.Fatal("hardware API must not be nil")
	}
	if got := api.PlatformID(); got != runtime.GOOS {
		t.Fatalf("platform ID = %q, want %q", got, runtime.GOOS)
	}
}

func TestNativeHardwareAPIHandlesNilMetrics(t *testing.T) {
	var api HardwareAPI = hardwareAPI()
	// A nil snapshot is a no-op; it must not panic during optional platform collection.
	api.CollectPlatformMetrics(nil)
}

func TestNativeHardwareAPIFanDiscoveryReturnsValidChannelRecords(t *testing.T) {
	var api HardwareAPI = hardwareAPI()
	for _, channel := range api.FanChannels() {
		if channel.ID == "" {
			t.Fatal("discovered fan channel has an empty identifier")
		}
		if channel.Backend == "" {
			t.Fatalf("fan channel %q has no backend identity", channel.ID)
		}
		if channel.Supported && channel.Reason != "" {
			t.Fatalf("supported fan channel %q unexpectedly has an unavailable reason: %q", channel.ID, channel.Reason)
		}
		if !channel.Supported && channel.Reason == "" {
			t.Fatalf("unsupported fan channel %q must explain why it is unavailable", channel.ID)
		}
	}
}
