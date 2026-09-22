#include "../include/telemetry.h"

#include <algorithm>
#include <cmath>
#include <iomanip>
#include <sstream>
#include <string_view>

namespace {

void appendMetric(std::ostringstream& out, std::string_view name, double value, std::string_view unit = {}) {
    out << name << '=';
    if (std::isfinite(value)) {
        out << std::fixed << std::setprecision(1) << value;
        if (!unit.empty()) {
            out << unit;
        }
    } else {
        out << "yok";
    }
    out << "; ";
}

void appendInteger(std::ostringstream& out, std::string_view name, int value) {
    out << name << '=' << value << "; ";
}

double parseNumber(const std::string& value) {
    try {
        size_t consumed = 0;
        const double parsed = std::stod(value, &consumed);
        if (consumed != value.size() || !std::isfinite(parsed)) {
            return std::numeric_limits<double>::quiet_NaN();
        }
        return parsed;
    } catch (...) {
        return std::numeric_limits<double>::quiet_NaN();
    }
}

bool parseBool(const std::string& value, bool& target) {
    if (value == "1" || value == "true") {
        target = true;
        return true;
    }
    if (value == "0" || value == "false") {
        target = false;
        return true;
    }
    return false;
}

int parseInt(const std::string& value) {
    try {
        size_t consumed = 0;
        const long parsed = std::stol(value, &consumed);
        if (consumed != value.size() || parsed < 0 || parsed > 1024) {
            return 0;
        }
        return static_cast<int>(parsed);
    } catch (...) {
        return 0;
    }
}

std::string hexDecode(std::string_view value) {
    if (value.size() % 2 != 0) {
        return {};
    }
    std::string result;
    result.reserve(value.size() / 2);
    for (size_t index = 0; index < value.size(); index += 2) {
        auto hex = [](char c) -> int {
            if (c >= '0' && c <= '9') return c - '0';
            if (c >= 'a' && c <= 'f') return c - 'a' + 10;
            if (c >= 'A' && c <= 'F') return c - 'A' + 10;
            return -1;
        };
        const int high = hex(value[index]);
        const int low = hex(value[index + 1]);
        if (high < 0 || low < 0) {
            return {};
        }
        result.push_back(static_cast<char>((high << 4) | low));
    }
    return result;
}

void addFinding(RiskAssessment& assessment, const char* finding) {
    assessment.findings.emplace_back(finding);
}

}  // namespace

bool isFiniteMeasurement(double value) {
    return std::isfinite(value);
}

