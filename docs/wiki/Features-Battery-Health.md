# Battery Health and Capacity

**Status: IMPLEMENTED in source; runtime hardware validation pending.**

The dashboard includes a read-only battery health panel. The bridge reports the capacity metadata exposed by the operating system and battery controller:

- Design capacity
- Current full-charge capacity
- Estimated capacity health: full-charge capacity / design capacity × 100
- Estimated capacity loss when full-charge capacity is below design capacity
- Charge-cycle count when the platform exposes it
- Current charging state when available

## Platform collection

- **Linux:** reads `/sys/class/power_supply/BAT*`, preferring energy capacity (reported as mWh) and falling back to charge capacity (reported as mAh).
- **Windows:** reads the Windows WMI battery classes through a bounded PowerShell subprocess. The collector has a five-second timeout and does not collect serial numbers.
- **macOS:** reads `AppleSmartBattery` metadata through a bounded `ioreg` subprocess. Capacity values retain the matching units reported by that interface.

The bridge returns unavailable data when capacity values are absent, invalid, or unsupported. The UI must not infer a battery is unhealthy merely because a platform does not expose these fields.

## Interpretation and limitations

The health percentage is an estimate based on reported capacity, not a battery-runtime prediction or a guarantee of remaining service life. Firmware may report inaccurate, stale, or recalibrated values; health can temporarily exceed 100% when the reported full-charge capacity exceeds the design estimate. Cycle counts are optional and depend on firmware and OS support. The displayed health color bands are indicative UI guidance, not manufacturer service thresholds.

This feature is read-only. It does not change charging limits, battery settings, firmware, or power profiles. No battery data is uploaded as telemetry.

## Validation still required

- Run Go unit tests and cross-compile the bridge for Windows, Linux, and macOS.
- Exercise the packaged application on physical laptops from each supported OS.
- Confirm that missing battery telemetry renders as unavailable without blocking dashboard startup.
