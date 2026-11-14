# Real-time Hardware Graphs

The dashboard keeps a bounded local telemetry history and renders recent hardware trends.

## Current behavior

- Telemetry is refreshed periodically while the dashboard is connected.
- CPU and GPU temperature samples are timestamped when valid values are available.
- The in-memory history is bounded to 720 samples; missing or invalid sensor values are not converted into zero readings.
- The dashboard presents recent temperature history and summary context from the available samples.
- History is local to the application; this is not a cloud telemetry or remote-monitoring service.

## Limitations

- Graph availability depends on the sensor sources exposed by the OS, driver and device.
- The current graph is not a universal multi-series chart for every metric, fan channel, voltage, clock or power sensor.
- A plotted value is telemetry, not proof that the sensor is calibrated or physically accurate.
- Physical-device validation and long-session behavior remain separate from Flutter widget tests.

See [Current Implementation Status](CURRENT-IMPLEMENTATION-STATUS.md) for the current feature and validation boundary.
