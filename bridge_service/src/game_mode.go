package main

import (
	"strings"
	"sync"
	"time"

	"github.com/shirou/gopsutil/v3/process"
)

type GameModeState struct {
	Enabled          bool   `json:"enabled"`
	AutoDetection    bool   `json:"autoDetection"`
	GameDetected     bool   `json:"gameDetected"`
	ProcessName      string `json:"processName"`
	PID              uint32 `json:"pid"`
	DetectedAt       string `json:"detectedAt"`
	OptimizationMode string `json:"optimizationMode"`
}

var gameModeState = struct {
	sync.RWMutex
	enabled bool
}{}

var knownGameProcesses = map[string]struct{}{
	"eldenring.exe": {}, "eldenring": {}, "valorant-win64-shipping.exe": {},
	"valorant-win64-shipping": {}, "cs2.exe": {}, "cs2": {}, "csgo.exe": {},
	"fortniteclient-win64-shipping.exe": {}, "fortniteclient-win64-shipping": {},
	"rocketleague.exe": {}, "rocketleague": {}, "gta5.exe": {}, "gta5": {},
	"r5apex.exe": {}, "r5apex": {}, "overwatch.exe": {}, "overwatch": {},
	"helldivers2.exe": {}, "helldivers2": {}, "minecraft.exe": {}, "javaw.exe": {},
	"witcher3.exe": {}, "cyberpunk2077.exe": {}, "dota2.exe": {}, "dota2": {},
	"leagueoflegends.exe": {}, "leagueclient.exe": {}, "pubg.exe": {},
	"paladins.exe": {}, "rainbowsix.exe": {}, "acvalhalla.exe": {},
	"hogwartslegacy.exe": {}, "starfield.exe": {}, "thefinals.exe": {},
	"apex.exe": {},
}

func setGameModeEnabled(enabled bool) {
	gameModeState.Lock()
	gameModeState.enabled = enabled
	gameModeState.Unlock()
}

func gameModeEnabled() bool {
	gameModeState.RLock()
	defer gameModeState.RUnlock()
	return gameModeState.enabled
}

func detectGameProcess() (string, uint32, bool) {
	procs, err := process.Processes()
	if err != nil { return "", 0, false }
	for _, p := range procs {
		name, err := p.Name()
		if err != nil { continue }
		n := strings.ToLower(strings.TrimSpace(name))
		if _, ok := knownGameProcesses[n]; ok {
			return name, p.Pid, true
		}
	}
	return "", 0, false
}

func collectGameModeState() GameModeState {
	name, pid, detected := detectGameProcess()
	enabled := gameModeEnabled()
	optimization := "monitoring-only"
	if enabled && detected {
		optimization = "game-active-monitoring"
	} else if enabled {
		optimization = "game-mode-armed"
	}
	state := GameModeState{
		Enabled: enabled, AutoDetection: true, GameDetected: detected,
		ProcessName: name, PID: uint32(pid), OptimizationMode: optimization,
	}
	if detected { state.DetectedAt = time.Now().UTC().Format(time.RFC3339) }
	return state
}
