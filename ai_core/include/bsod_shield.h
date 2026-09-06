
#ifndef BSOD_SHIELD_H
#define BSOD_SHIELD_H

#include <chrono>
#include <mutex>

class BSODShield {
public:
    BSODShield(int timeout_seconds);
    void heartbeat(); // AI çalışırken her döngüde bunu çağır
    bool isSystemHealthy();

private:
    std::chrono::steady_clock::time_point last_heartbeat;
    const std::chrono::seconds timeout_limit;
    mutable std::mutex heartbeat_mutex;
};

#endif
