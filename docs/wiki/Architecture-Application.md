# Application Architecture

```text
┌──────────────────────────────┐
│ Flutter / Dart Dashboard     │
│ gui_dashboard/               │
│ - metrics UI                 │
│ - controls                   │
│ - profiles                   │
│ - update/security status     │
└──────────────┬───────────────┘
               │ authenticated loopback socket
               ▼
┌──────────────────────────────┐
│ Go Bridge Service             │
│ bridge_service/               │
│ - authentication              │
│ - telemetry collection        │
│ - diagnostics                 │
│ - platform adapters           │
│ - Windows service             │
└──────────────┬───────────────┘
               │
               ▼
┌──────────────────────────────┐
│ Native C++ / AI Core         │
│ ai_core/                     │
│ - native runtime             │
│ - llama.cpp / GGML           │
│ - defensive runtime checks   │
└──────────────────────────────┘
```

The bridge is the boundary between the user-facing UI and privileged/system-facing operations.
