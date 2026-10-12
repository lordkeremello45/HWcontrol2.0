//go:build linux

package main

import "testing"

func TestParseBusctlString(t *testing.T) {
	for _, test := range []struct {
		input string
		want  string
		ok    bool
	}{
		{`s "balanced"`, "balanced", true},
		{`s "power-saver"`, "power-saver", true},
		{`s "performance"`, "performance", true},
		{`u 1`, "", false},
		{`s ""`, "", false},
		{`garbage`, "", false},
	} {
		got, err := parseBusctlString(test.input)
		if (err == nil) != test.ok || got != test.want {
			t.Errorf("parseBusctlString(%q) = (%q, %v), want (%q, ok=%v)", test.input, got, err, test.want, test.ok)
		}
	}
}

func TestLinuxProfileMapping(t *testing.T) {
	for _, test := range []struct {
		value float64
		want  string
		ok    bool
	}{
		{0, "balanced", true},
		{50, "power-saver", true},
		{100, "performance", true},
		{75, "", false},
	} {
		got, err := linuxProfileName(test.value)
		if (err == nil) != test.ok || got != test.want {
			t.Errorf("linuxProfileName(%v) = (%q, %v), want (%q, ok=%v)", test.value, got, err, test.want, test.ok)
		}
	}
}
