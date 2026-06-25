cmake_minimum_required(VERSION 3.16)
project(HWControl2_0 C CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Llama.cpp Ayarları
set(GGML_CUDA OFF CACHE BOOL "" FORCE)
set(GGML_METAL OFF CACHE BOOL "" FORCE)

include(FetchContent)

FetchContent_Declare(
  llama_cpp
  GIT_REPOSITORY https://github.com/ggerganov/llama.cpp
  GIT_TAG        b9789
)
FetchContent_MakeAvailable(llama_cpp)

# AI_CORE modülünü sisteme dahil et
add_subdirectory(ai_core)
