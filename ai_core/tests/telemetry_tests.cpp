#include "../include/telemetry.h"

#include <cassert>
#include <cmath>
#include <string>

int main() {
    {
        HardwareTelemetry telemetry;
        telemetry.cpuTemperatureC = 92.0;
        telemetry.cpuLoadPercent = 96.0;
        telemetry.gpuTemperatureC = 91.0;
        telemetry.gpuPowerWatts = 238.0;
        telemetry.gpuPowerLimitWatts = 250.0;
        telemetry.gpuMemoryUsagePercent = 97.0;

        const RiskAssessment risk = assessHardwareRisk(telemetry);
        assert(risk.level == "yuksek");
        assert(!risk.findings.empty());

        const std::string prompt = buildAnalysisPrompt(telemetry, risk);
        assert(prompt.find("CPU_temp=92.0C") != std::string::npos);
        assert(prompt.find("GPU_power=238.0W") != std::string::npos);
        assert(prompt.find("GPU_memory=97.0%") != std::string::npos);
        assert(prompt.find("RISK_ENGINE=yuksek") != std::string::npos);
        assert(prompt.find("değer uydurma") != std::string::npos);
    }

    {
        HardwareTelemetry previous;
        previous.cpuTemperatureC = 70.0;
        previous.gpuTemperatureC = 76.0;

        HardwareTelemetry current;
        current.cpuTemperatureC = 77.0;
        current.gpuTemperatureC = 83.0;

        current.cpuFrequencyMHz = 2200.0;
        previous.cpuFrequencyMHz = 3000.0;
        current.cpuLoadPercent = 92.0;
        current.gpuCoreClockMHz = 1400.0;
        previous.gpuCoreClockMHz = 1900.0;
        current.gpuLoadPercent = 90.0;

        const RiskAssessment risk = assessHardwareRisk(current, &previous);
        assert(std::fabs(risk.cpuTemperatureDeltaC - 7.0) < 0.001);
        assert(std::fabs(risk.gpuTemperatureDeltaC - 7.0) < 0.001);
        assert(risk.cpuFrequencyDropPercent > 26.0 && risk.cpuFrequencyDropPercent < 27.0);
        assert(risk.gpuCoreClockDropPercent > 26.0 && risk.gpuCoreClockDropPercent < 27.0);
        assert(risk.level == "yuksek");
        const std::string prompt = buildAnalysisPrompt(current, risk);
        assert(prompt.find("CPU_freq_drop=") != std::string::npos);
        assert(prompt.find("GPU_clock_drop=") != std::string::npos);
    }

    {
        HardwareTelemetry telemetry;
        assert(!parseTelemetryProtocolLine("cpu_temp=72.5 broken-token gpu_temp=81", telemetry));
        // Malformed framing must never be accepted even when earlier fields are valid.
    }

    {
        HardwareTelemetry telemetry;
        const bool parsed = parseTelemetryProtocolLine(
            "cpu_temp=72.5 cpu_load=48 gpu_temp=81 gpu_load=96 gpu_power=210 "
            "gpu_power_limit=250 game_mode=1 game_detected=1 "
            "gpu_name_hex=4e5649444941204745464f524345 game_process_hex=6373322e657865",
            telemetry);
        assert(parsed);
        assert(std::fabs(telemetry.cpuTemperatureC - 72.5) < 0.001);
        assert(telemetry.gameModeEnabled);
        assert(telemetry.gameDetected);
        assert(telemetry.gpuName == "NVIDIA GEFORCE");
        assert(telemetry.gameProcessName == "cs2.exe");
    }

    {
        HardwareTelemetry telemetry;
        const bool parsed = parseTelemetryProtocolLine("cpu_temp=nan", telemetry);
        assert(parsed);
        assert(!std::isfinite(telemetry.cpuTemperatureC));
    }

    {
        HardwareTelemetry telemetry;
        const RiskAssessment risk = assessHardwareRisk(telemetry);
        assert(risk.level == "veri-yetersiz");
        assert(!risk.findings.empty());
    }

    return 0;
}