RiskAssessment assessHardwareRisk(const HardwareTelemetry& current,
                                  const HardwareTelemetry* previous) {
    RiskAssessment assessment;
    bool critical = false;
    bool elevated = false;
    bool watch = false;
    size_t measuredValues = 0;

    if (isFiniteMeasurement(current.cpuTemperatureC)) {
        ++measuredValues;
        if (current.cpuTemperatureC >= 95.0) {
            critical = true;
            addFinding(assessment, "CPU sıcaklığı çok yüksek gözlem eşiğinde.");
        } else if (current.cpuTemperatureC >= 85.0) {
            elevated = true;
            addFinding(assessment, "CPU sıcaklığı yüksek gözlem eşiğinde.");
        } else if (current.cpuTemperatureC >= 75.0) {
            watch = true;
            addFinding(assessment, "CPU sıcaklığı izleme eşiğinin üzerinde.");
        }
    }

    if (isFiniteMeasurement(current.gpuTemperatureC)) {
        ++measuredValues;
        if (current.gpuTemperatureC >= 100.0) {
            critical = true;
            addFinding(assessment, "GPU sıcaklığı çok yüksek gözlem eşiğinde.");
        } else if (current.gpuTemperatureC >= 90.0) {
            elevated = true;
            addFinding(assessment, "GPU sıcaklığı yüksek gözlem eşiğinde.");
        } else if (current.gpuTemperatureC >= 80.0) {
            watch = true;
            addFinding(assessment, "GPU sıcaklığı izleme eşiğinin üzerinde.");
        }
    }

    if (isFiniteMeasurement(current.gpuPowerWatts) &&
        isFiniteMeasurement(current.gpuPowerLimitWatts) &&
        current.gpuPowerLimitWatts > 0.0) {
        ++measuredValues;
        const double ratio = current.gpuPowerWatts / current.gpuPowerLimitWatts;
        if (ratio >= 1.05) {
            critical = true;
            addFinding(assessment, "GPU gücü bildirilen güç limitini aşıyor.");
        } else if (ratio >= 0.95) {
            elevated = true;
            addFinding(assessment, "GPU gücü güç limitine çok yakın.");
        } else if (ratio >= 0.85) {
            watch = true;
            addFinding(assessment, "GPU güç kullanımı yüksek.");
        }
    }

    if (isFiniteMeasurement(current.gpuMemoryUsagePercent)) {
        ++measuredValues;
        if (current.gpuMemoryUsagePercent >= 95.0) {
            elevated = true;
            addFinding(assessment, "GPU belleği doluluğu çok yüksek.");
        }
    }

    if (isFiniteMeasurement(current.cpuLoadPercent) && current.cpuLoadPercent >= 95.0) {
        ++measuredValues;
        watch = true;
        addFinding(assessment, "CPU yükü uzun süre yüksek olabilir.");
    }

    if (isFiniteMeasurement(current.gpuLoadPercent) && current.gpuLoadPercent >= 95.0) {
        ++measuredValues;
        watch = true;
        addFinding(assessment, "GPU yükü yüksek.");
    }

    if (previous != nullptr) {
        if (isFiniteMeasurement(current.cpuTemperatureC) &&
            isFiniteMeasurement(previous->cpuTemperatureC)) {
            assessment.cpuTemperatureDeltaC = current.cpuTemperatureC - previous->cpuTemperatureC;
            if (assessment.cpuTemperatureDeltaC >= 5.0 && current.cpuTemperatureC >= 70.0) {
                elevated = true;
                addFinding(assessment, "CPU sıcaklığı son analize göre hızlı yükseliyor.");
            }
        }
        if (isFiniteMeasurement(current.gpuTemperatureC) &&
            isFiniteMeasurement(previous->gpuTemperatureC)) {
            assessment.gpuTemperatureDeltaC = current.gpuTemperatureC - previous->gpuTemperatureC;
            if (assessment.gpuTemperatureDeltaC >= 5.0 && current.gpuTemperatureC >= 75.0) {
                elevated = true;
                addFinding(assessment, "GPU sıcaklığı son analize göre hızlı yükseliyor.");
            }
        }
        if (isFiniteMeasurement(current.cpuFrequencyMHz) &&
            isFiniteMeasurement(previous->cpuFrequencyMHz) &&
            previous->cpuFrequencyMHz > 0.0) {
            assessment.cpuFrequencyDropPercent =
                100.0 * (previous->cpuFrequencyMHz - current.cpuFrequencyMHz) / previous->cpuFrequencyMHz;
            if (assessment.cpuFrequencyDropPercent >= 15.0 &&
                isFiniteMeasurement(current.cpuTemperatureC) &&
                current.cpuTemperatureC >= 85.0 &&
                isFiniteMeasurement(current.cpuLoadPercent) &&
                current.cpuLoadPercent >= 85.0) {
                elevated = true;
                addFinding(assessment, "CPU sıcaklık ve yük altında frekans düşüşü termal throttling şüphesi oluşturuyor.");
            }
        }
        if (isFiniteMeasurement(current.gpuCoreClockMHz) &&
            isFiniteMeasurement(previous->gpuCoreClockMHz) &&
            previous->gpuCoreClockMHz > 0.0) {
            assessment.gpuCoreClockDropPercent =
                100.0 * (previous->gpuCoreClockMHz - current.gpuCoreClockMHz) / previous->gpuCoreClockMHz;
            if (assessment.gpuCoreClockDropPercent >= 15.0 &&
                isFiniteMeasurement(current.gpuTemperatureC) &&
                current.gpuTemperatureC >= 80.0 &&
                isFiniteMeasurement(current.gpuLoadPercent) &&
                current.gpuLoadPercent >= 80.0) {
                elevated = true;
                addFinding(assessment, "GPU sıcaklık ve yük altında saat düşüşü termal throttling şüphesi oluşturuyor.");
            }
        }
    }

    if (measuredValues == 0) {
        assessment.level = "veri-yetersiz";
        addFinding(assessment, "Kullanılabilir sıcaklık/yük telemetrisi yok.");
    } else if (critical) {
        assessment.level = "kritik";
    } else if (elevated) {
        assessment.level = "yuksek";
    } else if (watch) {
        assessment.level = "izleme";
    } else {
        assessment.level = "normal";
    }

    if (assessment.findings.empty()) {
        assessment.findings.emplace_back("Belirgin bir gözlem eşiği aşımı yok.");
    }

    return assessment;
}

