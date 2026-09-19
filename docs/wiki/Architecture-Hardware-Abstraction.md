# Hardware Abstraction

Hardware access is split by platform.

The Go bridge uses common interfaces for metrics while delegating OS-specific collection to files such as:

- `platform_metrics_windows.go`
- `platform_metrics_linux.go`
- platform-neutral collection in `main.go`

Driver information is also separated by platform.

This structure allows the dashboard protocol to remain stable even when telemetry collection differs between Windows and Linux/macOS.
