#include "../include/engine.h"
#include "../include/monitor.h"
#include <iostream>

int main() {
    // 1. Modülleri tanımla
    AIEngine ai;
    Monitor monitor;

    // 2. Modeli hazırla
    if (!ai.init("ai_core/models/gemma-2b-it-q4_k_m.gguf")) {
        std::cerr << "AI Engine baslatilamadi!" << std::endl;
        return -1;
    }

    // 3. Ana döngü (Sonsuz döngü, sistemi izler)
    while (true) {
        monitor.updateHardwareStatus();
        float temp = monitor.getTemperature();
        
        // AI'ya veriyi gönder
        ai.processData(temp, 0.0f); // 0.0f = GPU/CPU yükü

        // Burada bir sleep eklenecek (AI'yı sürekli yormamak için)
        break; // Test için döngüden çıkıyoruz
    }

    return 0;
}
