# Shared Libraries and Data

This directory is the repository-level home for reusable libraries and curated, non-secret data shared across HWcontrol2.0 components.

## Ownership rules

- Keep runtime-specific code inside its owning package. Flutter code stays under `gui_dashboard/lib/`; Go bridge code stays under `bridge_service/src/`; native engine code stays under `ai_core/` or `audio_core/`.
- Put cross-component libraries, curated hardware knowledge, schemas, and integration contracts here when they have a clear shared owner.
- Do not copy the same hardware/model facts into multiple catalogs. Prefer one canonical source and explicit adapters.
- Large model weights and voice packs are runtime assets, not source files. Track their version, license, origin, and SHA-256 metadata; download/cache them outside the repository when appropriate.
- Training examples and knowledge-base records are different things. Updating knowledge records does not train Gemma or change model weights.
- Keep user data, telemetry history, credentials, API tokens, and machine-specific identifiers out of this directory.
- Any data that can influence hardware-control decisions must be validated at the Go bridge/security boundary. Model output and catalog text must never directly authorize privileged actions.

## Current inventory

| Concern | Current location | Notes |
|---|---|---|
| Hardware identification helper | `lib/hardware-identification/` | Windows C# read-only identity collector; platform status and limitations are documented in its README. |
| Gemma model metadata | `models/gemma-3-1b-it-Q5_K_M.json` | Kept at its current path for compatibility with existing references. It is metadata, not model weights or training data. |
| Gemma runtime/download manager | `gui_dashboard/lib/model_manager.dart` | Flutter-specific lifecycle, download bounds, and SHA-256 verification. |
| Piper TTS adapter | `gui_dashboard/lib/services/piper_tts_service.dart` | Flutter-specific local Piper process and WAV playback integration. |
| Localization catalogs | `gui_dashboard/lib/l10n/` | ARB/ICU resources belong to the Flutter localization build. |
| Native AI runtime | `ai_core/` | C++/CMake inference/runtime code; model weights are not committed here. |
| Audio engine | `audio_core/` | Native audio functionality and platform integration. |

## Intended module boundaries

- `ai/`: shared AI contracts, prompt templates, model metadata adapters, and knowledge retrieval interfaces. Keep Flutter-specific download/UI code in the Flutter package.
- `knowledge/`: curated hardware specifications, compatibility data, source attribution, schema versions, and confidence levels.
- `tts/`: shared speech-provider contracts and voice-pack metadata. Keep Piper process and audio-player implementation in the Flutter package unless another runtime genuinely needs it.
- `hardware-identification/`: hardware identity collection and normalized identity contracts; not telemetry or hardware control.
- `validation/`: schemas and cross-component validation contracts where sharing is practical. Runtime enforcement remains in the relevant trusted component.

Create a module directory only when it contains a real library, schema, catalog, or documented contract. Avoid empty placeholder folders and avoid moving files until all imports, CI workflows, packaging scripts, and tests have been updated together.
