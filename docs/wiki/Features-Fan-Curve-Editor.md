# Fan Curve Editor

## Current status

**IMPLEMENTED:** HWcontrol2.0 provides a point-based fan-curve editor with local persistence and linear interpolation.

The curve is defined by temperature/fan pairs and can be saved as the default curve.

## Safety boundary

The GUI can configure and evaluate a curve even when a platform is monitor-only. Automatic fan actuation is only attempted when the bridge reports a validated writable hardware-control backend and valid thermal telemetry.

Unsupported hardware remains monitor-only.

## Example

| Temperature | Fan |
|---:|---:|
| 40 °C | 25% |
| 55 °C | 35% |
| 65 °C | 50% |
| 75 °C | 65% |
| 85 °C | 80% |
| 92 °C | 100% |
