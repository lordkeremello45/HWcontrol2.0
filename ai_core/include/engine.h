#ifndef ENGINE_H
#define ENGINE_H

class Engine {
public:
    void initModel(const char* modelPath);
    void processHardwareData(float temp);
private:
    // Model pointer'ları buraya gelecek
};

#endif
