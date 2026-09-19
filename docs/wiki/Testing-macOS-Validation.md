# macOS Validation

The macOS release path is validated on a native macOS runner for Apple Silicon.

Validation covers:

- native CMake build;
- CTest regression suite;
- Go bridge tests/build;
- Flutter analyze/tests;
- Flutter macOS release build;
- application/package path used by the release pipeline.

The target is macOS 14+ Apple Silicon.

A successful build validation is not, by itself, Developer ID signing or Apple notarization. Those are separate production trust gates and are only claimed when Apple credentials and verification steps are present.

The repository now includes a release-readiness gate that checks whether the required Apple signing/notarization secrets are configured before a production release is treated as ready.
