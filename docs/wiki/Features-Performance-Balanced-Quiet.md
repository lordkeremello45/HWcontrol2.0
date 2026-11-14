# Performance / Balanced / Quiet

The dashboard provides named presets that map to fan and AI-processing target values.

| Preset | Fan | AI |
|---|---:|---:|
| Quiet / Sessiz | 25% | 45% |
| Balanced / Dengeli | 50% | 80% |
| Performance / Performans | 85% | 100% |
| Game / Oyun | 75% | 95% |
| Manual / Manuel | Current values | Current values |

Presets update the dashboard controls and then attempt to send the corresponding bridge commands.

## Important implementation note

The current bridge source returns an error when the hardware-control backend is unavailable. Therefore preset selection does not guarantee that a physical fan or power-control operation occurred on every build or machine.

## Operating-system performance modes

These app-level presets do not automatically change the operating system power mode. Separate configured-mode adapters are implemented for Windows 11 AC/DC and Linux power-profiles-daemon, but platform runtime validation is pending; Windows 10 and macOS automatic switching are unavailable. Use Performance Lab for those separate controls. See [Performance Mode](Features-Performance-Mode.md) for platform limits.


OS power profiles are managed separately in Performance Lab. The Go bridge contains configured-mode adapters for Windows 11 AC/DC and Linux power-profiles-daemon; macOS automatic switching and Windows 10 support are unavailable. Adapter runtime validation is pending. See [Performance Mode](Features-Performance-Mode.md).