std::string buildAnalysisPrompt(const HardwareTelemetry& current,
                                const RiskAssessment& assessment) {
    std::ostringstream out;
    out << "Sen HWcontrol yerel donanım analiz motorusun. "
        << "Yalnızca aşağıdaki ölçülmüş verilere dayan. "
        << "Yok olan alanlar için değer uydurma. "
        << "Fan, voltaj, saat hızı veya güç limiti değiştirmeyi emretme. "
        << "Belirsizliği açıkça belirt. Türkçe, en fazla 3 kısa cümle yaz. "
        << "Önce durum, sonra önemli bulgu, sonra güvenli izleme önerisi ver.\n";

    out << "RISK_ENGINE=" << assessment.level << "; ";
    if (isFiniteMeasurement(assessment.cpuTemperatureDeltaC)) {
        appendMetric(out, "CPU_delta", assessment.cpuTemperatureDeltaC, "C");
    }
    if (isFiniteMeasurement(assessment.gpuTemperatureDeltaC)) {
        appendMetric(out, "GPU_delta", assessment.gpuTemperatureDeltaC, "C");
    }
    if (isFiniteMeasurement(assessment.cpuFrequencyDropPercent)) {
        appendMetric(out, "CPU_freq_drop", assessment.cpuFrequencyDropPercent, "%");
    }
    if (isFiniteMeasurement(assessment.gpuCoreClockDropPercent)) {
        appendMetric(out, "GPU_clock_drop", assessment.gpuCoreClockDropPercent, "%");
    }
    out << "BULGULAR=";
    for (size_t index = 0; index < assessment.findings.size(); ++index) {
        if (index > 0) out << " | ";
        out << assessment.findings[index];
    }
    out << "\nTELEMETRI: ";
    appendMetric(out, "CPU_temp", current.cpuTemperatureC, "C");
    appendMetric(out, "CPU_load", current.cpuLoadPercent, "%");
    appendMetric(out, "CPU_max_core", current.cpuMaxCoreLoadPercent, "%");
    appendMetric(out, "CPU_freq", current.cpuFrequencyMHz, "MHz");
    appendInteger(out, "CPU_cores", current.cpuCoreCount);
    appendMetric(out, "GPU_temp", current.gpuTemperatureC, "C");
    appendMetric(out, "GPU_hotspot", current.gpuHotspotTemperatureC, "C");
    appendMetric(out, "GPU_load", current.gpuLoadPercent, "%");
    appendMetric(out, "GPU_memory", current.gpuMemoryUsagePercent, "%");
    appendMetric(out, "GPU_power", current.gpuPowerWatts, "W");
    appendMetric(out, "GPU_power_limit", current.gpuPowerLimitWatts, "W");
    appendMetric(out, "GPU_core_clock", current.gpuCoreClockMHz, "MHz");
    appendMetric(out, "GPU_memory_clock", current.gpuMemoryClockMHz, "MHz");
    appendMetric(out, "GPU_encoder", current.gpuEncoderUsagePercent, "%");
    appendMetric(out, "GPU_decoder", current.gpuDecoderUsagePercent, "%");
    appendMetric(out, "fan", current.fanPercent, "%");
    appendMetric(out, "fan_rpm", current.fanRPM);
    appendMetric(out, "RAM", current.memoryUsagePercent, "%");
    appendMetric(out, "disk", current.diskUsagePercent, "%");
    out << "GAME_MODE=" << (current.gameModeEnabled ? "acik" : "kapali")
        << "; GAME_DETECTED=" << (current.gameDetected ? "evet" : "hayir")
        << "; GPU_VENDOR=" << (current.gpuVendor.empty() ? "yok" : current.gpuVendor)
        << "; GPU_NAME=" << (current.gpuName.empty() ? "yok" : current.gpuName)
        << "; GAME_PROCESS=" << (current.gameProcessName.empty() ? "yok" : current.gameProcessName)
        << '\n';
    return out.str();
}

