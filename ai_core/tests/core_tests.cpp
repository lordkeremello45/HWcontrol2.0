#include "../include/engine.h"
#include "../include/bsod_shield.h"

#include <cassert>
#include <chrono>
#include <limits>
#include <thread>

int main() {
    {
        AIEngine engine;

        // Invalid paths must fail without leaving a partially initialized runtime.
        assert(!engine.init("/definitely/missing/hwcontrol-model.gguf"));
        assert(engine.processData(42.0f, 25.0f) == "AI motoru hazir degil");

        // Repeated failed initialization must remain safe and deterministic.
        assert(!engine.init("/definitely/missing/hwcontrol-model-2.gguf"));
        assert(engine.processData(42.0f, 25.0f) == "AI motoru hazir degil");

        // Non-finite telemetry must never be passed to the model pipeline.
        assert(engine.processData(std::numeric_limits<float>::quiet_NaN(), 25.0f) == "AI girdisi gecersiz");
        assert(engine.processData(42.0f, std::numeric_limits<float>::infinity()) == "AI girdisi gecersiz");
    }

    {
        BSODShield shield(1);
        assert(shield.isSystemHealthy());
        shield.heartbeat();
        assert(shield.isSystemHealthy());

        std::this_thread::sleep_for(std::chrono::milliseconds(1100));
        assert(!shield.isSystemHealthy());

        // A later heartbeat re-arms the watchdog.
        shield.heartbeat();
        assert(shield.isSystemHealthy());
    }

    return 0;
}
