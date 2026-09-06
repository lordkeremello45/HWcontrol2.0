#include "../include/engine.h"
#include "../include/monitor.h"
#include "../include/bsod_shield.h" // Yeni kalkan
#include <iostream>
#include <thread> // Sleep için
#include <filesystem>

int main(int argc, char* argv[]) {
    AIEngine ai;
    Monitor monitor;
    BSODShield shield(5); // AI 5 saniye içinde cevap vermezse "kalkan" devreye girer

    const std::filesystem::path modelPath = argc > 1
        ? argv[1]
        : std::filesystem::path("ai_core/models/gemma-2b-it-q4_k_m.gguf");

    if (!ai.init(modelPath.string().c_str())) {
        std::cerr << "AI modeli baslatilamadi: " << modelPath << std::endl;
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

        // Kalkanı güncelle (AI canlı ve çalışıyor)
        shield.heartbeat();

        // Kalkanı kontrol et (Eğer AI 5 saniyedir cevap vermediyse burası hata verir)
        if (!shield.isSystemHealthy()) {
            std::cerr << "BSOD SHIELD: Sistem dondu! Güvenli moda geçiliyor..." << std::endl;
            break; 
        }

        // AI'yı çok yormamak için kısa bir mola
        std::this_thread::sleep_for(std::chrono::milliseconds(500));
    }

    return 0;
}
