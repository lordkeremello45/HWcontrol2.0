package main

import "testing"

func TestGameModeStateDefaultsSafe(t *testing.T) {
	setGameModeEnabled(false)
	state := collectGameModeState()
	if state.Enabled { t.Fatal("game mode must default to disabled") }
	if !state.AutoDetection { t.Fatal("automatic detection must remain enabled") }
	if state.OptimizationMode != "monitoring-only" && state.OptimizationMode != "game-active-monitoring" && state.OptimizationMode != "game-mode-armed" {
		t.Fatalf("unexpected optimization mode: %s", state.OptimizationMode)
	}
}
