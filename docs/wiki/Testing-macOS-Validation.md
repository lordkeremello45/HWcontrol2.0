# macOS Validation

The macOS release workflow targets a native macOS runner and Apple Silicon. Check the latest workflow run before claiming that a particular commit passed.

Validation covers:

- native CMake build;
- CTest regression suite;
- Go bridge tests/build;
- Flutter analyze/tests;
- Flutter macOS release build;
- application/package path used by the release pipeline.

The target is macOS 14+ Apple Silicon.

A successful build validation is not, by itself, Developer ID signing or Apple notarization. Those are separate production trust gates and are only claimed when Apple credentials and verification steps are present.

The final-release workflow checks whether required Apple signing/notarization secrets are configured before a production release can proceed. Secret presence alone is not signature or notarization verification; the resulting artifact must pass the platform verification steps.
