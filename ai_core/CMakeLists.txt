# ai_core/CMakeLists.txt

add_executable(ai_engine 
    src/main.cpp 
    src/engine.cpp 
    src/monitor.cpp
)

# Llama kütüphanesini bağla
target_link_libraries(ai_engine PRIVATE llama)

# Include klasörünü tanıt
target_include_directories(ai_engine PRIVATE include)
