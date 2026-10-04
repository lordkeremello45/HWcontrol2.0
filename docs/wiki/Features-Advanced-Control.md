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

Linux currently has a conservative single-target hwmon PWM backend. Windows and macOS vendor/EC control remain unavailable until validated against real hardware.
