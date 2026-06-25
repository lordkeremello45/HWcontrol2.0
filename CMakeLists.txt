cmake_minimum_required(VERSION 3.16)
project(HWControl2_0 C CXX)

# C++ Standardı
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Llama.cpp için opsiyonel ayarlar (Derleme hızını artırır)
set(GGML_CUDA OFF CACHE BOOL "" FORCE)
set(GGML_METAL OFF CACHE BOOL "" FORCE)
set(GGML_NATIVE ON CACHE BOOL "" FORCE) # CPU optimizasyonu için

# 1. FetchContent ile llama.cpp'yi dışarıdan çekiyoruz
include(FetchContent)

FetchContent_Declare(
  llama_cpp
  GIT_REPOSITORY https://github.com/ggerganov/llama.cpp
  GIT_TAG        b9789
)

# Kütüphaneyi projeye dahil et
FetchContent_MakeAvailable(llama_cpp)

# 2. AI_CORE modülünü tanımla
add_executable(ai_engine 
    ai_core/src/main.cpp
)

# Llama kütüphanesini engine'e bağla
target_link_libraries(ai_engine PRIVATE llama)

# Header yollarını belirt
target_include_directories(ai_engine PRIVATE 
    ai_core/include
    ${llama_cpp_SOURCE_DIR}/include
)

# 3. İleride ekleyeceğin modüller için yer tutucular
# add_subdirectory(bridge_service)
# add_subdirectory(gui_dashboard)

message(STATUS "HWControl 2.0 yapılandırması tamamlandı.")
