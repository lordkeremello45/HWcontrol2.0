#include "../include/engine.h"
#include "../include/monitor.h"
#include "../include/bsod_shield.h"
#include <cstdlib>
#include <iostream>
#include <thread>
#include <filesystem>

static std::filesystem::path defaultModelPath() {
    if (const char* configured = std::getenv("HWCONTROL_MODEL"); configured && *configured) {
        return std::filesystem::path(configured);
    }
#ifdef _WIN32
    if (const char* localAppData = std::getenv("LOCALAPPDATA"); localAppData && *localAppData) {
        return std::filesystem::path(localAppData) / "HWControl" / "models" / "gemma-2b-it-q4_k_m.gguf";
    }
#elif defined(__APPLE__)
    if (const char* home = std::getenv("HOME"); home && *home) {
        return std::filesystem::path(home) / "Library" / "Application Support" / "HWControl" / "models" / "gemma-2b-it-q4_k_m.gguf";
    }
#else
    if (const char* xdg = std::getenv("XDG_CACHE_HOME"); xdg && *xdg) {
        return std::filesystem::path(xdg) / "HWControl" / "models" / "gemma-2b-it-q4_k_m.gguf";
    }
    if (const char* home = std::getenv("HOME"); home && *home) {
        return std::filesystem::path(home) / ".cache" / "HWControl" / "models" / "gemma-2b-it-q4_k_m.gguf";
    }
#endif
    return std::filesystem::path("ai_core/models/gemma-2b-it-q4_k_m.gguf");
}

int main(int argc, char* argv[]) {
    AIEngine ai;
    Monitor monitor;
    BSODShield shield(5);

    const std::filesystem::path modelPath = argc > 1 ? argv[1] : defaultModelPath();
    if (!std::filesystem::exists(modelPath)) {
        std::cerr << "AI modeli bulunamadı: " << modelPath << std::endl;
        std::cerr << "HWControl ilk çalıştırmada modeli kurmalıdır veya HWCONTROL_MODEL ile geçerli bir yol verilmelidir." << std::endl;
        return -2;
    }

    if (!ai.init(modelPath.string().c_str())) {
        std::cerr << "AI modeli başlatılamadı: " << modelPath << std::endl;
        return -1;
    }

    int sample_count = 0;
    while (true) {
        monitor.updateHardwareStatus();
        float temp = monitor.getTemperature();

        if (++sample_count >= 10) {
            sample_count = 0;
            const std::string analysis = ai.processData(temp, monitor.getStatus().cpuLoad);
            std::cout << "AI: " << analysis << std::endl;
        }

        shield.heartbeat();
        if (!shield.isSystemHealthy()) {
            std::cerr << "BSOD SHIELD: Sistem dondu! Güvenli moda geçiliyor..." << std::endl;
            break;
        }
        std::this_thread::sleep_for(std::chrono::milliseconds(500));
    }
    return 0;
}
