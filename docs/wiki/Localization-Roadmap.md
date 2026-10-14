# Localization roadmap

## Target

The next localization milestone is **1,000 user-facing translation keys** in the canonical English (US) ARB catalog. Count actual user-facing keys only; exclude ARB metadata keys beginning with `@`. Do not inflate the count with unused strings, duplicate synonyms, generated placeholders, or machine-translated filler.

## Baseline on 2026-10-14

- English (US): 278 user-facing keys.
- Turkish: 44 user-facing keys.
- English (UK): 222 user-facing keys.

These counts were read from the current ARB files. They are a catalog baseline, not a claim of complete UI coverage. Several locales are still sparse and will need parity work.

## Incremental plan

1. Inventory visible UI text and group keys by feature: onboarding, dashboard, sensors, fan channels, profiles, Game Mode, battery, diagnostics, settings, accessibility, errors, update flow, packaging/runtime, and safety.
2. Give every key a stable semantic name and a short translator description. Use ICU plural/select placeholders for variable text rather than concatenating sentences.
3. Treat `app_en_US.arb` as the canonical source; keep regional English variants and translated ARB files aligned with the keys used by the app.
4. Translate Turkish with natural Türkiye Turkish and review technical terms consistently. Other languages should be reviewed by fluent speakers before being described as complete.
5. Add tests for missing keys, empty values, invalid placeholders, duplicate/unused keys, and catalog growth. Missing translations must fall back safely without crashing startup.
6. Increase coverage by feature slices until the catalog reaches 1,000 useful keys, then continue with quality and locale parity rather than stopping at the number.

## Wizard slice

The first-run setup wizard adds profile selection, startup preference, an explicit hardware-control safety acknowledgement, and a final review. It stores user choices but does not claim unsupported hardware capabilities or directly change fan hardware. English (US) and Turkish wizard strings are present; broader locale coverage remains work in progress.
