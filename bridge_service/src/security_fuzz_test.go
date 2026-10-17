package main

import (
	"bufio"
	"errors"
	"strings"
	"testing"
)

// FuzzCommandAuthenticationCoversPayload checks that arbitrary command fields
// survive signing/verification and that changing an authenticated field is
// rejected. This targets the IPC authentication trust boundary.
func FuzzCommandAuthenticationCoversPayload(f *testing.F) {
	f.Add("Get Status", 0.0, "", int64(1), "nonce")
	f.Add("Set Fan Speed", 51.0, "front-fan", int64(-42), "")
	f.Add("", 1.0, "target", int64(0), "replay")

	f.Fuzz(func(t *testing.T, action string, value float64, target string, timestamp int64, nonce string) {
		cmd := Command{
			Action:    action,
			Value:     value,
			Target:    target,
			Timestamp: timestamp,
			Nonce:     nonce,
		}
		const secret = "test-only-secret-for-command-authentication"
		cmd.Auth = signCommand(cmd, secret)
		if !authenticateCommand(cmd, secret) {
			t.Fatal("a freshly signed command did not authenticate")
		}

		cmd.Nonce += "\x00tampered"
		if authenticateCommand(cmd, secret) {
			t.Fatal("authentication accepted a command after its nonce changed")
		}
	})
}

// FuzzReadBoundedRequest asserts that arbitrary input cannot make the bridge
// request reader return an oversized successful request or a partial line as
// a complete request.
func FuzzReadBoundedRequest(f *testing.F) {
	f.Add("")
	f.Add("Get Status\n")
	f.Add("{invalid-json}\n")
	f.Add(strings.Repeat("a", maxRequestBytes))
	f.Add(strings.Repeat("a", maxRequestBytes+1))

	f.Fuzz(func(t *testing.T, input string) {
		// Cap fuzz inputs around the actual production request limit so a single
		// generated input cannot consume disproportionate memory in CI.
		if len(input) > maxRequestBytes+2 {
			input = input[:maxRequestBytes+2]
		}
		line, err := readBoundedRequest(bufio.NewReader(strings.NewReader(input)), maxRequestBytes)
		if err == nil {
			if len(line) > maxRequestBytes {
				t.Fatalf("reader returned oversized successful request: %d bytes", len(line))
			}
			if len(line) == 0 || line[len(line)-1] != '\n' {
				t.Fatal("reader accepted a request that did not end with a newline")
			}
		}
		if errors.Is(err, errRequestTooLarge) && line != nil {
			t.Fatal("oversized request returned data instead of a rejection")
		}
	})
}
