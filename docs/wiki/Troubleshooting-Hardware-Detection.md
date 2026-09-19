# Troubleshooting — Hardware Detection

Hardware telemetry is not uniform across machines.

## Check the System status panel

Inspect:

- GPU adapter;
- sensor source;
- model SHA-256;
- bridge state;
- warning threshold;
- last temperature.

## Common reasons for missing fields

- unsupported sensor API;
- missing/limited GPU driver telemetry;
- vendor tooling unavailable;
- platform-specific capability not built;
- hardware-control backend unavailable.

The project should report unavailable telemetry rather than inventing values.
