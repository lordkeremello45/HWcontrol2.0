# Fan Curve Editor

HWControl provides a point-based Smart Fan Curve editor in the dashboard.

## Current behavior

- temperature/fan points can be added, edited through the point sliders, removed and reset;
- the curve is persisted locally;
- linear interpolation is used between points;
- persisted and edited curves are normalized to remain non-decreasing as temperature rises, and fan targets have a 20% minimum because zero can stop cooling;
- automatic control is capability-gated and remains disabled when the bridge reports monitor-only hardware;
- the controller applies smoothing, a minimum fan floor, a minimum target delta and a minimum command interval;
- invalid or missing thermal telemetry resets the controller and fails closed;
- at critical temperatures (95 °C and above), automatic control requests a 100% emergency fan target instead of following the normal curve; the bridge rejects lower fan targets during that state;
- emergency cooling remains latched until every available valid CPU/GPU temperature is below 92 °C;
- missing/invalid thermal telemetry and unsupported backends still fail closed.

## Backend support

The GUI does not imply hardware support. The bridge exposes fanControlSupported and fanControlBackend from the native/platform backend.

Linux currently has a conservative hwmon backend. Automatic discovery is enabled only when exactly one writable PWM target has a matching fan input; ambiguous systems must explicitly set HWCONTROL_HWMON_PWM.

Windows and macOS remain monitor-only until a validated vendor/EC backend is available for the target hardware matrix.

## Safety boundary

Fan commands remain HMAC-authenticated, range-validated and fail-closed at the bridge boundary. The application never treats missing temperature telemetry as safe.
