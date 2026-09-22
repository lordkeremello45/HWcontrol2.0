#include "../include/engine.h"
#include "../include/monitor.h"
#include "../include/bsod_shield.h"

#include <cstdlib>
#include <filesystem>
#include <iostream>
#include <string>
#include <thread>

static std::filesystem::path defaultModelPath() {
    if (const char* configured = std::getenv("HWCONTROL_MODEL"); configured && *configured) {
        return std::filesystem::path(configured);
    }
#ifdef _WIN32
    if (const char* localAppData = std::getenv("LOCALAPPDATA"); localAppData && *localAppData) {
        return std::filesystem::path(localAppData) / "HWControl" / "models" / "gemma-3-1b-it-Q5_K_M.gguf";
    }
#elif defined(__APPLE__)
    if (const char* home = std::getenv("HOME"); home && *home) {
        return std::filesystem::path(home) / "Library" / "Application Support" / "HWControl" / "models" / "gemma-3-1b-it-Q5_K_M.gguf";
    }
#else
    if (const char* xdg = std::getenv("XDG_CACHE_HOME"); xdg && *xdg) {
        return std::filesystem::path(xdg) / "HWControl" / "models" / "gemma-3-1b-it-Q5_K_M.gguf";
    }
    if (const char* home = std::getenv("HOME"); home && *home) {
        return std::filesystem::path(home) / ".cache" / "HWControl" / "models" / "gemma-3-1b-it-Q5_K_M.gguf";
    }
#endif
    return std::filesystem::path("ai_core/models/gemma-3-1b-it-Q5_K_M.gguf");
}

static int runStdioMode(const std::filesystem::path& modelPath) {
    AIEngine ai;
    if (!ai.init(modelPath.string().c_str())) {
        std::cerr << "AI model could not be initialized: " << modelPath << std::endl;
        return -1;
    }

    std::string line;
    while (std::getline(std::cin, line)) {
        if (line.empty()) {
            continue;
        }
        HardwareTelemetry telemetry;
        if (!parseTelemetryProtocolLine(line, telemetry)) {
            std::cout << "ERROR|invalid-telemetry" << std::endl;
            std::cout.flush();
            continue;
        }
        const std::string response = ai.processTelemetry(telemetry);
        std::cout << "OK|" << response << std::endl;
        std::cout.flush();
    }
    return 0;
}

int main(int argc, char* argv[]) {
    const bool stdioMode = argc > 1 && std::string(argv[1]) == "--stdio";
    const std::filesystem::path modelPath = (argc > 1 && !stdioMode)
        ? std::filesystem::path(argv[1])
        : defaultModelPath();

    if (stdioMode) {
        return runStdioMode(modelPath);
    }

    AIEngine ai;
    Monitor monitor;
    BSODShield shield(5);

    if (!std::filesystem::exists(modelPath)) {
        std::cerr << "AI modeli bulunamadı: " << modelPath << std::endl;
        std::cerr << "HWCONTROL_MODEL ile geçerli bir model yolu verilebilir." << std::endl;
        return -2;
    }

    if (!ai.init(modelPath.string().c_str())) {
        std::cerr << "AI modeli başlatılamadı: " << modelPath << std::endl;
        return -1;
    }

    int sampleCount = 0;
    while (true) {
        monitor.updateHardwareStatus();

        if (++sampleCount >= 10) {
            sampleCount = 0;
            const std::string analysis = ai.processTelemetry(monitor.getTelemetry());
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
