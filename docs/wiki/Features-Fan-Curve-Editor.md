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
- at critical temperatures (95 °C and above), emergency cooling requests a 100% fan target independently of the normal Smart Fan toggle; it stays latched until available valid CPU/GPU temperatures fall below 92 °C, and the bridge rejects lower fan targets while critical;
- emergency cooling remains latched until every available valid CPU/GPU temperature is below 92 °C;
- missing/invalid thermal telemetry and unsupported backends still fail closed.

## Backend support

The GUI does not imply hardware support. The bridge exposes fanControlSupported and fanControlBackend from the native/platform backend.

Linux exposes independently enumerated hwmon PWM channels. Each channel is reported separately with its backend, RPM feedback, current PWM percentage, writable/manual-mode status and a reason when it remains monitor-only. The bridge only permits per-channel writes when the channel has a matching fanN_input RPM sensor, is writable, and pwmN_enable already reports manual mode (1); the application does not switch a controller out of firmware automatic mode automatically.

When multiple channels are available, the legacy global fan slider remains disabled and users control channels individually. Each channel can save its own curve, select CPU temperature, GPU temperature or the hottest valid CPU/GPU reading, enable/disable automatic curve evaluation, and save a manual target. Channel controls remain subject to the same thermal, authentication and fail-closed checks.

Optional Linux target selection: HWCONTROL_HWMON_PWM restricts discovery to one absolute path under /sys/class/hwmon; HWCONTROL_HWMON_PWMS accepts a comma-separated list of such paths. These settings only select candidates; they do not bypass the RPM, writability or manual-mode checks.

Windows and macOS remain monitor-only until validated vendor/EC per-channel adapters are available for the target hardware matrix.

## Safety boundary

Fan commands remain HMAC-authenticated, range-validated and fail-closed at the bridge boundary. The application never treats missing temperature telemetry as safe.
