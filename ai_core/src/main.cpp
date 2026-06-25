#include "../include/engine.h"
#include "../include/monitor.h"
#include "../include/bsod_shield.h" // Yeni kalkan
#include <iostream>
#include <thread> // Sleep için

int main() {
    AIEngine ai;
    Monitor monitor;
    BSODShield shield(5); // AI 5 saniye içinde cevap vermezse "kalkan" devreye girer

    if (!ai.init("ai_core/models/gemma-2b-it-q4_k_m.gguf")) {
        return -1;
    }

    while (true) {
        monitor.updateHardwareStatus();
        float temp = monitor.getTemperature();
        
        // AI'ya veriyi gönder
        ai.processData(temp, 0.0f);

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
