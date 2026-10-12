package main

import "testing"

func TestPowerModeNameAcceptsOnlySupportedChoices(t *testing.T) {
	tests := []struct {
		value float64
		want  string
		ok    bool
	}{
		{0, "Balanced", true},
		{50, "Best Power Efficiency", true},
		{100, "Best Performance", true},
		{1, "", false},
		{75, "", false},
		{-1, "", false},
	}
	for _, test := range tests {
		got, ok := powerModeName(test.value)
		if got != test.want || ok != test.ok {
			t.Errorf("powerModeName(%v) = (%q, %v), want (%q, %v)", test.value, got, ok, test.want, test.ok)
		}
	}
}

func TestValidatePowerModeRequest(t *testing.T) {
	for _, action := range []string{"Set Power Mode AC", "Set Power Mode DC"} {
		for _, value := range []float64{0, 50, 100} {
			if err := validatePowerModeRequest(action, value); err != nil {
				t.Errorf("validatePowerModeRequest(%q, %v): %v", action, value, err)
			}
		}
		for _, value := range []float64{1, 25, 75, 101} {
			if err := validatePowerModeRequest(action, value); err == nil {
				t.Errorf("validatePowerModeRequest(%q, %v) unexpectedly succeeded", action, value)
			}
		}
	}
	if err := validatePowerModeRequest("Set Power Mode", 100); err == nil {
		t.Fatal("unexpectedly accepted unscoped power mode action")
	}
}

func TestValidateCommandAcceptsPowerModeActions(t *testing.T) {
	for _, test := range []struct {
		action string
		value  float64
		valid  bool
	}{
		{"Get Power Mode", 0, true},
		{"Get Power Mode", 1, false},
		{"Set Power Mode AC", 0, true},
		{"Set Power Mode AC", 50, true},
		{"Set Power Mode AC", 100, true},
		{"Set Power Mode AC", 75, false},
		{"Set Power Mode DC", 100, true},
	} {
		command := testCommand(test.action, test.value)
		err := validateCommand(command)
		if (err == nil) != test.valid {
			t.Errorf("validateCommand(%q, %v) error=%v, want valid=%v", test.action, test.value, err, test.valid)
		}
	}
}
