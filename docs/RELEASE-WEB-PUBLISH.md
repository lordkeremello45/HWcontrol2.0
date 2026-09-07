# Release → Web publishing

HWControl keeps release binaries in GitHub Releases and publishes only a small metadata manifest to the GitHub Pages site.

## Flow

```text
platform tag
    │
    ▼
Publish platform release
    │
    ├── packages
    └── artifact attestations
    │
    ├───────────────┐
    ▼               ▼
Release integrity   Windows Setup bootstrapper
    │               │
    └───────┬───────┘
            ▼
   Sync release metadata
            │
            ▼
   website/release.json
            │
            ▼
       Deploy website
            │
            ▼
        GitHub Pages
```

The web app reads `website/release.json` first. It falls back to the GitHub Releases API when the manifest is unavailable or invalid.

## Why binaries are not committed

Release packages remain release assets. Large MSI, DMG, DEB, ZIP and archive files are not mirrored into the Git repository. The generated manifest contains only release URLs, names, sizes and checksum links.

## Update behavior

`release-web-sync.yml` is triggered after successful `Release integrity` or `Publish Windows Setup bootstrapper` runs. The workflow re-reads the current stable releases before generating the manifest.

The manifest generator is deterministic: it records release publication metadata but no generation timestamp, preventing needless commits when the release set has not changed.

## Validation

`website-validation.yml` validates JavaScript, the Python manifest generator and the manifest schema. The Pages workflow validates the manifest integration before deployment.

The manifest uses schema version `1`. Changes to its structure should update both the generator and `scripts/website-release-test.mjs` together.
