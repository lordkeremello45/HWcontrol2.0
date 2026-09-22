# Telemetry History and Thermal Detection

HWControl keeps a bounded in-memory telemetry history in the dashboard.

## History

- Sampling interval: approximately 5 seconds while the bridge is connected.
- Retention: 720 samples (approximately one hour).
- Recorded signals include CPU/GPU temperature, CPU usage/frequency, GPU usage/core clock/power/VRAM usage, fan, RAM and disk usage.
- The dashboard renders CPU temperature, GPU temperature and CPU utilization history.
- History can be exported locally as CSV.
- Diagnostic ZIP reports include the collected telemetry samples.

No telemetry is uploaded automatically.

## Deterministic thermal detection

The dashboard evaluates the local telemetry stream before sending a snapshot to the local LLM.

Thermal throttling is marked as **suspected**, not proven, when:

- CPU temperature is at least 85 °C,
- CPU utilization is at least 85%, and
- observed CPU frequency drops by at least 15% between samples;

or:

- GPU temperature is at least 80 °C,
- GPU utilization is at least 80%, and
- observed GPU core clock drops by at least 15% between samples.

Higher temperatures and rapid temperature rises are also surfaced as deterministic warnings.

The detector does not change fan speed, clocks, voltage, power limits or other hardware settings. It is an observation layer only.

## AI integration

The current thermal state is included in the telemetry context sent to the local Gemma analysis process. The LLM remains an explanation layer; deterministic telemetry and hardware capability state remain authoritative.
