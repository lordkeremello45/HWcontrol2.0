package main

import (
	"os"
	"regexp"
	"strings"
)

var (
	redactionPatterns = []*regexp.Regexp{
		regexp.MustCompile(`(?i)(HWCONTROL_KEY(?:_FILE)?\s*[=:]\s*)([^\s,;]+)`),
		regexp.MustCompile(`(?i)((?:HMAC|API[_-]?KEY|ACCESS[_-]?TOKEN|REFRESH[_-]?TOKEN|AUTHORIZATION|BEARER|PASSWORD|SECRET)\s*[=:]\s*)([^\s,;]+)`),
		regexp.MustCompile(?i)(Bearer\s+)([^\s]+),
		regexp.MustCompile(`(?i)(-----BEGIN [A-Z0-9 ]+PRIVATE KEY-----)([\s\S]*?)(-----END [A-Z0-9 ]+PRIVATE KEY-----)`),
	}
	userPathPattern = regexp.MustCompile(`(?i)([A-Z]:[\\/]+Users[\\/]+)[^\\/\s]+|(/Users/)[^/\s]+|(/home/)[^/\s]+`)
)

// redactSensitiveText removes credentials and local usernames before text reaches
// persistent bridge logs or diagnostic artifacts.
func redactSensitiveText(input string) string {
	out := input
	for _, pattern := range redactionPatterns {
		out = pattern.ReplaceAllStringFunc(out, func(match string) string {
			if strings.Contains(strings.ToLower(match), "private key") {
				return "[REDACTED_PRIVATE_KEY]"
			}
			parts := strings.FieldsFunc(match, func(r rune) bool {
				return r == '=' || r == ':'
			})
			if len(parts) == 0 {
				return "[REDACTED]"
			}
			prefixLen := len(match) - len(strings.TrimLeft(match, " \t"))
			prefix := match[:prefixLen]
			if i := strings.IndexAny(match, "=:"); i >= 0 {
				prefix = match[:i+1]
			}
			if strings.HasPrefix(strings.ToLower(strings.TrimSpace(match)), "bearer") {
				return "Bearer [REDACTED]"
			}
			return prefix + "[REDACTED]"
		})
	}
	out = userPathPattern.ReplaceAllString(out, "$1<USER>")
	return out
}

type redactingWriter struct {
	dst interface{ Write([]byte) (int, error) }
}

func (w redactingWriter) Write(p []byte) (int, error) {
	clean := redactSensitiveText(string(p))
	return w.dst.Write([]byte(clean))
}

func redactEnvironmentValue(name, value string) string {
	lower := strings.ToLower(name)
	if strings.Contains(lower, "key") || strings.Contains(lower, "token") ||
		strings.Contains(lower, "secret") || strings.Contains(lower, "password") {
		return "[REDACTED]"
	}
	if value == os.Getenv("HWCONTROL_KEY") {
		return "[REDACTED]"
	}
	return redactSensitiveText(value)
}
