#include "../include/engine.h"
#include <iostream>

AIEngine::AIEngine() : model(nullptr), ctx(nullptr) {}

bool AIEngine::init(const char* modelPath) {
    llama_backend_init();
    
    llama_model_params mparams = llama_model_default_params();
    model = llama_load_model_from_file(modelPath, mparams);
    
    if (!model) return false;

    llama_context_params cparams = llama_context_default_params();
    ctx = llama_new_context_with_model(model, cparams);
    
    return true;
}

void AIEngine::processData(float temp, float load) {
    // Burada model.eval() veya generate döngüleri çalışacak
    std::cout << "AI Engine: Veri isleniyor -> Temp: " << temp << " Load: " << load << std::endl;
}

AIEngine::~AIEngine() {
    if (ctx) llama_free(ctx);
    if (model) llama_free_model(model);
    llama_backend_free();
}
