#include "../include/monitor.h"

#include <cmath>
#include <fstream>
#include <sstream>
#include <string>
#include <vector>

#if defined(_WIN32) || defined(__APPLE__) || defined(__linux__)
#include <cstdio>
#endif

namespace {

double nanValue() {
    return std::numeric_limits<double>::quiet_NaN();
}

#if defined(_WIN32) || defined(__APPLE__) || defined(__linux__)
std::string commandOutput(const char* command) {
#ifdef _WIN32
    FILE* pipe = _popen(command, "r");
#else
    FILE* pipe = popen(command, "r");
#endif
    if (!pipe) {
        return {};
    }

    std::string output;
    char buffer[512];
    while (fgets(buffer, sizeof(buffer), pipe) != nullptr) {
        output += buffer;
        if (output.size() > 16384) {
            break;
        }
    }
#ifdef _WIN32
    _pclose(pipe);
#else
    pclose(pipe);
#endif
    return output;
}
#endif

}  // namespace

Monitor::Monitor()
    : currentStatus{
          nanValue(), nanValue(), nanValue(), nanValue(),
          nanValue(), nanValue(), nanValue(), nanValue(),
          nanValue(), nanValue(), nanValue(), nanValue(),
          nanValue(), nanValue(), 0} {}

void Monitor::updateHardwareStatus() {
#if defined(__linux__)
    static std::vector<unsigned long long> previousIdle;
    static std::vector<unsigned long long> previousTotal;

    std::ifstream cpuFile("/proc/stat");
    std::string label;
    unsigned long long user = 0;
    unsigned long long nice = 0;
    unsigned long long system = 0;
    unsigned long long idle = 0;
    unsigned long long iowait = 0;
    unsigned long long irq = 0;
    unsigned long long softirq = 0;
    unsigned long long steal = 0;

    if (cpuFile >> label >> user >> nice >> system >> idle >> iowait >> irq >> softirq >> steal) {
        const unsigned long long idleTotal = idle + iowait;
        const unsigned long long total = user + nice + system + idle + iowait + irq + softirq + steal;
        if (previousTotal.size() == 1 && total >= previousTotal[0] && idleTotal >= previousIdle[0]) {
            const auto totalDelta = total - previousTotal[0];
            const auto idleDelta = idleTotal - previousIdle[0];
            if (totalDelta > 0 && idleDelta <= totalDelta) {
                currentStatus.cpuLoad = 100.0 * static_cast<double>(totalDelta - idleDelta) / static_cast<double>(totalDelta);
            }
        }
        previousIdle = {idleTotal};
        previousTotal = {total};
    }

    std::ifstream statusFile("/proc/cpuinfo");
    std::string line;
    int cores = 0;
    while (std::getline(statusFile, line)) {
        if (line.rfind("processor", 0) == 0) {
            ++cores;
        }
        if (line.rfind("cpu MHz", 0) == 0 && !isFiniteMeasurement(currentStatus.cpuFrequencyMHz)) {
            const size_t colon = line.find(':');
            if (colon != std::string::npos) {
                try {
                    currentStatus.cpuFrequencyMHz = std::stod(line.substr(colon + 1));
                } catch (...) {
                }
            }
        }
    }
    currentStatus.cpuCoreCount = cores;

    // Derive the busiest logical CPU from the same interval counters. This gives
    // the local LLM a useful signal that aggregate CPU load can hide.
    std::ifstream perCoreStat("/proc/stat");
    std::string cpuLabel;
    std::vector<unsigned long long> currentIdle;
    std::vector<unsigned long long> currentTotal;
    while (perCoreStat >> cpuLabel) {
        if (cpuLabel.size() <= 3 || cpuLabel.rfind("cpu", 0) != 0 || !std::isdigit(static_cast<unsigned char>(cpuLabel[3]))) {
            if (cpuLabel == "intr" || cpuLabel == "ctxt" || cpuLabel == "btime" || cpuLabel == "processes" || cpuLabel == "procs_running" || cpuLabel == "procs_blocked" || cpuLabel == "softirq") {
                std::string rest;
                std::getline(perCoreStat, rest);
                continue;
            }
            std::string rest;
            std::getline(perCoreStat, rest);
            continue;
        }
        unsigned long long u = 0, n = 0, s = 0, i = 0, w = 0, irqV = 0, sirq = 0, st = 0;
        if (!(perCoreStat >> u >> n >> s >> i >> w >> irqV >> sirq >> st)) break;
        currentIdle.push_back(i + w);
        currentTotal.push_back(u + n + s + i + w + irqV + sirq + st);
    }
    static std::vector<unsigned long long> previousCoreIdle;
    static std::vector<unsigned long long> previousCoreTotal;
    if (previousCoreTotal.size() == currentTotal.size() && previousCoreIdle.size() == currentIdle.size()) {
        double maxLoad = 0.0;
        for (size_t index = 0; index < currentTotal.size(); ++index) {
            if (currentTotal[index] < previousCoreTotal[index] || currentIdle[index] < previousCoreIdle[index]) continue;
            const auto totalDelta = currentTotal[index] - previousCoreTotal[index];
            const auto idleDelta = currentIdle[index] - previousCoreIdle[index];
            if (totalDelta > 0 && idleDelta <= totalDelta) {
                maxLoad = std::max(maxLoad, 100.0 * static_cast<double>(totalDelta - idleDelta) / static_cast<double>(totalDelta));
            }
        }
        currentStatus.cpuMaxCoreLoadPercent = maxLoad;
    }
    previousCoreIdle = currentIdle;
    previousCoreTotal = currentTotal;

    const char* thermalPaths[] = {
        "/sys/class/thermal/thermal_zone0/temp",
        "/sys/class/hwmon/hwmon0/temp1_input",
    };
    for (const char* path : thermalPaths) {
        std::ifstream temperatureFile(path);
        long temperature = 0;
        if (temperatureFile >> temperature) {
            const double celsius = static_cast<double>(temperature) / 1000.0;
            if (std::isfinite(celsius) && celsius > -40.0 && celsius < 150.0) {
                currentStatus.temperatureC = celsius;
                break;
            }
        }
    }

    std::ifstream memInfo("/proc/meminfo");
    unsigned long long memTotalKb = 0;
    unsigned long long memAvailableKb = 0;
    std::string memKey;
    unsigned long long memValue = 0;
    std::string memUnit;
    while (memInfo >> memKey >> memValue >> memUnit) {
        if (memKey == "MemTotal:") memTotalKb = memValue;
        else if (memKey == "MemAvailable:") memAvailableKb = memValue;
    }
    if (memTotalKb > 0 && memAvailableKb <= memTotalKb) {
        currentStatus.memoryUsage = 100.0 * static_cast<double>(memTotalKb - memAvailableKb) / static_cast<double>(memTotalKb);
    }

    const std::string nvidia = commandOutput(
        "nvidia-smi --query-gpu=temperature.gpu,utilization.gpu,utilization.memory,"
        "fan.speed,power.draw,power.limit,memory.used,memory.total,clocks.gr,clocks.mem,"
        "utilization.encoder,utilization.decoder --format=csv,noheader,nounits 2>/dev/null");
    if (!nvidia.empty()) {
        std::istringstream row(nvidia);
        std::string field;
        std::vector<std::string> fields;
        while (std::getline(row, field, ',')) {
            fields.push_back(field);
        }
        if (fields.size() >= 12) {
            const auto parse = [](const std::string& value) {
                try {
                    return std::stod(value);
                } catch (...) {
                    return nanValue();
                }
            };
            currentStatus.gpuTemperatureC = parse(fields[0]);
            currentStatus.gpuLoad = parse(fields[1]);
            currentStatus.gpuMemoryUsagePercent = parse(fields[2]);
            currentStatus.fanPercent = parse(fields[3]);
            currentStatus.gpuPowerWatts = parse(fields[4]);
            currentStatus.gpuPowerLimitWatts = parse(fields[5]);
            const double memoryUsedMiB = parse(fields[6]);
            const double memoryTotalMiB = parse(fields[7]);
            currentStatus.gpuCoreClockMHz = parse(fields[8]);
            currentStatus.gpuMemoryClockMHz = parse(fields[9]);

            if (std::isfinite(memoryUsedMiB) && std::isfinite(memoryTotalMiB) && memoryTotalMiB > 0) {
                currentStatus.gpuMemoryUsagePercent = 100.0 * memoryUsedMiB / memoryTotalMiB;
            }
        }
    }

#elif defined(_WIN32) || defined(__APPLE__)
    const std::string nvidia = commandOutput(
        "nvidia-smi --query-gpu=temperature.gpu,utilization.gpu,utilization.memory,"
        "fan.speed,power.draw,power.limit,memory.used,memory.total,clocks.gr,clocks.mem "
        "--format=csv,noheader,nounits 2>/dev/null");
    if (!nvidia.empty()) {
        std::istringstream row(nvidia);
        std::string field;
        std::vector<std::string> fields;
        while (std::getline(row, field, ',')) fields.push_back(field);
        if (fields.size() >= 10) {
            const auto parse = [](const std::string& value) {
                try { return std::stod(value); } catch (...) { return nanValue(); }
            };
            currentStatus.gpuTemperatureC = parse(fields[0]);
            currentStatus.gpuLoad = parse(fields[1]);
            currentStatus.gpuMemoryUsagePercent = parse(fields[2]);
            currentStatus.fanPercent = parse(fields[3]);
            currentStatus.gpuPowerWatts = parse(fields[4]);
            currentStatus.gpuPowerLimitWatts = parse(fields[5]);
            const double memoryUsedMiB = parse(fields[6]);
            const double memoryTotalMiB = parse(fields[7]);
            currentStatus.gpuCoreClockMHz = parse(fields[8]);
            currentStatus.gpuMemoryClockMHz = parse(fields[9]);
            if (std::isfinite(memoryUsedMiB) && std::isfinite(memoryTotalMiB) && memoryTotalMiB > 0) {
                currentStatus.gpuMemoryUsagePercent = 100.0 * memoryUsedMiB / memoryTotalMiB;
            }
        }
    }
#endif
}

