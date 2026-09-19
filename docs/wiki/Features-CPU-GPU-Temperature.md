# CPU & GPU Temperature

## CPU temperature

The bridge first uses platform sensor information where available and identifies CPU/package/core temperature entries.

## GPU temperature

### NVIDIA

The bridge can use `nvidia-smi` for GPU name, driver, temperature, usage, fan percentage, power, voltage, memory and clock data.

### AMD on Linux

The Linux backend can use the kernel `amdgpu` sysfs interfaces for GPU telemetry.

### Windows

The Windows backend can use LibreHardwareMonitor WMI sensor data and a Windows WMI fallback.

## Dashboard

The dashboard displays:

- current CPU temperature;
- CPU usage;
- GPU usage;
- a temperature history graph;
- a configurable warning threshold.

The application should be treated as a monitoring/control tool, not as a replacement for firmware, OS, driver or hardware safety mechanisms.
