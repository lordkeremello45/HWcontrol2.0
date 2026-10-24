# FreeBSD `pkg` repository status

**Status: BLOCKED / NOT PUBLISHED.**

The project currently publishes a Debian package named `hwcontrol`; that DEB is not a FreeBSD package and must never be placed in a FreeBSD repository. A real FreeBSD `pkg` repository requires a FreeBSD-built `.pkg` artifact, a tested dependency/runtime layout, repository metadata generated with `pkg repo`, and a separately managed signing key.

The current release workflow and available validation do not establish that the C++ engine, Go bridge, Flutter dashboard, service integration, and hardware APIs build and run on FreeBSD. This document intentionally does not provide a pretend install command.

Repository metadata generation is scaffolded in `scripts/build-freebsd-pkg-repository.sh`. It must run on FreeBSD with a dedicated RSA signing key and already-built `.pkg` files; it does not build HWcontrol itself or prove FreeBSD compatibility. The resulting repository has not been generated or published.

To unblock publication:
1. Add a FreeBSD CI runner/VM build for the actual application and its dependencies.
2. Fix compile/runtime failures and add install, launch, and uninstall tests on FreeBSD.
3. Produce and inspect a versioned `.pkg` artifact whose package name is `hwcontrol`.
4. Generate and sign repository metadata with `pkg repo`, publish the public key/fingerprint independently, and test a clean-client install and upgrade.
5. Only then document `pkg install hwcontrol` as supported.
