#ifndef ENGINE_H
#define ENGINE_H

#include "llama.h"
#include <string>

class AIEngine {
public:
    AIEngine();
    ~AIEngine();

    // Modeli başlat ve belleğe yükle. Tekrar çağrıldığında mevcut durumu güvenli biçimde bırakır.
    bool init(const char* modelPath);

    // Donanım verisini AI'ya gönder ve kısa yanıt al
    std::string processData(float temp, float load);

private:
    void release();

    llama_model* model;
    llama_context* ctx;
    llama_sampler* sampler;
    bool backend_initialized;
};

#endif
