# HWcontrol2.0 Beta Quickstart

HWcontrol2.0 is beta software. Hardware support differs by operating system, device, driver and firmware. Read this guide before installing or testing hardware-control features.

## 1. Choose a release

Use the [official GitHub Releases page](https://github.com/lordkeremello45/HWcontrol2.0/releases) or the [project website](https://lordkeremello45.github.io/HWcontrol2.0/).

- Windows: Windows 10/11 x64. The guided EXE is intended for typical installation; MSI and MSIX are alternative deployment formats, and portable ZIP is available when included in the release.
- macOS: macOS 14+ on Apple Silicon. Intel macOS packages are not currently shipped.
- Linux: Debian/Ubuntu-family x64. Choose the DEB or a portable TAR package when the release includes it.

A release tag does not guarantee that every package is present. Check the asset list on the release page before downloading.

## 2. Verify the downloaded artifact

If the release provides a SHA-256 manifest, calculate the file digest locally and compare it with the published value.

PowerShell:

    Get-FileHash .\\<downloaded-file> -Algorithm SHA256

Linux:

    sha256sum ./<downloaded-file>

macOS:

    shasum -a 256 ./<downloaded-file>

Replace the placeholder with the actual downloaded filename. A matching hash shows that the file matches the published digest; it does not identify the publisher or replace trusted code signing. Do not claim that a package is signed unless the operating system and release provide verifiable signing evidence.

## 3. Install conservatively

### Windows

Use the official release asset and review the installer prompts. Do not disable SmartScreen or other Windows security controls just to force a package to run. If publisher identity cannot be verified, treat that as a real trust limitation rather than assuming the package is signed.

### macOS

Use only the Apple Silicon build for the documented target. If macOS cannot verify the developer or package, do not bypass Gatekeeper solely to continue; first confirm the artifact and signing status from the official release information.

### Debian/Ubuntu-family Linux

1. Download the HWControl-<release-tag>-Linux-x64.deb asset from the official [GitHub Releases page](https://github.com/lordkeremello45/HWcontrol2.0/releases).
2. Open a terminal in the directory containing the downloaded file and install it using its exact filename:

       sudo apt install ./HWControl-<release-tag>-Linux-x64.deb

   Replace <release-tag> with the tag shown on the release page. For example, a unified tag named v0.3.1-beta.42 produces an asset named HWControl-v0.3.1-beta.42-Linux-x64.deb. The ./ prefix tells APT to install a local package file and resolve its dependencies.
3. The product/display name is HWcontrol2.0. The Debian package name and terminal launcher are both `hwcontrol`, so commands use the short name rather than `hwcontrol2.0`. Installing a local DEB file does not automatically configure an APT repository; until the official APT repository is published, use the local-file command above. Once the repository is live, its official setup instructions will provide the repository and signing-key configuration before `sudo apt install hwcontrol` is used.
4. To remove the installed package, run:

       sudo apt remove hwcontrol

   Use sudo apt purge hwcontrol only if you intentionally want the package's purge script to remove its /var/lib/hwcontrol state. Review the release-specific cleanup instructions before removing application state.

A portable archive is not interchangeable with a DEB package. Review any dependency or permission prompts before confirming.

## 4. First-run checklist

1. Record the HWcontrol2.0 release/tag and OS version.
2. Confirm the dashboard can communicate with the local bridge.
3. Review detected hardware and capability states.
4. Start with monitoring; only test control features explicitly reported as supported.
5. Stop testing if fan behavior, temperatures or system stability become abnormal.
6. Do not run multiple fan-control utilities against the same controller at once.

A control panel being visible does not prove that the current hardware backend can safely apply changes.

## 5. Report a useful issue

Search [existing issues](https://github.com/lordkeremello45/HWcontrol2.0/issues) before opening a new one. Include:

- OS and version, CPU architecture and HWcontrol2.0 version;
- device model and relevant driver/kernel/firmware details;
- expected behavior, actual behavior and reproduction steps;
- relevant logs after removing secrets and personal information.

Never attach passwords, API keys, bridge authentication material, signing credentials, private tokens or unredacted diagnostic exports. Use the repository's private security-reporting path for vulnerabilities rather than a public issue.

## 6. What to expect

HWcontrol2.0 is still in beta. Some hardware may be monitor-only, some readings may be unavailable, and package availability can vary by release. Report reproducible results rather than assuming support based on another machine's behavior.

- [Official releases](https://github.com/lordkeremello45/HWcontrol2.0/releases)
- [Project website](https://lordkeremello45.github.io/HWcontrol2.0/)
- [Security policy](../SECURITY.md)
- [Contribution guide](../CONTRIBUTING.md)
