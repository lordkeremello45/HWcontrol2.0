cmake_minimum_required(VERSION 3.16)
project(HWVisionNative LANGUAGES CXX)

include(cmake/HWVisionDependencies.cmake)

if(CMAKE_SOURCE_DIR STREQUAL CMAKE_CURRENT_SOURCE_DIR)
  include(CTest)
endif()

function(hwvision_apply_hardening target)
  target_compile_features(${target} PUBLIC cxx_std_17)
  set_target_properties(${target} PROPERTIES
    CXX_EXTENSIONS OFF POSITION_INDEPENDENT_CODE ON
  )
  if(MSVC)
    target_compile_options(${target} PRIVATE /W4 /permissive- /sdl)
  elseif(CMAKE_CXX_COMPILER_ID MATCHES "GNU|Clang|AppleClang")
    target_compile_options(${target} PRIVATE
      -Wall -Wextra -Wpedantic -Wconversion -Wsign-conversion -Wshadow
      -Wnon-virtual-dtor -fstack-protector-strong
    )
  endif()
endfunction()

add_library(hwvision_game_mode STATIC src/game_mode.cpp)
add_library(HWVision::GameMode ALIAS hwvision_game_mode)
target_include_directories(hwvision_game_mode PUBLIC
  $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
)
hwvision_apply_hardening(hwvision_game_mode)

add_library(hwvision_hdr10plus STATIC src/hdr10plus.cpp)
add_library(HWVision::Hdr10Plus ALIAS hwvision_hdr10plus)
target_include_directories(hwvision_hdr10plus PUBLIC
  $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
)
hwvision_apply_hardening(hwvision_hdr10plus)


add_library(hwvision_render_pipeline STATIC src/render_pipeline.cpp)
add_library(HWVision::RenderPipeline ALIAS hwvision_render_pipeline)
target_include_directories(hwvision_render_pipeline PUBLIC
  $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
)
hwvision_apply_hardening(hwvision_render_pipeline)

if(BUILD_TESTING)
  add_executable(hwvision_game_mode_tests tests/game_mode_tests.cpp)
  target_link_libraries(hwvision_game_mode_tests PRIVATE HWVision::GameMode)
  hwvision_apply_hardening(hwvision_game_mode_tests)
  add_test(NAME hwvision_game_mode_policy COMMAND hwvision_game_mode_tests)

  add_executable(hwvision_hdr10plus_tests tests/hdr10plus_tests.cpp)
  target_link_libraries(hwvision_hdr10plus_tests PRIVATE HWVision::Hdr10Plus)
  hwvision_apply_hardening(hwvision_hdr10plus_tests)
  add_test(NAME hwvision_hdr10plus_metadata COMMAND hwvision_hdr10plus_tests)

  add_executable(hwvision_render_pipeline_tests tests/render_pipeline_tests.cpp)
  target_link_libraries(hwvision_render_pipeline_tests PRIVATE HWVision::RenderPipeline)
  hwvision_apply_hardening(hwvision_render_pipeline_tests)
  add_test(NAME hwvision_render_pipeline COMMAND hwvision_render_pipeline_tests)
endif()
