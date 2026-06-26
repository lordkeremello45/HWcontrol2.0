#include "../include/monitor.h"
#include <iostream>

// Donanım verisini okuyan/formatlayan sınıf
void Monitor::updateHardwareStatus() {
    // Burada ileride 'bridge_service'den gelen veriyi parse edeceğiz
    std::cout << "Monitor: Donanim verileri guncellendi..." << std::endl;
}

float Monitor::getTemperature() const {
    return 65.5f; // Örnek veri: Sensörden gelecek değer
}
