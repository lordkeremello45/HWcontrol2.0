# CPU & GPU Temperature

## CPU temperature

The bridge first uses platform sensor information where available and identifies CPU/package/core temperature entries.

## GPU temperature and telemetry

### NVIDIA

The Go bridge can use `nvidia-smi` to collect GPU name, driver, temperature, utilization, fan percentage, power, voltage, memory and clock data when the NVIDIA driver exposes those fields. This is a telemetry path; it is separate from CUDA compute acceleration.

If `nvidia-smi` is missing, inaccessible, or the driver does not expose a field, that metric may be unavailable. HWcontrol must not invent values or treat missing telemetry as a verified sensor reading. Fan control remains subject to the platform's separately detected capabilities and safety checks.

### AMD on Linux

The Linux backend can use the kernel `amdgpu` sysfs interfaces for GPU telemetry.

### Windows

The Windows backend can use LibreHardwareMonitor WMI sensor data and a Windows WMI fallback.

## Optional CUDA acceleration for local AI

The native CMake build now has an opt-in `HWCONTROL_ENABLE_CUDA` option for the bundled `llama.cpp` dependency. It defaults to `OFF` to preserve the existing CPU/default cross-platform build behavior. On a supported NVIDIA development machine with a compatible CUDA toolkit and compiler installed, configure with:

```bash
cmake -S . -B build-cuda -DHWCONTROL_ENABLE_CUDA=ON
cmake --build build-cuda --config Release
```

This enables a CUDA-capable build of the local AI engine where the pinned `llama.cpp` revision and installed toolchain support it. It does not mean CUDA acceleration is enabled in standard release builds, that a model is bundled, or that every NVIDIA GPU/toolkit combination has been tested. CUDA telemetry and CUDA compute are distinct capabilities.

## Dashboard

The dashboard displays:

- current CPU temperature;
- CPU usage;
- GPU usage;
- a temperature history graph;
- a configurable warning threshold.

The application should be treated as a monitoring/control tool, not as a replacement for firmware, OS, driver or hardware safety mechanisms.
