# FAQ

## Is HWControl 2.0 cross-platform?

The release pipeline targets Windows, macOS and Linux. Current macOS packages target Apple Silicon, while Windows and Linux releases are x64.

## Does SHA-256 mean the application is code-signed?

No. SHA-256 verifies artifact integrity. It does not establish publisher identity.

## Is SignPath currently active?

The repository currently has SignPath policy documentation but no active SignPath GitHub Actions signing integration.

## Does Game Mode automatically detect games?

Not currently. The current feature is a named Game preset.

## Is there a full fan-curve editor?

Not currently. Fan control is profile/slider based in the current UI.

## Where are release installers stored?

GitHub Release assets. The source repository intentionally avoids committing large binary installers.
