#include "../include/engine.h"
#include <iostream>

AIEngine::AIEngine() : model(nullptr), ctx(nullptr) {}

bool AIEngine::init(const char* modelPath) {
    if (!modelPath || modelPath[0] == '\0') {
        return false;
    }

    llama_backend_init();
    
    llama_model_params mparams = llama_model_default_params();
    model = llama_model_load_from_file(modelPath, mparams);
    
    if (!model) return false;

    llama_context_params cparams = llama_context_default_params();
    ctx = llama_init_from_model(model, cparams);

    if (!ctx) {
        llama_model_free(model);
        model = nullptr;
        llama_backend_free();
        return false;
    }
    
    return ctx != nullptr;
}

void AIEngine::processData(float temp, float load) {
    // Burada model.eval() veya generate döngüleri çalışacak
    std::cout << "AI Engine: Veri isleniyor -> Temp: " << temp << " Load: " << load << std::endl;
}

AIEngine::~AIEngine() {
    if (ctx) llama_free(ctx);
    if (model) llama_model_free(model);
    llama_backend_free();
}
