# HWcontrol2.0 Local Security Audit

SPDX-License-Identifier: Apache-2.0

This standalone utility provides a local, offline integrity check for security-sensitive HWcontrol files. It is intentionally independent of the desktop runtime and has no network dependency.

## Checks

- SHA-256 digest comparison against an expected, independently trusted value.
- Missing expected hashes are reported as `UNVERIFIED` and fail by default; a calculated digest is not proof of integrity.
- `--allow-unpinned` is an explicit inventory-only mode for discovering current digests. It does not turn those entries into verified files and must not be used as a security gate.
- Missing or unreadable files.
- Symlink substitution.
- Non-regular file targets.
- Manifest paths escaping the selected audit root.
- Machine-readable JSON output for local diagnostics and CI integration.

The utility does not establish a cryptographic root of trust by itself. Use signed/provenanced release artifacts and an independently obtained manifest for a stronger trust chain.

## Example manifest

    {
      "files": [
        {"path": "bridge-service", "sha256": "<expected SHA-256>"},
        {"path": "ai_engine"}
      ]
    }

## Run locally

From the repository root:

    GO111MODULE=off go test ./security/local-audit
    GO111MODULE=off go run ./security/local-audit --root . --manifest ./security/local-audit/manifest.example.json --allow-unpinned

The example manifest has no trusted reference hashes, so `--allow-unpinned` is only for inventory collection. For verification, populate each `sha256` from an independently trusted source and omit that flag. Use `--json` for machine-readable output.

In PowerShell, set `$env:GO111MODULE = "off"` before running the same `go test` or `go run` commands.

## License scope

This utility and its accompanying documentation are separately licensed under Apache License 2.0 (Apache-2.0). It does not relicense GPLv3 desktop code, the AGPLv3-only website, or third-party dependencies.

The Apache-2.0 scope is deliberately limited to security/local-audit/.
