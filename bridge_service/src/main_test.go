package main

import "testing"

func TestValidateCommand(t *testing.T) {
	tests := []struct {
		name    string
		command Command
		valid   bool
	}{
		{"valid fan command", Command{Action: "Fan Hızı", Value: 50}, true},
		{"unknown action", Command{Action: "shutdown", Value: 50}, false},
		{"out of range", Command{Action: "Fan Hızı", Value: 101}, false},
		{"missing action", Command{Value: 20}, false},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			if (validateCommand(test.command) == nil) != test.valid {
				t.Fatalf("validateCommand(%+v) validity mismatch", test.command)
			}
		})
	}
}
