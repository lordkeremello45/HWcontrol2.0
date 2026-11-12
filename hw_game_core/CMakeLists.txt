cmake_minimum_required(VERSION 3.16)
project(HWControlGameCore LANGUAGES CXX)

# Allow fast, dependency-free validation as a standalone CMake project.
if(CMAKE_SOURCE_DIR STREQUAL CMAKE_CURRENT_SOURCE_DIR)
  include(CTest)
endif()

option(HWCONTROL_GAME_CORE_ENABLE_SANITIZERS
  "Enable AddressSanitizer and UndefinedBehaviorSanitizer for Game Core tests"
  OFF
)

add_library(hwcontrol_game_core STATIC
  src/backend_selection.cpp
  src/render_graph.cpp
)
add_library(HWControl::GameCore ALIAS hwcontrol_game_core)

target_include_directories(hwcontrol_game_core
  PUBLIC $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
)
target_compile_features(hwcontrol_game_core PUBLIC cxx_std_20)
set_target_properties(hwcontrol_game_core PROPERTIES
  CXX_EXTENSIONS OFF
  POSITION_INDEPENDENT_CODE ON
)

if(MSVC)
  target_compile_options(hwcontrol_game_core PRIVATE /W4 /permissive- /sdl)
elseif(CMAKE_CXX_COMPILER_ID MATCHES "GNU|Clang|AppleClang")
  target_compile_options(hwcontrol_game_core PRIVATE
    -Wall -Wextra -Wpedantic -Wconversion -Wsign-conversion -Wshadow
    -Wnon-virtual-dtor -fstack-protector-strong
  )
endif()

if(HWCONTROL_GAME_CORE_ENABLE_SANITIZERS)
  if(CMAKE_CXX_COMPILER_ID MATCHES "GNU|Clang|AppleClang")
    target_compile_options(hwcontrol_game_core PRIVATE
      -fsanitize=address,undefined -fno-omit-frame-pointer
    )
  else()
    message(FATAL_ERROR
      "HWCONTROL_GAME_CORE_ENABLE_SANITIZERS requires GCC or Clang"
    )
  endif()
endif()

if(BUILD_TESTING)
  add_executable(hw_game_core_tests tests/game_core_tests.cpp)
  target_link_libraries(hw_game_core_tests PRIVATE HWControl::GameCore)
  target_compile_features(hw_game_core_tests PRIVATE cxx_std_20)
  set_target_properties(hw_game_core_tests PROPERTIES CXX_EXTENSIONS OFF)

  if(MSVC)
    target_compile_options(hw_game_core_tests PRIVATE /W4 /permissive- /sdl)
  elseif(CMAKE_CXX_COMPILER_ID MATCHES "GNU|Clang|AppleClang")
    target_compile_options(hw_game_core_tests PRIVATE
      -Wall -Wextra -Wpedantic -Wconversion -Wsign-conversion -Wshadow
      -fstack-protector-strong
    )
  endif()

  if(HWCONTROL_GAME_CORE_ENABLE_SANITIZERS)
    target_compile_options(hw_game_core_tests PRIVATE
      -fsanitize=address,undefined -fno-omit-frame-pointer
    )
    target_link_options(hw_game_core_tests PRIVATE
      -fsanitize=address,undefined
    )
  endif()

  add_test(NAME hw_game_core_unit COMMAND hw_game_core_tests)
endif()
