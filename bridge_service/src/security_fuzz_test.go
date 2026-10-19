package main

import (
	"bufio"
	"encoding/base64"
	"encoding/json"
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

// FuzzDecodeCommandStrict ensures that arbitrary IPC payloads cannot panic the
// strict schema parser. Inputs are bounded to the production request size.
func FuzzDecodeCommandStrict(f *testing.F) {
	f.Add(`{"action":"Get Status","value":0,"timestamp":1,"nonce":"0123456789abcdef0123456789abcdef","auth":"0000000000000000000000000000000000000000000000000000000000000000"}`)
	f.Add(`{"action":"Get Status","action":"Fan Hızı"}`)
	f.Add(`{"Action":"Get Status"}`)
	f.Add(`null`)
	f.Add(`{}`)
	f.Fuzz(func(t *testing.T, raw string) {
		if len(raw) > maxRequestBytes {
			return
		}
		var cmd Command
		_ = decodeCommandStrict([]byte(raw), &cmd)
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


// FuzzAudioStudioJSONPayload exercises the JSON-to-native-audio boundary with
// valid and mutated JSON. Accepted inputs must still satisfy all domain limits
// and serialize to the exact fixed-width helper protocol, including the five ARGON fields.
func FuzzAudioStudioJSONPayload(f *testing.F) {
	request := audioStudioStartRequest{
		CaptureIndex: 0,
		PlaybackIndex: 0,
		GateThreshold: -48,
		CompressorThreshold: -12,
		CompressorRatio: 2,
		CompressorAttack: 10,
		CompressorRelease: 100,
		CompressorKnee: 6,
		HighPassFrequency: 80,
		LimiterCeiling: -1,
		EQGain: []float64{0, 0, 0},
		EQFrequency: []float64{100, 1000, 8000},
	}
	raw, err := json.Marshal(request)
	if err != nil {
		f.Fatal(err)
	}
	f.Add(string(raw))
	f.Add("{}")
	f.Add(`{"CaptureIndex":-1}`)
	f.Add(`{"EQGain":[1,2,3],"EQFrequency":[NaN,1,2]}`)

	f.Fuzz(func(t *testing.T, rawJSON string) {
		if len(rawJSON) > 6000 {
			// The encoded form would exceed the protocol's 8192-byte bound.
			if _, err := decodeAudioStudioStartTarget(strings.Repeat("A", 8193)); err == nil {
				t.Fatal("oversized configuration was accepted")
			}
			return
		}
		target := base64.RawURLEncoding.EncodeToString([]byte(rawJSON))
		decoded, err := decodeAudioStudioStartTarget(target)
		if err != nil {
			return
		}
		if err := validAudioStudioStartRequest(decoded); err != nil {
			t.Fatalf("decoder accepted a request that fails domain validation: %v", err)
		}
		line := audioStudioStartLine(decoded)
		if strings.ContainsAny(line, "\r\n") {
			t.Fatal("validated configuration introduced a line break into the native protocol")
		}
		if fields := strings.Fields(line); len(fields) != 28 {
			t.Fatalf("native audio protocol has %d fields, want 28", len(fields))
		}
	})
}
