#ifndef HWCONTROL_TELEMETRY_H
#define HWCONTROL_TELEMETRY_H

#include <limits>
#include <string>
#include <vector>

struct HardwareTelemetry {
    double cpuTemperatureC = std::numeric_limits<double>::quiet_NaN();
    double cpuLoadPercent = std::numeric_limits<double>::quiet_NaN();
    double cpuMaxCoreLoadPercent = std::numeric_limits<double>::quiet_NaN();
    double cpuFrequencyMHz = std::numeric_limits<double>::quiet_NaN();
    int cpuCoreCount = 0;

    double gpuTemperatureC = std::numeric_limits<double>::quiet_NaN();
    double gpuHotspotTemperatureC = std::numeric_limits<double>::quiet_NaN();
    double gpuLoadPercent = std::numeric_limits<double>::quiet_NaN();
    double gpuMemoryUsagePercent = std::numeric_limits<double>::quiet_NaN();
    double gpuPowerWatts = std::numeric_limits<double>::quiet_NaN();
    double gpuPowerLimitWatts = std::numeric_limits<double>::quiet_NaN();
    double gpuCoreClockMHz = std::numeric_limits<double>::quiet_NaN();
    double gpuMemoryClockMHz = std::numeric_limits<double>::quiet_NaN();
    double gpuEncoderUsagePercent = std::numeric_limits<double>::quiet_NaN();
    double gpuDecoderUsagePercent = std::numeric_limits<double>::quiet_NaN();
    double fanPercent = std::numeric_limits<double>::quiet_NaN();
    double fanRPM = std::numeric_limits<double>::quiet_NaN();

    double memoryUsagePercent = std::numeric_limits<double>::quiet_NaN();
    double diskUsagePercent = std::numeric_limits<double>::quiet_NaN();

    bool gameModeEnabled = false;
    bool gameDetected = false;
    std::string gameProcessName;
    std::string gpuVendor;
    std::string gpuName;
};

struct RiskAssessment {
    std::string level;
    std::vector<std::string> findings;
    double cpuTemperatureDeltaC = std::numeric_limits<double>::quiet_NaN();
    double gpuTemperatureDeltaC = std::numeric_limits<double>::quiet_NaN();
    double cpuFrequencyDropPercent = std::numeric_limits<double>::quiet_NaN();
    double gpuCoreClockDropPercent = std::numeric_limits<double>::quiet_NaN();
};

bool isFiniteMeasurement(double value);
RiskAssessment assessHardwareRisk(const HardwareTelemetry& current,
                                  const HardwareTelemetry* previous = nullptr);

// Builds a deterministic, data-only prompt. The LLM explains the supplied facts;
// it is not allowed to invent measurements or choose hardware control actions.
std::string buildAnalysisPrompt(const HardwareTelemetry& current,
                                const RiskAssessment& assessment);

bool parseTelemetryProtocolLine(const std::string& line, HardwareTelemetry& telemetry);

#endif
