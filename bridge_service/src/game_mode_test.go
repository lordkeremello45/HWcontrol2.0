package main

import (
	"testing"
	"time"
)

func TestGameModeStateDefaultsSafe(t *testing.T) {
	setGameModeEnabled(false)
	gameSessionDetectedAt("", 0, false, time.Now())
	state := collectGameModeState()
	if state.Enabled {
		t.Fatal("game mode must default to disabled")
	}
	if !state.AutoDetection {
		t.Fatal("automatic detection must remain enabled")
	}
	if state.OptimizationMode != "monitoring-only" && state.OptimizationMode != "game-active-monitoring" && state.OptimizationMode != "game-mode-armed" {
		t.Fatalf("unexpected optimization mode: %s", state.OptimizationMode)
	}
}

func TestGameSessionDetectionTimeIsStable(t *testing.T) {
	start := time.Date(2026, 10, 12, 10, 0, 0, 0, time.UTC)
	nextPoll := start.Add(15 * time.Second)

	got := gameSessionDetectedAt("cs2.exe", 1234, true, start)
	if want := start.Format(time.RFC3339); got != want {
		t.Fatalf("first detection = %q, want %q", got, want)
	}
	got = gameSessionDetectedAt("CS2.EXE", 1234, true, nextPoll)
	if want := start.Format(time.RFC3339); got != want {
		t.Fatalf("session detection time changed on poll: got %q, want %q", got, want)
	}
	if got := gameSessionDurationSeconds(nextPoll); got != 15 {
		t.Fatalf("session duration = %d, want 15 seconds", got)
	}
	got = gameSessionDetectedAt("cs2.exe", 5678, true, nextPoll)
	if want := nextPoll.Format(time.RFC3339); got != want {
		t.Fatalf("new PID detection = %q, want %q", got, want)
	}
	if got = gameSessionDetectedAt("", 0, false, nextPoll.Add(time.Second)); got != "" {
		t.Fatalf("session should clear after game exits, got %q", got)
	}
	if got := gameSessionDurationSeconds(nextPoll.Add(time.Second)); got != 0 {
		t.Fatalf("cleared session duration = %d, want 0", got)
	}
	got = gameSessionDetectedAt("cs2.exe", 1234, true, nextPoll.Add(2*time.Second))
	if want := nextPoll.Add(2 * time.Second).Format(time.RFC3339); got != want {
		t.Fatalf("restarted session detection = %q, want %q", got, want)
	}
}

func TestKnownGameProcessAllowListAvoidsGenericJavaProcess(t *testing.T) {
	for _, name := range []string{"CS2.EXE", " cs2 ", "Cyberpunk2077.exe", "Minecraft.exe"} {
		if !isKnownGameProcess(name) {
			t.Errorf("expected known game process %q to be recognized", name)
		}
	}
	for _, name := range []string{"javaw.exe", "idea64.exe", "chrome.exe", "unknown-game.exe", ""} {
		if isKnownGameProcess(name) {
			t.Errorf("unexpected process %q recognized as a game", name)
		}
	}
}

func TestCustomGameProcessAllowListIsOptInAndNormalized(t *testing.T) {
	t.Setenv("HWCONTROL_GAME_PROCESSES", "my-game.exe, /opt/games/indie-game")
	for _, name := range []string{"MY-GAME.EXE", "indie-game", "/opt/games/indie-game"} {
		if !isKnownGameProcess(name) {
			t.Errorf("expected configured game process %q to be recognized", name)
		}
	}
	for _, name := range []string{"javaw.exe", "unknown.exe"} {
		if isKnownGameProcess(name) {
			t.Errorf("unconfigured process %q must not be recognized", name)
		}
	}
}
