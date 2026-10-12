package main

import (
	"os"
	"path/filepath"
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
	SessionDurationSeconds int64 `json:"sessionDurationSeconds"`
	OptimizationMode string `json:"optimizationMode"`
}

var gameModeState = struct {
	sync.RWMutex
	enabled bool
}{}

var gameSession = struct {
	sync.Mutex
	processName string
	pid         uint32
	detectedAt  time.Time
}{}

var knownGameProcesses = map[string]struct{}{
	"eldenring.exe": {}, "eldenring": {}, "valorant-win64-shipping.exe": {},
	"valorant-win64-shipping": {}, "cs2.exe": {}, "cs2": {}, "csgo.exe": {},
	"fortniteclient-win64-shipping.exe": {}, "fortniteclient-win64-shipping": {},
	"rocketleague.exe": {}, "rocketleague": {}, "gta5.exe": {}, "gta5": {},
	"r5apex.exe": {}, "r5apex": {}, "overwatch.exe": {}, "overwatch": {},
	"helldivers2.exe": {}, "helldivers2": {}, "minecraft.exe": {},
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

func normalizeGameProcessName(name string) string {
	normalized := strings.TrimSpace(strings.ToLower(name))
	normalized = strings.ReplaceAll(normalized, "\\", "/")
	if slash := strings.LastIndex(normalized, "/"); slash >= 0 {
		normalized = normalized[slash+1:]
	}
	return filepath.Base(normalized)
}

func isKnownGameProcess(name string) bool {
	normalized := normalizeGameProcessName(name)
	if normalized == "" {
		return false
	}
	if _, ok := knownGameProcesses[normalized]; ok {
		return true
	}

	// Optional user-defined executable allow-list. This keeps unknown games
	// opt-in and avoids broad matches such as javaw.exe or generic launchers.
	for _, configured := range strings.Split(os.Getenv("HWCONTROL_GAME_PROCESSES"), ",") {
		if candidate := normalizeGameProcessName(configured); candidate != "" && candidate == normalized {
			return true
		}
	}
	return false
}

// gameSessionDetectedAt preserves the first detection time for the same process
// and PID. A new PID starts a new session; a missing process clears the session.
func gameSessionDetectedAt(name string, pid uint32, detected bool, now time.Time) string {
	gameSession.Lock()
	defer gameSession.Unlock()

	if !detected || pid == 0 {
		gameSession.processName = ""
		gameSession.pid = 0
		gameSession.detectedAt = time.Time{}
		return ""
	}

	if gameSession.pid != pid || !strings.EqualFold(gameSession.processName, name) || gameSession.detectedAt.IsZero() {
		gameSession.processName = name
		gameSession.pid = pid
		gameSession.detectedAt = now.UTC()
	}
	return gameSession.detectedAt.Format(time.RFC3339)
}

func gameSessionDurationSeconds(now time.Time) int64 {
	gameSession.Lock()
	defer gameSession.Unlock()
	if gameSession.detectedAt.IsZero() || now.Before(gameSession.detectedAt) {
		return 0
	}
	return int64(now.Sub(gameSession.detectedAt).Seconds())
}

func detectGameProcess() (string, uint32, bool) {
	procs, err := process.Processes()
	if err != nil {
		return "", 0, false
	}
	for _, p := range procs {
		name, err := p.Name()
		if err != nil || p.Pid <= 0 || !isKnownGameProcess(name) {
			continue
		}
		return name, uint32(p.Pid), true
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
	now := time.Now()
	detectedAt := gameSessionDetectedAt(name, pid, detected, now)
	return GameModeState{
		Enabled: enabled, AutoDetection: true, GameDetected: detected,
		ProcessName: name, PID: pid, DetectedAt: detectedAt,
		SessionDurationSeconds: gameSessionDurationSeconds(now), OptimizationMode: optimization,
	}
}
