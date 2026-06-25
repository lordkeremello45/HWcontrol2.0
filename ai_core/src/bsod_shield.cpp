#include "../include/bsod_shield.h"

BSODShield::BSODShield(int timeout_seconds) 
    : timeout_limit(timeout_seconds) {
    last_heartbeat = std::chrono::steady_clock::now();
}

void BSODShield::heartbeat() {
    last_heartbeat = std::chrono::steady_clock::now();
}

bool BSODShield::isSystemHealthy() {
    auto now = std::chrono::steady_clock::now();
    auto elapsed = std::chrono::duration_cast<std::chrono::seconds>(now - last_heartbeat).count();
    return elapsed < timeout_limit;
}
