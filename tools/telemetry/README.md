# Telemetry tooling

HWControl exports telemetry locally as CSV. These development tools validate that export contract without adding runtime dependencies to the desktop application.

## Rust analyzer

telemetry-analyzer is a dependency-free Rust CLI used for regression validation. It checks the 14-column telemetry schema, validates numeric fields, rejects non-finite values, and prints basic maxima.

    cargo test --manifest-path tools/telemetry-analyzer/Cargo.toml
    cargo run --manifest-path tools/telemetry-analyzer/Cargo.toml -- tools/telemetry-analyzer/fixtures/healthy.csv

The analyzer is tooling-only; it is not shipped with HWControl.

## Python fixture generator

generate_fixture.py creates deterministic telemetry CSV fixtures using Python's standard-library csv module. This keeps test data reproducible without adding a Python dependency to the application.

    python tools/telemetry/generate_fixture.py /tmp/HWControl-Telemetry.csv
    python -m unittest discover -s tools/telemetry -p 'test_*.py'

The production application remains Dart + Go + C++ and does not require Python or Rust at runtime.
