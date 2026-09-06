#include "../include/monitor.h"
#include <iostream>

Monitor::Monitor()
    : currentStatus{65.5f, 0.0f, 0.0f, true} {}

// Donanım verisini okuyan/formatlayan sınıf
void Monitor::updateHardwareStatus() {
    // Burada ileride 'bridge_service'den gelen veriyi parse edeceğiz
    std::cout << "Monitor: Donanim verileri guncellendi..." << std::endl;
}

float Monitor::getTemperature() const {
    return currentStatus.temperature;
}