bool parseTelemetryProtocolLine(const std::string& line, HardwareTelemetry& telemetry) {
    std::istringstream input(line);
    std::string token;
    bool parsedAnything = false;

    while (input >> token) {
        const size_t separator = token.find('=');
        if (separator == std::string::npos || separator == 0) {
            return false;
        }
        const std::string key = token.substr(0, separator);
        const std::string value = token.substr(separator + 1);
        if (value.empty()) {
            return false;
        }

        if (key == "cpu_temp") telemetry.cpuTemperatureC = parseNumber(value);
        else if (key == "cpu_load") telemetry.cpuLoadPercent = parseNumber(value);
        else if (key == "cpu_max_core") telemetry.cpuMaxCoreLoadPercent = parseNumber(value);
        else if (key == "cpu_freq") telemetry.cpuFrequencyMHz = parseNumber(value);
        else if (key == "cpu_cores") telemetry.cpuCoreCount = parseInt(value);
        else if (key == "gpu_temp") telemetry.gpuTemperatureC = parseNumber(value);
        else if (key == "gpu_hotspot") telemetry.gpuHotspotTemperatureC = parseNumber(value);
        else if (key == "gpu_load") telemetry.gpuLoadPercent = parseNumber(value);
        else if (key == "gpu_memory") telemetry.gpuMemoryUsagePercent = parseNumber(value);
        else if (key == "gpu_power") telemetry.gpuPowerWatts = parseNumber(value);
        else if (key == "gpu_power_limit") telemetry.gpuPowerLimitWatts = parseNumber(value);
        else if (key == "gpu_core_clock") telemetry.gpuCoreClockMHz = parseNumber(value);
        else if (key == "gpu_memory_clock") telemetry.gpuMemoryClockMHz = parseNumber(value);
        else if (key == "gpu_encoder") telemetry.gpuEncoderUsagePercent = parseNumber(value);
        else if (key == "gpu_decoder") telemetry.gpuDecoderUsagePercent = parseNumber(value);
        else if (key == "fan") telemetry.fanPercent = parseNumber(value);
        else if (key == "fan_rpm") telemetry.fanRPM = parseNumber(value);
        else if (key == "ram") telemetry.memoryUsagePercent = parseNumber(value);
        else if (key == "disk") telemetry.diskUsagePercent = parseNumber(value);
        else if (key == "game_mode") {
            if (!parseBool(value, telemetry.gameModeEnabled)) return false;
        } else if (key == "game_detected") {
            if (!parseBool(value, telemetry.gameDetected)) return false;
        } else if (key == "gpu_vendor_hex") {
            telemetry.gpuVendor = hexDecode(value);
        } else if (key == "gpu_name_hex") {
            telemetry.gpuName = hexDecode(value);
        } else if (key == "game_process_hex") {
            telemetry.gameProcessName = hexDecode(value);
        } else if (key == "reset") {
            if (value == "1") telemetry = HardwareTelemetry{};
            else return false;
        } else {
            // Unknown fields are ignored for forward compatibility.
            continue;
        }
        parsedAnything = true;
    }

    return parsedAnything;
}
