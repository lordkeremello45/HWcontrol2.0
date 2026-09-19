# Game Mode

## Current status

The dashboard currently provides an **Oyun / Game** preset with the following targets:

- fan: 75%
- AI processing: 95%

The preset is implemented through the same profile/command path as the other presets.

## Not a process optimizer yet

The current source does not implement a full game-process detection/priority/overlay scheduler. The term Game Mode therefore refers to the available preset rather than a complete game orchestration subsystem.

Future work can add process detection, automatic activation, restore-on-exit and per-game profiles.
