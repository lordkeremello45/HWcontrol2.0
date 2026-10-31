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

The package name and terminal launcher are both `hwcontrol`.

**If the signed APT repository is live** (the official website publishes the signed `InRelease` index), download and inspect the setup script, then register the repository:

    curl --fail --location --proto '=https' --tlsv1.2 \
      https://raw.githubusercontent.com/lordkeremello45/HWcontrol2.0/main/scripts/setup-apt-repository.sh \
      --output setup-hwcontrol-apt.sh
    less setup-hwcontrol-apt.sh
    sudo bash setup-hwcontrol-apt.sh
    sudo apt update && sudo apt install hwcontrol

The setup script verifies the pinned APT signing-key fingerprint before adding the repository. Do not bypass a fingerprint mismatch or install from an unverified mirror.

**If the APT repository is not yet published**, install the exact DEB asset from the official [GitHub Releases page](https://github.com/lordkeremello45/HWcontrol2.0/releases):

    sudo apt install ./HWControl-<release-tag>-Linux-x64.deb

Replace <release-tag> with the tag shown on the release page. Installing a local DEB does not configure the APT repository.

To remove the installed package, run:

    sudo apt remove hwcontrol

Use `sudo apt purge hwcontrol` only if you intentionally want the package's purge script to remove its `/var/lib/hwcontrol` state. Review the release-specific cleanup instructions before removing application state.

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
