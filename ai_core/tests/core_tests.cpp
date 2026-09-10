#include "../include/engine.h"
#include "../include/bsod_shield.h"

#include <cassert>
#include <chrono>
#include <cstdlib>
#include <iostream>
#include <limits>
#include <string>
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

        // Optional real-model regression. CI can enable this with HWCONTROL_TEST_MODEL.
        if (const char* model = std::getenv("HWCONTROL_TEST_MODEL"); model && *model) {
            if (!engine.init(model)) {
                std::cerr << "HWCONTROL_TEST_MODEL could not be initialized: " << model << '\n';
                return 1;
            }
            const std::string first = engine.processData(55.0f, 35.0f);
            assert(!first.empty());
            assert(first != "AI yanit uretemedi");

            // Successful repeated init must replace the previous runtime without corrupting it.
            assert(engine.init(model));
            const std::string second = engine.processData(56.0f, 36.0f);
            assert(!second.empty());
            assert(second != "AI motoru hazir degil");
            assert(second != "AI yanit uretemedi");
        }
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
