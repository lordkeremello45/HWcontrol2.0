# Advanced Hardware Control

Advanced control consists of Smart Fan Curve, hardware automation and capability-aware Game Mode.

## Smart Fan Curve

The dashboard evaluates a persisted temperature-to-fan curve. A safety controller smooths telemetry and rate-limits commands to reduce oscillation.

## Hardware Automation

Users can create, edit, enable/disable and delete CPU/GPU temperature rules such as:

CPU temperature >= 80 °C -> fan 70%

Rules are evaluated locally. They only result in hardware commands when the bridge reports a validated fan-control backend.

## Game Mode

Game Mode may apply a predefined fan target when game detection is active, but it is also capability-gated.

## Backend support

A GUI control is not proof of hardware support. The bridge is the source of truth for fanControlSupported, fanControlBackend and thermal safety state.

Linux exposes independently discovered hwmon PWM channels with individual HMAC-authenticated targets. A channel is writable only when its matching fanN_input RPM sensor exists, pwmN_enable is already in manual mode, and the PWM path is writable. Each channel can use its own curve and CPU/GPU/hottest-valid sensor source; missing selected-sensor data pauses that channel's curve.

Windows and macOS remain monitor-only for per-channel fan control until validated vendor/EC adapters are implemented and tested against the target hardware matrix.