HardwareStatus Monitor::getStatus() const {
    return currentStatus;
}

double Monitor::getTemperature() const {
    return currentStatus.temperatureC;
}

HardwareTelemetry Monitor::getTelemetry() const {
    HardwareTelemetry telemetry;
    telemetry.cpuTemperatureC = currentStatus.temperatureC;
    telemetry.cpuLoadPercent = currentStatus.cpuLoad;
    telemetry.cpuFrequencyMHz = currentStatus.cpuFrequencyMHz;
    telemetry.cpuCoreCount = currentStatus.cpuCoreCount;
    telemetry.gpuTemperatureC = currentStatus.gpuTemperatureC;
    telemetry.gpuLoadPercent = currentStatus.gpuLoad;
    telemetry.gpuMemoryUsagePercent = currentStatus.gpuMemoryUsagePercent;
    telemetry.gpuPowerWatts = currentStatus.gpuPowerWatts;
    telemetry.gpuPowerLimitWatts = currentStatus.gpuPowerLimitWatts;
    telemetry.gpuCoreClockMHz = currentStatus.gpuCoreClockMHz;
    telemetry.gpuMemoryClockMHz = currentStatus.gpuMemoryClockMHz;
    telemetry.fanPercent = currentStatus.fanPercent;
    telemetry.fanRPM = currentStatus.fanRPM;
    telemetry.cpuMaxCoreLoadPercent = currentStatus.cpuMaxCoreLoadPercent;
    telemetry.memoryUsagePercent = currentStatus.memoryUsage;
    return telemetry;
}
