#ifndef MONITOR_H
#define MONITOR_H

#include "telemetry.h"

struct HardwareStatus {
    double temperatureC;
    double cpuLoad;
    double gpuLoad;
    double memoryUsage;
    double cpuFrequencyMHz;
    double gpuTemperatureC;
    double gpuPowerWatts;
    double gpuPowerLimitWatts;
    double gpuMemoryUsagePercent;
    double fanPercent;
    double fanRPM;
    double gpuCoreClockMHz;
    double gpuMemoryClockMHz;
    double cpuMaxCoreLoadPercent;
    int cpuCoreCount;
};

class Monitor {
public:
    Monitor();

    void updateHardwareStatus();
    HardwareStatus getStatus() const;
    double getTemperature() const;

    HardwareTelemetry getTelemetry() const;

private:
    HardwareStatus currentStatus{};
};

#endif
