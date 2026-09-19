# Repository Structure

```text
HWcontrol2.0/
├── ai_core/               # native C++ / AI runtime
├── bridge_service/        # Go bridge
├── gui_dashboard/         # Flutter UI
├── deploy/                # platform service/installer assets
├── installer/             # installer entry scripts and docs
├── website/               # GitHub Pages website
├── updates/               # update/release manifest
├── docs/                  # project security/release documentation
└── .github/workflows/     # CI/CD
```

The release pipeline intentionally keeps large binaries in GitHub Releases instead of committing them to the main source tree.
