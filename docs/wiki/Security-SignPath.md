# SignPath

## Current status

The repository contains SignPath-related policy documentation, but the public workflow configuration currently does **not** contain an active SignPath GitHub Actions submission integration.

No active references were found for the expected SignPath token/organization variables or a SignPath signing action in the repository's current workflow set.

## Foundation application

The project applied to the SignPath Foundation Open Source Code Signing program. The application was not approved at the time of the review because the project did not yet demonstrate enough external public visibility signals such as community adoption and independent references.

This is a program-eligibility result, not a statement about the project's technical quality.

## Future integration

A production SignPath flow would look like:

```text
GitHub Actions build
       ↓
unsigned Windows artifact
       ↓
SignPath trusted build integration
       ↓
SignPath signing policy
       ↓
signed artifact
       ↓
Authenticode verification
       ↓
GitHub Release
```

Do not publish a release as SignPath-signed until an actual signed artifact has been generated and independently verified.
