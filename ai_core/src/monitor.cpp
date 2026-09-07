#include "../include/monitor.h"
#include <fstream>
#include <iostream>
#include <sstream>
#include <string>

Monitor::Monitor()
    : currentStatus{0.0f, 0.0f, 0.0f, true} {}

// Donanım verisini okuyan/formatlayan sınıf
void Monitor::updateHardwareStatus() {
#if defined(__linux__)
    static unsigned long long previous_idle = 0;
    static unsigned long long previous_total = 0;
    std::ifstream cpu_file("/proc/stat");
    std::string label;
    unsigned long long user = 0;
    unsigned long long nice = 0;
    unsigned long long system = 0;
    unsigned long long idle = 0;
    unsigned long long iowait = 0;
    unsigned long long irq = 0;
    unsigned long long softirq = 0;
    unsigned long long steal = 0;
    if (cpu_file >> label >> user >> nice >> system >> idle >> iowait >> irq >> softirq >> steal) {
        const unsigned long long idle_total = idle + iowait;
        const unsigned long long total = user + nice + system + idle + iowait + irq + softirq + steal;
        const unsigned long long total_delta = total - previous_total;
        const unsigned long long idle_delta = idle_total - previous_idle;
        if (total_delta > 0) {
            currentStatus.cpuLoad = 100.0f * static_cast<float>(total_delta - idle_delta) / static_cast<float>(total_delta);
        }
        previous_idle = idle_total;
        previous_total = total;
    }

    const char* thermal_paths[] = {
        "/sys/class/thermal/thermal_zone0/temp",
        "/sys/class/hwmon/hwmon0/temp1_input",
    };
    for (const char* path : thermal_paths) {
        std::ifstream temperature_file(path);
        long temperature = 0;
        if (temperature_file >> temperature) {
            currentStatus.temperature = static_cast<float>(temperature) / 1000.0f;
            break;
        }
    }
#else
    currentStatus.temperature = 0.0f;
    currentStatus.cpuLoad = 0.0f;
#endif
}

HardwareStatus Monitor::getStatus() const {
    return currentStatus;
}

float Monitor::getTemperature() const {
    return currentStatus.temperature;
}
