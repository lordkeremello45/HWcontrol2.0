# HWControl 2026-09 all-in-one hotfix

This recovery line consolidates the missing release/web and GPU compatibility work identified from PRs #2 and #3, while retaining the installer and release-integrity fixes already present on `main`.

## Included

- GPU driver compatibility policy: full features, safe mode, or monitor-only based on driver status.
- Release metadata manifest for GitHub Pages.
- Manifest-first website download selector with GitHub Releases API fallback.
- Website validation and Pages pre-deploy validation.
- Release-to-web metadata synchronization after release integrity / Windows Setup publication.
- Windows 11-style and two-tone Linux platform icons.

Release binaries remain GitHub Release assets; the website stores metadata only.
