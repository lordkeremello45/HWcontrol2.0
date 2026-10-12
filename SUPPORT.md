# Support and User Feedback

HWcontrol2.0 is currently a Beta project. Reports about bugs, usability, hardware compatibility, documentation, localization, accessibility, and feature ideas are welcome. Clear, reproducible feedback is more useful than a general statement that something is broken.

## Choose the right channel

- **Bug report:** Open a structured [Bug report](https://github.com/lordkeremello45/HWcontrol2.0/issues/new?template=bug_report.yml). Include expected behavior, actual behavior, reproduction steps, version, operating system, and impact.
- **Feature or usability suggestion:** Open a structured [Feature request](https://github.com/lordkeremello45/HWcontrol2.0/issues/new?template=feature_request.yml). Describe the user problem before proposing a solution.
- **Existing issue:** Search [open and closed issues](https://github.com/lordkeremello45/HWcontrol2.0/issues) first. Add relevant details to an existing report instead of creating duplicates.
- **General support:** Read the [Wiki](https://github.com/lordkeremello45/HWcontrol2.0/wiki) and [Beta Quickstart](docs/USER-QUICKSTART.md), or email hwcontrolteam@outlook.com.
- **Security vulnerability:** Follow [SECURITY.md](SECURITY.md). Do not post exploit details or secrets in public issues.

## Make feedback actionable

When relevant, provide:

- HWcontrol2.0 version or commit and installation format;
- OS version and architecture;
- CPU/GPU and relevant driver or firmware versions;
- exact error text, the action that triggered it, and minimal reproduction steps;
- whether the issue is consistent, intermittent, or happened only once;
- expected versus actual behavior and how severely it affects your workflow;
- for hardware features, whether the sensor/control capability is reported as supported.

If the issue relates to performance, include the workload and how you measured the result. Avoid claims about performance gains based only on a subjective impression.

## Optional diagnostic exports and privacy

HWcontrol2.0 follows a local-first approach. The app does not automatically upload diagnostic reports. Creating a diagnostic archive is a local export, not a submission.

Before attaching or emailing any diagnostic file, inspect it and remove passwords, API keys, access tokens, bridge secrets, signing credentials, personal data, personal file paths, device serial numbers, and unrelated system information. Share only the smallest relevant excerpt. Contact details are optional; never post private contact details in a public issue.

See [PRIVACY.md](PRIVACY.md) for the project's data-handling explanation.

## What happens after you submit feedback?

Reports are reviewed for reproducibility, severity, safety, platform scope, and whether the reported behavior is implemented or planned. A report is not a promise that a feature will be implemented or that a fix has shipped. Where possible, maintainers will ask for missing details, link related reports, and record a verified resolution in the issue or release notes.

## Hardware support

Telemetry and control depend on the operating system, driver, firmware, permissions, and exposed sensor interfaces. A feature being visible in the dashboard does not mean every device supports it. Please report missing telemetry separately from an unsafe or ineffective control command.

## Project

- Repository: https://github.com/lordkeremello45/HWcontrol2.0
- Releases: https://github.com/lordkeremello45/HWcontrol2.0/releases
- Support email: hwcontrolteam@outlook.com
