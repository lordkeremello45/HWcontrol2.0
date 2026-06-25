cmake_minimum_required(VERSION 3.16)
project(HWControl2_0 C CXX)

# C++ Standartları
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Llama.cpp ve GGML Derleme Ayarları
set(GGML_CUDA OFF CACHE BOOL "" FORCE)
set(GGML_METAL OFF CACHE BOOL "" FORCE)
set(GGML_NATIVE ON CACHE BOOL "" FORCE)

# 1. FetchContent ile llama.cpp'yi çek
include(FetchContent)

FetchContent_Declare(
  llama_cpp
  GIT_REPOSITORY https://github.com/ggerganov/llama.cpp
  GIT_TAG        b9789
)
FetchContent_MakeAvailable(llama_cpp)

# 2. Model için klasör oluştur ve otomatik indir
file(MAKE_DIRECTORY ${CMAKE_SOURCE_DIR}/ai_core/models)

set(MODEL_URL "https://huggingface.co/bartowski/gemma-2-2b-it-GGUF/resolve/main/gemma-2-2b-it-Q4_K_M.gguf")
set(MODEL_PATH "${CMAKE_SOURCE_DIR}/ai_core/models/gemma-2b-it-q4_k_m.gguf")

if(NOT EXISTS ${MODEL_PATH})
    message(STATUS "Model bulunamadi, indiriliyor: ${MODEL_PATH}")
    file(DOWNLOAD ${MODEL_URL} ${MODEL_PATH} SHOW_PROGRESS)
endif()

# 3. AI_CORE modülünü sisteme dahil et
add_subdirectory(ai_core)

message(STATUS "HWControl 2.0 yapılandırması başarıyla tamamlandı.")
