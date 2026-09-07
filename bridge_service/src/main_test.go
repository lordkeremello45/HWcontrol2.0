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
		{"status command", Command{Action: "Get Status"}, true},
		{"security command", Command{Action: "Get Security"}, true},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			if (validateCommand(test.command) == nil) != test.valid {
				t.Fatalf("validateCommand(%+v) validity mismatch", test.command)
			}
		})
	}
}

func TestAuthenticateCommand(t *testing.T) {
	command := Command{Action: "Fan Hızı", Value: 50}
	secret := "test-secret"
	command.Auth = signCommand(command, secret)

	if !authenticateCommand(command, secret) {
		t.Fatal("expected command authentication to succeed")
	}
	command.Value = 51
	if authenticateCommand(command, secret) {
		t.Fatal("expected modified command authentication to fail")
	}
}

func TestExecuteHardwareCommandFailsClosed(t *testing.T) {
	for _, action := range []string{"Fan Hızı", "AI İşlem Gücü"} {
		err := executeHardwareCommand(Command{Action: action, Value: 50})
		if err == nil {
			t.Fatalf("expected %q to fail without a hardware backend", action)
		}
	}
}
