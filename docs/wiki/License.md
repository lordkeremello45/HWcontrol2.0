# License

HWcontrol2.0 uses component-scoped licensing rather than applying every license to the entire repository.

## Desktop application

The repository root and the HWcontrol2.0 desktop application are licensed under **GNU GPLv3**. The authoritative license text is the repository-root [LICENSE](https://github.com/lordkeremello45/HWcontrol2.0/blob/main/LICENSE) file.

## Website

The source code under `website/` is separately licensed under **GNU AGPLv3-only (AGPL-3.0-only)**. See the repository [website/LICENSE](https://github.com/lordkeremello45/HWcontrol2.0/blob/main/website/LICENSE).

AGPLv3 is selected for the website source because it is designed for network-interactive software and extends copyleft obligations to covered network use. It is a licensing condition, not a substitute for web security controls.

## Local security tooling

The standalone tooling under `security/local-audit/` is separately licensed under **Apache License 2.0 (Apache-2.0)**. This scope is intended for reusable, offline security and integrity tooling that can be independently tested, integrated, and contributed to without changing the GPLv3 desktop application's license.

Apache-2.0 provides an explicit contributor patent grant and permissive reuse terms. It is compatible with inclusion in GPLv3 projects, but GPLv3-covered code is not being relicensed under Apache-2.0. The Apache scope is limited to files that explicitly identify `Apache-2.0`.

The license text is available in the repository [LICENSE-APACHE](https://github.com/lordkeremello45/HWcontrol2.0/blob/main/LICENSE-APACHE); the component also carries its own NOTICE and license pointer. Apache-2.0 is a licensing choice, not a technical security control.

## Third-party components

Third-party dependencies and bundled components retain their own licenses. See the repository [THIRD_PARTY_NOTICES.md](https://github.com/lordkeremello45/HWcontrol2.0/blob/main/THIRD_PARTY_NOTICES.md) and the dependency manifests for applicable terms.

This document is informational. The applicable license text and component-specific notices are authoritative.
