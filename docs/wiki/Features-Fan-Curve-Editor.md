# Fan Curve Editor

## Current status

A full point-based fan-curve editor is **not yet implemented** in the current repository.

What exists today is profile-based fan control:

- a Fan Hızı slider from 0–100%;
- named presets;
- a saved Manual profile;
- a bridge command path for `Fan Hızı`.

The UI therefore supports controlled fan target values where the backend implements the operation, but it does not yet expose a graph with temperature → fan-speed curve points.

## Planned direction

A future curve editor can build on the existing profile mechanism with:

- temperature/fan control points;
- interpolation;
- minimum/maximum fan bounds;
- hysteresis;
- apply/revert;
- per-device profiles.

Until that is implemented, documentation should refer to the feature as profile-based fan control rather than a completed fan-curve editor.
