cmake_minimum_required(VERSION 3.16)
project(HWVisionNative LANGUAGES CXX)

if(CMAKE_SOURCE_DIR STREQUAL CMAKE_CURRENT_SOURCE_DIR)
  include(CTest)
endif()

add_library(hwvision_game_mode STATIC src/game_mode.cpp)
add_library(HWVision::GameMode ALIAS hwvision_game_mode)
target_include_directories(hwvision_game_mode PUBLIC
  $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
)
target_compile_features(hwvision_game_mode PUBLIC cxx_std_17)
set_target_properties(hwvision_game_mode PROPERTIES
  CXX_EXTENSIONS OFF POSITION_INDEPENDENT_CODE ON
)
if(MSVC)
  target_compile_options(hwvision_game_mode PRIVATE /W4 /permissive- /sdl)
elseif(CMAKE_CXX_COMPILER_ID MATCHES "GNU|Clang|AppleClang")
  target_compile_options(hwvision_game_mode PRIVATE
    -Wall -Wextra -Wpedantic -Wconversion -Wsign-conversion -Wshadow
    -Wnon-virtual-dtor -fstack-protector-strong
  )
endif()

if(BUILD_TESTING)
  add_executable(hwvision_game_mode_tests tests/game_mode_tests.cpp)
  target_link_libraries(hwvision_game_mode_tests PRIVATE HWVision::GameMode)
  target_compile_features(hwvision_game_mode_tests PRIVATE cxx_std_17)
  set_target_properties(hwvision_game_mode_tests PROPERTIES CXX_EXTENSIONS OFF)
  if(MSVC)
    target_compile_options(hwvision_game_mode_tests PRIVATE /W4 /permissive- /sdl)
  elseif(CMAKE_CXX_COMPILER_ID MATCHES "GNU|Clang|AppleClang")
    target_compile_options(hwvision_game_mode_tests PRIVATE
      -Wall -Wextra -Wpedantic -Wconversion -Wsign-conversion -Wshadow
      -fstack-protector-strong
    )
  endif()
  add_test(NAME hwvision_game_mode_policy COMMAND hwvision_game_mode_tests)
endif()
