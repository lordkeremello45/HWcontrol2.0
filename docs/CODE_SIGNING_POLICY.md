# Code Signing Policy

HWControl 2.0 uses code signing to improve release authenticity and end-user trust.

## SignPath Foundation

**Free code signing provided by SignPath.io, certificate by SignPath Foundation.**

The project intends to use SignPath Foundation code signing for eligible Windows release artifacts after acceptance into the SignPath Foundation Open Source Code Signing program.

Until a signing request has been completed and the resulting artifact has been independently verified, a release must not be described as signed.

## Scope

The SignPath signing scope is limited to artifacts built from this repository's own source code and release build scripts. The initial target is the Windows release line, including:

- `Setup.exe` guided installer
- Windows `.msi` installer
- Windows portable `.exe` binaries where applicable

Unsigned third-party binaries may only be included where their redistribution is permitted and they are not represented as project-signed binaries.

## Source and build provenance

- Repository: https://github.com/lordkeremello45/HWcontrol2.0
- Release branch: `main`
- Build system: GitHub Actions on GitHub-hosted runners
- Release artifacts are produced by workflows stored in this repository.
- Build scripts and CI configuration are part of the reviewed source/build surface.
- Signing must use artifacts produced by the corresponding GitHub Actions build rather than manually uploaded local binaries.

## Roles

### Committers and reviewers

- `lordkeremello45` — project maintainer, committer and reviewer

Changes proposed by contributors who are not project committers must be reviewed before being included in a signing build.

### Approver

- `lordkeremello45` — release signing approver

The approver is responsible for confirming that the release corresponds to the intended source revision, passed the project's release validation, and is suitable for publication.

## Release signing procedure

1. Build the release from the repository using GitHub Actions.
2. Run the project's platform and release-integrity validation.
3. Upload the unsigned release artifact to the GitHub Actions workflow artifact store.
4. Submit the artifact to SignPath using the configured trusted GitHub build system and origin verification.
5. Manually approve release signing when the configured SignPath policy requires approval.
6. Publish the resulting signed artifact to the official GitHub Release.
7. Verify the Authenticode signature and publisher information before describing the artifact as signed.
8. Publish the corresponding checksums and release provenance information.

A failed or unverifiable signing request must never be treated as a successful release signature.

## Artifact metadata

Signed artifacts must use consistent product metadata:

- Product name: `HWControl`
- Product version: the exact release version for that build
- Publisher/signing identity: the identity shown by the resulting certificate

## Security requirements

- GitHub and SignPath accounts used for signing must have multi-factor authentication enabled.
- SignPath API tokens and signing credentials must never be committed to the repository.
- Release signing must occur only through the protected CI workflow.
- Signing must not be used to distribute unrelated third-party software.
- Build scripts must remain reviewable and version-controlled.

## Privacy

HWControl follows a local-first telemetry model. The application does not intentionally collect or transmit unnecessary telemetry, usage analytics, advertising identifiers, or behavioral tracking data. Hardware and system monitoring data remains local unless the user explicitly exports or shares it. Update checking uses HTTPS requests to the allowlisted GitHub release infrastructure.

For the full security and privacy description, see [`SECURITY.md`](../SECURITY.md).

## Verification

Users should verify that a signed Windows artifact has a valid Authenticode signature and that the signer matches the publisher identity presented by the release documentation. Checksums remain useful for integrity verification but do not replace code-signing verification.

## Policy status

Current status: **SignPath Foundation application / signing integration preparation**.

The project is not considered signed until SignPath acceptance, CI integration, and successful signature verification are complete.
