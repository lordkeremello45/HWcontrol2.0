#include "../include/engine.h"
#include <cmath>
#include <iostream>
#include <vector>

AIEngine::AIEngine() : model(nullptr), ctx(nullptr), sampler(nullptr), backend_initialized(false) {}

void AIEngine::release() {
    if (sampler) {
        llama_sampler_free(sampler);
        sampler = nullptr;
    }
    if (ctx) {
        llama_free(ctx);
        ctx = nullptr;
    }
    if (model) {
        llama_model_free(model);
        model = nullptr;
    }
    if (backend_initialized) {
        llama_backend_free();
        backend_initialized = false;
    }
}

bool AIEngine::init(const char* modelPath) {
    if (!modelPath || modelPath[0] == '\0') {
        return false;
    }

    // init() is safe to call repeatedly: never leak or overwrite a previous runtime.
    release();
    llama_backend_init();
    backend_initialized = true;

    llama_model_params mparams = llama_model_default_params();
    model = llama_model_load_from_file(modelPath, mparams);
    if (!model) {
        release();
        return false;
    }

    llama_context_params cparams = llama_context_default_params();
    ctx = llama_init_from_model(model, cparams);
    if (!ctx) {
        release();
        return false;
    }

    sampler = llama_sampler_chain_init(llama_sampler_chain_default_params());
    if (!sampler) {
        release();
        return false;
    }
    llama_sampler_chain_add(sampler, llama_sampler_init_temp(0.25f));
    llama_sampler_chain_add(sampler, llama_sampler_init_greedy());

    return true;
}

std::string AIEngine::processData(float temp, float load) {
    if (!std::isfinite(temp) || !std::isfinite(load)) {
        return "AI girdisi gecersiz";
    }
    if (!model || !ctx || !sampler) {
        return "AI motoru hazir degil";
    }

    const llama_vocab* vocab = llama_model_get_vocab(model);
    if (!vocab) {
        return "AI vocab bulunamadi";
    }

    const std::string prompt =
        "Sistem monitoru olarak kisa ve Turkce yanit ver. "
        "Sicaklik: " + std::to_string(temp) + " C, CPU yuku: " +
        std::to_string(load) + "%. Risk varsa tek cumleyle belirt.";
    llama_memory_clear(llama_get_memory(ctx), true);
    const bool is_first = llama_memory_seq_pos_max(llama_get_memory(ctx), 0) == -1;
    const int token_count = -llama_tokenize(vocab, prompt.c_str(), prompt.size(), nullptr, 0, is_first, true);
    if (token_count <= 0) return "Prompt tokenize edilemedi";

    std::vector<llama_token> prompt_tokens(static_cast<size_t>(token_count));
    if (llama_tokenize(vocab, prompt.c_str(), prompt.size(), prompt_tokens.data(), prompt_tokens.size(), is_first, true) < 0) {
        return "Prompt tokenize edilemedi";
    }

    llama_batch batch = llama_batch_get_one(prompt_tokens.data(), prompt_tokens.size());
    if (llama_decode(ctx, batch) != 0) return "AI decode basarisiz";

    std::string response;
    for (int token_index = 0; token_index < 96; ++token_index) {
        llama_token token = llama_sampler_sample(sampler, ctx, -1);
        if (llama_vocab_is_eog(vocab, token)) break;
        char buffer[256];
        const int piece_size = llama_token_to_piece(vocab, token, buffer, sizeof(buffer), 0, true);
        if (piece_size <= 0) break;
        response.append(buffer, static_cast<size_t>(piece_size));
        batch = llama_batch_get_one(&token, 1);
        if (llama_decode(ctx, batch) != 0) break;
    }
    return response.empty() ? "AI yanit uretemedi" : response;
}

AIEngine::~AIEngine() {
    release();
}
