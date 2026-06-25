#ifndef MONITOR_H
#define MONITOR_H

// Donanım durumlarını saklamak için bir yapı
struct HardwareStatus {
    float temperature;
    float cpuLoad;
    float gpuLoad;
    bool fanStatus;
};

class Monitor {
public:
    // Monitor sınıfı başlatıcı
    Monitor();

    // Sensör verilerini günceller (Bridge'den gelen veriyi buraya bağlayacağız)
    void updateHardwareStatus();

    // Güncel donanım bilgilerini döndürür
    HardwareStatus getStatus() const;

    // Tekil veri çekme metodları
    float getTemperature() const;

private:
    HardwareStatus currentStatus;
};

#endif // MONITOR_H
