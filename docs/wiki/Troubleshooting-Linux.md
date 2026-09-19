# Troubleshooting — Linux

## GPU metrics missing

Check the GPU driver and relevant Linux interfaces.

For AMD, HWControl can use `amdgpu` sysfs telemetry.

For NVIDIA, the bridge can use `nvidia-smi`.

## Service not running

Check the `hwcontrol-bridge.service` unit and systemd status.

## Package selection

The installer only selects package formats that exist in the published release. A distribution may therefore receive a portable archive rather than a native package.
