# AGENTS.md

## HWcontrol2.0 Repository Instructions

HWcontrol2.0 is a cross-platform desktop hardware monitoring and control application.

### Architecture

```
Flutter / Dart GUI
        ↓
Authenticated localhost Go Bridge
        ↓
Native C++ / CMake Engine
        ↓
Platform-specific hardware APIs
```

Targets: Windows 10/11 x64, Linux x64, macOS 14+ Apple Silicon.

## Engineering Rules

1. Inspect the existing implementation before changing it.
2. Identify and fix the actual root cause; never mask failures.
3. Prefer minimal, focused changes over unrelated refactors.
4. Preserve the existing architecture unless a change is explicitly required.
5. Do not claim a feature is implemented without verifying backend behavior.
6. Treat Windows, Linux, and macOS as distinct platforms.
7. Do not add Python to the production application unless explicitly requested.
8. Do not introduce unnecessary asynchronous complexity into existing synchronous workflows.
9. Never hard-code secrets, tokens, passwords, certificates, private keys, or credentials.
10. Never weaken security or disable validation merely to make CI pass.

## Validation

### C++

```bash
cmake
build
ctest
```

### Go Bridge

```bash
go test ./...
go build
```

### Flutter / Dart

```bash
flutter pub get
flutter analyze
flutter test
```

When possible, validate the packaged application, not only source builds.

## CI/CD

- Inspect affected GitHub Actions workflows.
- Run relevant tests when possible.
- Investigate CI failures instead of suppressing them.
- Never remove tests or use unnecessary `continue-on-error`.
- Keep Windows, Linux, and macOS workflows independently valid.

## Packaging

Expected targets include Windows EXE/installer, MSI, MSIX when applicable, portable ZIP; macOS APP/DMG/PKG as applicable; and Linux DEB/TAR.GZ/TAR.ZST.

Artifact creation alone is not sufficient. Prefer installation, launch, runtime, and cleanup validation.

## Hardware Safety

Never infer hardware functionality from a GUI control alone. Verify native backend and platform API support for temperatures, fan RPM/control, voltage, power, clocks, memory, and hardware detection.

Hardware-control operations must fail safely and must not silently report success when the backend cannot perform the requested operation.

## Security

Keep the localhost bridge authenticated, validate bridge inputs/outputs, treat hardware-control commands as privileged operations, and never expose credentials or signing material.

See `SECURITY.md` for the repository security policy.

## Documentation

Documentation must reflect actual implementation. Use status labels such as IMPLEMENTED, PARTIAL, PLANNED, UNAVAILABLE, BLOCKED, VERIFIED, and UNVERIFIED. Never document planned functionality as implemented.

Canonical documentation lives under `docs/wiki/`.

## Git Workflow

- Work from `main` unless another branch is explicitly required.
- Prefer small, reviewable commits.
- Use descriptive commit messages.
- Do not rewrite shared history unless explicitly requested.
- Review the diff before committing.
- Never commit secrets, credentials, build caches, or machine-specific files.

## Completion Criteria

For significant changes, evaluate:

```
Source Build → Unit Tests → Cross-platform Build → Package
→ Install Test → Runtime Smoke Test → Hardware/Feature Validation
→ Signing/Integrity → Documentation
```

Only mark a stage VERIFIED when it has actually been tested.

## Agent Behavior

An AI coding agent should:

1. Inspect first.
2. Identify the actual root cause before significant changes.
3. Make the smallest appropriate fix.
4. Validate the change.
5. Re-check affected CI/workflows.
6. Report verified results and remaining blockers separately.

Never fabricate test results, runtime behavior, hardware support, signing status, or CI success.
