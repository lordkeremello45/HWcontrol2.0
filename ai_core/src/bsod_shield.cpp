#include "../include/bsod_shield.h"

BSODShield::BSODShield(int timeout_seconds) 
    : timeout_limit(std::chrono::seconds(timeout_seconds > 0 ? timeout_seconds : 1)) {
    last_heartbeat = std::chrono::steady_clock::now();
}

void BSODShield::heartbeat() {
    std::lock_guard<std::mutex> lock(heartbeat_mutex);
    last_heartbeat = std::chrono::steady_clock::now();
}

bool BSODShield::isSystemHealthy() {
    std::lock_guard<std::mutex> lock(heartbeat_mutex);
    auto now = std::chrono::steady_clock::now();
    return now - last_heartbeat < timeout_limit;
}
