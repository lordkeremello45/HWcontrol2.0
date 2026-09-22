#ifndef ENGINE_H
#define ENGINE_H

#include "llama.h"
#include "telemetry.h"

#include <optional>
#include <string>

class AIEngine {
public:
    AIEngine();
    ~AIEngine();

    bool init(const char* modelPath);

    // Backward-compatible CPU-only entry point.
    std::string processData(float temp, float load);

    // Full hardware analysis path used by the richer telemetry pipeline.
    std::string processTelemetry(const HardwareTelemetry& telemetry);

private:
    void release();
    std::string runInference(const std::string& prompt);

    llama_model* model;
    llama_context* ctx;
    llama_sampler* sampler;
    bool backend_initialized;
    std::optional<HardwareTelemetry> previousTelemetry;
};

#endif
