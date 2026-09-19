# Real-time Hardware Graphs

The dashboard maintains a temperature history buffer and renders a live history graph.

## Current behavior

- telemetry is refreshed periodically;
- CPU temperature samples are timestamped;
- the history is bounded to 720 samples;
- the dashboard displays the last-hour context in the UI;
- the graph includes a visible temperature trend and maximum value.

The current graph implementation is focused on CPU temperature rather than a separate multi-series chart for every telemetry metric.
