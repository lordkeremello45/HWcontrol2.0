# Game Mode

Game Mode provides a safe game-session detection layer.

## Behavior

- Can be armed from the dashboard.
- Automatically scans running processes for known game executables.
- Reports the detected game process and PID.
- Exposes Game Mode state through the authenticated bridge.
- Includes the state in diagnostics.
- Does not force fan, clock, voltage, power-limit, or process-priority changes.

## Safety

The current native hardware-control backend is monitor-only. Therefore Game Mode never pretends to apply a fan/clock optimization when the platform does not expose a validated control backend.

When hardware control is implemented for a platform, Game Mode can use this state as the trigger for a platform-specific performance policy.

## Detection

The detector uses a conservative executable allow-list. Unknown games are not automatically treated as games.

Status values distinguish:

- Game Mode armed
- game process detected
- monitoring-only operation

This design avoids unsafe automatic hardware changes while establishing the foundation for platform-specific gaming optimization.
