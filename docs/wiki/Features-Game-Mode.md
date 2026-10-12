# Game Mode

Game Mode provides a conservative game-session detection and monitoring layer.

## Behavior

- Can be armed from the dashboard.
- Automatically scans running processes for known game executables.
- Reports the detected process name and PID through the authenticated bridge.
- Preserves the session start timestamp while the same process name and PID remain detected.
- Reports elapsed session duration in seconds through the bridge state.
- Starts a new session when the detected PID changes and clears the timestamp when no allow-listed game is found.
- Includes Game Mode state in diagnostics.
- Does not change clocks, voltage, power limits, process priority, or terminate background processes.
- Hardware actions remain disabled unless a platform backend has been validated and explicitly reports support.

## Per-game profile assignment

- When a supported game is detected, the dashboard exposes a profile-assignment control for that executable.
- Assignments are stored in the user's local settings as executable-name-to-saved-profile mappings.
- A mapped profile currently applies its saved fan target only. The AI value is not a hardware-control action.
- When Smart Fan is enabled, its valid automatic target may raise the game profile's fan target; a game profile must not suppress thermal automation.
- If no profile is assigned, Game Mode retains its default 75% fan target, but only when the bridge reports a validated fan-control backend.
- On game exit, Game Mode disable, or switching to another detected game, the dashboard attempts to restore the fan target that was active before the game session.
- The profile mapping is keyed by executable basename, not a full path or Steam app ID. Different games that use the same executable basename share the mapping.
- If the bridge rejects a fan command or the backend is unavailable, the dashboard must not claim the target was applied.

## Detection limitations

Detection uses a conservative executable allow-list. Unknown games are not automatically treated as games. Generic `javaw.exe` is intentionally not allow-listed because it is also used by non-game Java applications.

Advanced users can opt in to additional executable names through the bridge service environment variable `HWCONTROL_GAME_PROCESSES`, as a comma-separated list (for example, `my-game.exe,indie-game`). Entries are normalized to executable basenames and compared case-insensitively. Configure this in the bridge service environment and restart the service. Do not add generic processes such as `javaw.exe`, shells, or launchers unless you accept the resulting false-positive risk. A dedicated in-app editor for these rules is not implemented yet.

The detector reports one matching process at a time. Per-game profile auto-selection, an in-app game-rule editor, launcher/library integrations (including Steam), and FPS/frame-time capture are not yet implemented. Session start time and elapsed duration are exposed by the `Get Game Mode` bridge response.

## Safety and platform support

The bridge is the source of truth for hardware-control capabilities. A GUI control is not proof of hardware support. On monitor-only hardware, Game Mode remains detection/monitoring only and must not claim that a fan, clock, or power optimization was applied.
