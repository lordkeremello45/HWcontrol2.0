# Healthy Core — CPU/GPU condition assessment

Healthy Core is an observation-only first implementation for HWcontrol2.0. It provides a conservative **condition index** from evidence the application already knows about. It does **not** claim to measure physical silicon wear, degradation percentage, or remaining useful life.

## Current implementation

The deterministic Go package is at `bridge_service/healthycore`. The Flutter dashboard now includes a Healthy Core card that summarizes the existing bounded local telemetry history (up to 720 samples) for CPU and GPU, and only shows a score after at least 12 valid temperature samples for that device. The dashboard score is explicitly a thermal-condition indicator, not wear. The Go package accepts a device kind, sample count, maximum observed temperature plus a device-specific thermal limit, thermal-throttling event count, observed hardware/driver error count, and an optional trusted vendor health percentage.

- No usable evidence returns `condition_index: null` and `insufficient_data`, never a fabricated 100/100.
- Temperature is evaluated only when a device-specific thermal limit is supplied.
- Thermal stress, throttling events, and observed errors lower the condition index through documented, bounded penalties.
- Vendor health is optional and must originate from a trusted device-specific source; it is not inferred.
- Inputs are validated for impossible counts, non-finite values, and invalid ranges.
- The result includes evidence summaries, confidence, status, and explicit limitations.
- The module never changes clocks, voltages, power limits, fan settings, or other hardware controls.

## Interpretation

The index is an initial operational risk indicator, not a scientific estimate of wear. A score such as 92 means the current rule set found few concerning signals in the supplied evidence; it does not mean the CPU/GPU is “92% unworn.” Status bands are `no_obvious_concern` (85–100), `needs_attention` (65–84), and `elevated_risk` (0–64). These are conservative product heuristics, not manufacturer-certified thresholds.

## Validation

Run from the repository root:

```sh
cd bridge_service
go test ./healthycore
```

## Remaining integration work

This package is a tested calculation boundary, not yet a live dashboard feature. The next integration slice must connect real telemetry and trustworthy error/throttle signals to this API, persist a privacy-conscious local history, expose results in Flutter, and verify platform-specific sensor availability. Do not populate the score with synthetic/sample values or present missing data as healthy. Longer-term wear/lifetime estimation requires validated device-specific models and independent calibration data.
