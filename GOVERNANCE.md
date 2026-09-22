# HWControl 2.0 Governance

## Project status

HWControl 2.0 is an independent open-source project maintained in public on GitHub.

Repository:
https://github.com/lordkeremello45/HWcontrol2.0

The project follows a maintainer-led model with public issues and pull requests. Technical decisions, release validation, security practices, and compatibility claims are documented in the repository.

## Maintainer

- GitHub: `lordkeremello45`
- Responsibility: project maintenance, release engineering, security response, and final release approval.

## Contributions

Contributors are encouraged to submit focused pull requests and reproducible issue reports.

Changes should:
- explain the problem being solved;
- include tests when practical;
- preserve cross-platform behavior;
- document platform limitations;
- avoid weakening security or release-integrity checks.

See [CONTRIBUTING.md](CONTRIBUTING.md).

## Review and release process

The normal release path is:

1. Source changes are proposed through GitHub.
2. Automated CI builds and tests the affected components.
3. Cross-platform package validation runs where applicable.
4. Release artifacts are generated from repository-controlled workflows.
5. Release integrity, checksums, and provenance are validated.
6. Windows publisher signing remains a separate trust layer and is only claimed after actual Authenticode verification.
7. Release notes and artifacts are published through GitHub Releases.

No generated binary is accepted as proof of a source build merely because it was built locally.

## Security governance

Security vulnerabilities should be reported privately through GitHub Security reporting. Public issues must not contain credentials, signing keys, authentication secrets, or exploit details.

See [SECURITY.md](SECURITY.md).

## Community standards

The project uses:
- a Code of Conduct;
- contribution guidelines;
- issue templates;
- pull request review;
- a public roadmap;
- release notes and changelog;
- reproducible CI workflows.

## Independence

HWControl 2.0 is not presented as affiliated with Microsoft, Apple, NVIDIA, AMD, Intel, SignPath, or any other hardware/software vendor unless an explicit partnership is publicly documented.

The project may use third-party tools and services for building, testing, documentation, distribution, or signing without implying vendor endorsement.
