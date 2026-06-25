#ifndef ENGINE_H
#define ENGINE_H

#include "llama.h"

class AIEngine {
public:
    AIEngine();
    ~AIEngine();

    // Modeli başlat ve belleğe yükle
    bool init(const char* modelPath);

    // Donanım verisini AI'ya gönder ve yanıt al
    void processData(float temp, float load);

private:
    llama_model* model;
    llama_context* ctx;
};

#endif
