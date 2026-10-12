# Game Mode

Game Mode provides a conservative game-session detection and monitoring layer.

## Behavior

- Can be armed from the dashboard.
- Automatically scans running processes for known game executables.
- Reports the detected process name and PID through the authenticated bridge.
- Preserves the session start timestamp while the same process name and PID remain detected.
- Starts a new session when the detected PID changes and clears the timestamp when no allow-listed game is found.
- Includes Game Mode state in diagnostics.
- Does not change clocks, voltage, power limits, process priority, or terminate background processes.
- Hardware actions remain disabled unless a platform backend has been validated and explicitly reports support.

## Detection limitations

Detection uses a conservative executable allow-list. Unknown games are not automatically treated as games. Generic `javaw.exe` is intentionally not allow-listed because it is also used by non-game Java applications; Minecraft Java Edition may therefore require a future explicit, user-configurable executable rule.

The detector reports one matching process at a time and does not yet provide per-game profile persistence, user-defined game registration, launcher/library integrations, or FPS/frame-time capture.

## Safety and platform support

The bridge is the source of truth for hardware-control capabilities. A GUI control is not proof of hardware support. On monitor-only hardware, Game Mode remains detection/monitoring only and must not claim that a fan, clock, or power optimization was applied.
