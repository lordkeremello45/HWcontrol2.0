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

The web app reads `website/release.json` first. It falls back to the GitHub Releases API when the manifest is unavailable or invalid, so a first-time deployment is not blocked by the absence of generated metadata.

## Why binaries are not committed

Release packages remain release assets. Large MSI, DMG, DEB, ZIP and archive files are not mirrored into the Git repository. The generated manifest contains only release URLs, names, sizes and checksum links.

## Update behavior

`release-web-sync.yml` is triggered after successful `Release integrity` or `Publish Windows Setup bootstrapper` runs. Both triggers are intentional because Windows Setup is published asynchronously after the platform release is created.

The workflow always re-reads the current stable releases from GitHub before generating the manifest. This means a later Windows Setup completion can update the manifest without requiring a second manual release.

## Validation

`website-validation.yml` validates JavaScript, the Python manifest generator and the manifest schema on pull requests. `pages.yml` repeats the relevant checks immediately before deployment.

The manifest uses schema version `1`. Changes to its structure should update both the generator and `scripts/website-release-test.mjs` in the same pull request.
