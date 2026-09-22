# HWcontrol2.0 Release Checklist

## Source
- [ ] Release version and changelog are correct.
- [ ] Source revision is tagged.
- [ ] CI/build scripts are part of the reviewed source change.
- [ ] No secrets, credentials, private keys, or local paths are committed.

## Tests
- [ ] C++ build passes.
- [ ] C++ tests pass.
- [ ] Go tests pass.
- [ ] Flutter analyze passes.
- [ ] Flutter tests pass.
- [ ] Platform package validation passes for every advertised release target.

## Packaging
- [ ] Windows Setup.exe/MSI/portable package validated.
- [ ] macOS PKG/DMG/app validated where applicable.
- [ ] Linux package/archive validated where applicable.
- [ ] Install and uninstall/cleanup checks pass.

## Security and provenance
- [ ] SBOM generated.
- [ ] Checksums generated and verified.
- [ ] GitHub Actions provenance/attestation generated where supported.
- [ ] Release artifacts originate from the tagged repository revision.
- [ ] Signing state is accurately described.
- [ ] If SignPath signing is active, the trusted build/origin policy passed.
- [ ] Authenticode signature is independently verified before calling a Windows artifact signed.

## Publication
- [ ] GitHub Release contains source links, release notes, artifacts, checksums, and provenance information.
- [ ] Documentation reflects the actual release state.
- [ ] Known limitations and unsupported hardware-control paths are documented.
- [ ] No claim of hardware support is made without backend validation.

## Post-release
- [ ] Download links work.
- [ ] Checksums match the published artifacts.
- [ ] Signature verification succeeds when signing is enabled.
- [ ] Installation and launch smoke tests are recorded.
- [ ] Issues discovered after release are tracked publicly.
