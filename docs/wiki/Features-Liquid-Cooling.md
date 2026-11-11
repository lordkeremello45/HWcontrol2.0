# Liquid Cooling

## Current status

**PARTIAL — optional read-only telemetry.** HWcontrol can query an externally installed `liquidctl` executable. The feature is not a universal AIO/custom-loop controller.

## Implemented

- Executes only `liquidctl status --json`.
- Uses a 2.5-second execution timeout and a bounded stdout size; stderr is also bounded and permission failures are reported separately.
- Parses a single JSON document and rejects malformed or trailing JSON values.
- Normalizes explicit coolant/liquid temperature, pump RPM, fan RPM, coolant flow and coolant level values with unit and range checks.
- Converts Fahrenheit coolant readings to Celsius.
- Discards device serial numbers and raw USB addresses from the public telemetry model.
- Reports independent capability states through `Get Health` and `Get Diagnostics`.
- Displays reported readings in a read-only dashboard panel. Failed refreshes retain previous readings as `stale`.

## Not implemented

- Automatic AIO versus custom-loop topology classification.
- USB initialization, pump/fan speed changes or firmware-profile takeover.
- Universal pump bounds, device-specific pump-stop policy or watchdog.
- Leak detection unless a future validated adapter exposes an explicit supported sensor.
- Reservoir level or coolant flow inference from CPU/GPU temperatures.
- Reconnect guarantees, USB-disconnect recovery or firmware-safe fallback.
- Physical AIO/custom-loop hardware validation.

## Why liquidctl was selected

The project should not reimplement the private USB protocol of every cooler or introduce a mandatory Python runtime into the core application. liquidctl already provides a machine-readable CLI status surface and supports multiple liquid-cooling controllers. The CLI documentation also warns that specific JSON keys, values and units may change; HWcontrol therefore accepts only recognized key/unit pairs and ignores unknown readings.

CoolerControl demonstrates a separate-process approach to hardware collection and device management. HWcontrol adopts only the optional read-only CLI boundary at this stage, not its daemon/device-control lifecycle.

## AIO and custom-loop separation

AIO and custom-loop devices must eventually become separate device/topology records. Their telemetry and control capabilities are not interchangeable. A custom loop may expose multiple pumps, radiators, reservoirs and flow meters; an AIO may expose only pump/fan RPM and coolant temperature. HWcontrol must report only what the device explicitly exposes.

## Safety gates before writable control

1. Identify exact vendor/product, controller firmware and supported driver.
2. Verify independent pump, radiator-fan and thermal-source mappings.
3. Read documented min/max pump bounds and supported control modes per device.
4. Define bounded ramps, command-rate limits and device-loss behavior.
5. Verify firmware fallback and recovery after app crash, bridge crash, USB disconnect, sleep/resume and permission loss.
6. Validate command readback and physical pump/fan response on actual hardware.
7. Keep controls disabled until all gates pass.

No CPU/GPU temperature may be relabeled as coolant temperature. An absent flow, level or leak sensor remains unavailable.
