# HWcontrol2.0 Product Readiness Checklist

This document defines evidence required to call HWcontrol2.0 a dependable user-facing product. It is an acceptance checklist, not a claim that every item is already complete.

## Release usability

- [ ] Each supported OS/architecture has an explicit release target and a tested package format.
- [ ] Release notes identify new behavior, known limitations, upgrade considerations and rollback/uninstall guidance.
- [ ] Expected assets are checked before a release is described as downloadable.
- [ ] SHA-256 manifests are generated and verified against the published assets.
- [ ] Signing and notarization status is stated accurately; unsigned packages are not presented as signed.
- [ ] First-run instructions, permissions and recovery steps are understandable to non-developers.
- [ ] Broken or incomplete downloads fail clearly rather than leaving an indefinite loading state.

## Runtime safety

- [ ] Unsupported hardware paths remain monitor-only and are visibly explained.
- [ ] Hardware-control commands validate capabilities, ranges and platform permissions.
- [ ] Control failures have safe, observable error states and do not imply success.
- [ ] Conflicts with other hardware-control tools are documented.
- [ ] Logs and diagnostic exports redact credentials and provide clear consent before external sharing.
- [ ] Service installation, upgrade and removal are tested on each supported OS.

## Engineering and security

- [ ] Native engine tests and sanitizer/static-analysis checks run where supported.
- [ ] Go bridge tests cover authentication, replay protection, malformed input, permissions and shutdown.
- [ ] Flutter tests cover critical workflows, localization fallback, accessibility and error states.
- [ ] Windows, macOS and Linux package smoke tests run in CI where the runner supports them.
- [ ] Dependency/security checks are actionable and failures are fixed rather than suppressed.
- [ ] Release provenance and SBOM output are checked when configured.
- [ ] Security policy and private vulnerability reporting remain discoverable.

## User experience and accessibility

- [ ] Users can identify the active platform, application version and detected capabilities.
- [ ] Missing telemetry is distinguished from a zero reading or a healthy state.
- [ ] Installation and update errors explain the next safe action.
- [ ] Keyboard navigation, focus visibility, contrast and reduced-motion behavior are tested.
- [ ] All shipped localization catalogs pass key/placeholder validation; translations are reviewed in context.
- [ ] Documentation links, support routes and release links are checked in CI.

## Trust and product discovery

- [ ] README and website accurately describe beta status and shipped targets.
- [ ] Product, install, privacy, security and contribution guides are available.
- [ ] Search-engine sitemap contains only real deployed pages.
- [ ] External package/catalog listings are submitted only when their current rules and signing requirements are met.
- [ ] User acquisition is measured with aggregate, privacy-conscious signals rather than unnecessary behavioral tracking.
- [ ] Independent hardware reports are recorded with the exact tested configuration.

## Exit criteria

A release can be called ready for a particular platform only when the relevant build, installation, upgrade/uninstall, runtime safety and smoke-test evidence exists for that platform. A green compile alone is not proof of hardware compatibility.

Record for each release:
- tag and commit SHA;
- workflow run URLs and result;
- package names, architectures and checksums;
- signing/notarization evidence, if any;
- hardware/OS configurations actually tested;
- known limitations and unresolved blockers.

**Current product status:** Beta. This checklist must be updated using real test and release evidence; unchecked items must not be represented as completed.
