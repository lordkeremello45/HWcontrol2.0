# Accessibility and Offline Speech (Piper TTS)

## Status

**PARTIAL — optional local Piper integration is implemented; bundled installation and end-to-end platform validation are not yet implemented.**

The dashboard settings menu includes an opt-in Piper TTS control, file-browser buttons for the Piper executable and ONNX voice model, a speech test, a stop control, and a command to read a short CPU/GPU dashboard summary. The service verifies that the model has a non-empty, parseable matching `.onnx.json` configuration before synthesis.

## Privacy and execution

- Speech synthesis runs locally through the Piper command-line executable.
- Dashboard text is passed through the process standard input; it is not sent to a web service by this integration.
- The executable is launched directly without a shell.
- Speech is disabled by default.
- HWcontrol2.0 does not currently download or bundle Piper binaries or voice models.
- Missing binaries/models or synthesis errors must not prevent the hardware dashboard from starting.

## Setup

1. Install a Piper CLI build appropriate for your operating system from the [Piper project](https://github.com/OHF-Voice/piper1-gpl).
2. Obtain a compatible Piper ONNX voice model and its matching model configuration JSON. Review the voice's license and redistribution terms before bundling or redistributing it.
3. Open HWcontrol2.0's menu, then **Accessibility**.
4. Enable **Offline speech (Piper TTS)**.
5. Use the browse controls to select the Piper executable and the voice model's `.onnx` file, or enter their paths manually. The matching `.onnx.json` file must be beside the model.
6. Select **Test speech**. If it succeeds, select **Read dashboard summary** to hear a short summary of CPU/GPU temperatures and usage.
7. Save settings to persist the preference and paths.

The executable path may be left blank when `piper` is available on `PATH`. The model path must point to a local `.onnx` model with a valid matching `.onnx.json` configuration file. The **Browse official Piper voices** link opens the upstream voice catalog. Check each model's `MODEL_CARD` for its license; availability in the catalog does not mean every voice may be redistributed.

## Known limitations

- Piper and voice models are not installed automatically and are not bundled with application installers. File browsing and validation are implemented; a managed download/install flow is not yet implemented.
- A screen reader should still be used for general navigation. This TTS integration is an additional speech feature, not a replacement for complete Flutter semantics, keyboard navigation, or the operating system's screen reader.
- The dashboard summary currently reads a concise subset of telemetry; it does not continuously announce every changing sensor value.
- Supported languages and voice quality depend on the model selected by the user.
- Windows, Linux, and macOS runtime/package validation remains required before this feature can be described as production-verified.

## Next steps

- Decide on approved, redistributable voice models after reviewing model licenses, download integrity, disk size, and voice quality.
- Add platform-specific Piper packaging or a secure first-run installer only after binary provenance and each voice model's redistribution license are verified.
- Test Piper startup, synthesis, playback, cancellation, and cleanup on all supported desktop platforms.
- Expand screen-reader semantics and keyboard-only navigation independently of TTS.
