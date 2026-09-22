cmake_minimum_required(VERSION 3.16)
project(HWControl2_0 C CXX)

# C++ standard
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Keep the build tree outside the source tree. CMake owns the build directory
# selected by the caller (-B build, -B build-windows, etc.).
set(GGML_CUDA OFF CACHE BOOL "" FORCE)
set(GGML_METAL OFF CACHE BOOL "" FORCE)
set(GGML_NATIVE OFF CACHE BOOL "" FORCE)

# The model is a runtime asset. Do not create source-tree directories or
# download/copy large model files during configuration.
set(MODEL_PATH "${CMAKE_SOURCE_DIR}/ai_core/models/gemma-3-1b-it-Q5_K_M.gguf")
if(NOT EXISTS "${MODEL_PATH}")
  message(STATUS "Model not found: ${MODEL_PATH}. It must be supplied separately for runtime AI features.")
endif()

include(FetchContent)

FetchContent_Declare(
  llama_cpp
  GIT_REPOSITORY https://github.com/ggerganov/llama.cpp
  GIT_TAG        b9789
)

FetchContent_MakeAvailable(llama_cpp)

# Enable CTest explicitly so native regression tests are available to CI and
# local builds without requiring callers to know the implementation detail.
include(CTest)
if(BUILD_TESTING)
  enable_testing()
endif()

add_subdirectory(ai_core)

message(STATUS "HWControl 2.0 configuration completed successfully.")
