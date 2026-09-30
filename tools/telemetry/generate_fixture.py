#!/usr/bin/env python3
"""Generate deterministic HWControl telemetry fixtures for regression tests."""

from __future__ import annotations

import argparse
import csv
from pathlib import Path

COLUMNS = [
    "timestamp", "cpu_temperature", "cpu_usage", "cpu_frequency_mhz",
    "gpu_temperature", "gpu_usage", "gpu_core_clock_mhz", "gpu_power_watts",
    "gpu_memory_usage", "fan_percent", "fan_rpm", "memory_usage",
    "disk_usage", "thermal_status",
]

ROWS = [
    ["2026-09-30T18:00:00Z", 42.5, 12.0, 3200, 48.0, 5.0, 1200, 35.0, 18.0, 25, 850, 41.0, 12.0, "NORMAL"],
    ["2026-09-30T18:00:01Z", 44.0, 24.0, 3400, 51.0, 18.0, 1350, 48.0, 22.0, 35, 1100, 43.0, 12.0, "NORMAL"],
]

def write_fixture(path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.writer(handle, lineterminator="\n")
        writer.writerow(COLUMNS)
        writer.writerows(ROWS)

def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    write_fixture(args.output)

if __name__ == "__main__":
    main()
