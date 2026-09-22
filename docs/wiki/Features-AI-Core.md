# Local AI Core

HWcontrol2.0 includes a local large-language-model analysis engine built around Gemma 3 1B GGUF and llama.cpp. The model is executed locally; telemetry is not uploaded to a cloud AI service by this component. The selected Gemma 3 1B Instruct Q5_K_M GGUF model is about 851 MB, keeping the model cache below 1 GB.

## What the AI Core does

The AI engine converts hardware telemetry into a short Turkish explanation. It currently accepts:

- CPU temperature, aggregate load, busiest logical-core load and frequency
- CPU core count
- GPU temperature, load and memory utilization
- GPU power and reported power limit
- GPU core and memory clocks
- fan percentage/RPM when available
- system RAM and disk utilization
- Game Mode / game detection state
- GPU vendor/name when supplied by the caller

Unavailable measurements are represented explicitly as missing data. The model is instructed not to invent values.

## Safety architecture

The LLM is not the hardware safety authority.

Before inference, a deterministic risk layer classifies the supplied telemetry as:

- `normal`
- `izleme`
- `yuksek`
- `kritik`
- `veri-yetersiz`

The thresholds are conservative observation thresholds, not universal hardware safety limits. The result is passed to the LLM as context so the model explains measured conditions rather than making uncontrolled hardware decisions.

The AI prompt explicitly prohibits instructing the user to change fan speed, voltage, clocks or power limits.

## Trend awareness

The AI engine retains the previous telemetry snapshot for the current runtime session and calculates CPU/GPU temperature deltas. A rapid rise can therefore be reported even when the absolute temperature has not crossed a high threshold.

## Runtime protocol

`ai_engine --stdio` starts a persistent model process and reads one telemetry request per line. The protocol is intentionally dependency-light and forward-compatible:

```text
cpu_temp=72.5 cpu_load=91 gpu_temp=82 gpu_load=97 gpu_power=218 gpu_power_limit=250 game_mode=1 game_detected=1
```

String values use hexadecimal fields such as `gpu_name_hex` and `game_process_hex`.

The response is one line:

```text
OK|<analysis>
```

Malformed requests return:

```text
ERROR|invalid-telemetry
```

The stdio mode is designed for the authenticated local application/bridge integration and avoids repeatedly loading the ~851 MB model for every analysis request.

## Current runtime boundary

The local LLM, telemetry analysis pipeline and desktop runtime integration are implemented. The GUI now starts the persistent AI engine locally and feeds it authenticated bridge telemetry. The Go bridge remains the authoritative hardware/control path, while the LLM is restricted to analysis, explanation and recommendations.

The native engine does not currently claim universal support for AMD/Intel/macOS sensor backends. Missing sensor data remains missing rather than being synthesized.

The deterministic risk engine now also compares consecutive CPU frequency and GPU core-clock samples. A drop of at least 15% under high load and elevated temperature is reported as suspected thermal throttling; the LLM only explains this finding and cannot control hardware.
