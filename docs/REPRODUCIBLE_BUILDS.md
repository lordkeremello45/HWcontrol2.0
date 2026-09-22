# Reproducible Builds and Release Provenance

HWcontrol2.0 treats release provenance as part of the product.

## Source of truth
Source repository:
https://github.com/lordkeremello45/HWcontrol2.0

Release build definitions are version-controlled under .github/workflows/ and platform packaging definitions are under deploy/ and the repository build files.

## Build rules
Release artifacts must be produced by GitHub Actions from a repository revision. Manual local binaries must not be substituted for release artifacts.

The release pipeline should keep these properties visible and reviewable:
- exact Git commit/tag
- workflow and job URL
- runner operating system
- dependency versions where pinned
- build configuration
- test results
- generated SBOM
- artifact checksums
- GitHub artifact provenance/attestation where supported

## Reproduction
A contributor should be able to check out the tagged source revision and run the platform-specific build commands documented in CONTRIBUTING.md and the Wiki. Differences caused by platform SDKs, compilers, signing services, or package timestamps must be documented rather than hidden.

## SignPath readiness
For future SignPath Open Source Code Signing integration, the release signing request must originate from a trusted GitHub-hosted build. The signing workflow must not accept arbitrary local uploads.

Official references:
https://docs.signpath.io/trusted-build-systems/github
https://docs.signpath.io/origin-verification/

## Verification chain
Source commit/tag
  -> GitHub Actions
  -> build + tests + package validation
  -> SBOM + provenance + checksum
  -> trusted signing integration
  -> signature verification
  -> GitHub Release

No stage should be described as verified until its workflow result or artifact inspection proves it.
