# Linux Packages

## Beta release assets

- Debian/Ubuntu: DEB package.
- Portable x64: TAR.GZ, TAR.ZST and ZIP archives.

The smoke test installs the DEB, waits for the bridge Unix socket (up to 30 seconds), checks the service and socket, and removes the package. If readiness times out, the workflow prints systemd status and journal logs.

## Distribution distinctions

- APT is a repository distribution mechanism, not a `.apt` file extension. The repository consists of signed metadata and DEB packages.
- Generic `.tar.zst` is a portable archive, not an Arch package.
- Native Arch packaging requires a correctly structured `.pkg.tar.zst` package; it is **not currently produced** by this beta workflow.
- Native RPM packaging is also separate and must not be inferred from a portable archive.

The installer should select only assets actually published in the release. Do not label a portable archive as a native distro package.
