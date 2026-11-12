add_library(hwcontrol_game_core
  src/upscaler.cpp
)
add_library(HWControl::GameCore ALIAS hwcontrol_game_core)

target_include_directories(hwcontrol_game_core
  PUBLIC
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
)
target_compile_features(hwcontrol_game_core PUBLIC cxx_std_17)
set_target_properties(hwcontrol_game_core PROPERTIES
  CXX_EXTENSIONS OFF
  POSITION_INDEPENDENT_CODE ON
)

if(MSVC)
  target_compile_options(hwcontrol_game_core PRIVATE /W4 /permissive- /GS /sdl /guard:cf)
  target_link_options(hwcontrol_game_core PRIVATE /GUARD:CF /DYNAMICBASE /NXCOMPAT)
elseif(CMAKE_CXX_COMPILER_ID MATCHES "GNU|Clang|AppleClang")
  target_compile_options(hwcontrol_game_core PRIVATE -Wall -Wextra -Wpedantic -Wconversion -fstack-protector-strong)
endif()

if(BUILD_TESTING)
  add_executable(hwcontrol_game_core_tests tests/upscaler_tests.cpp)
  target_link_libraries(hwcontrol_game_core_tests PRIVATE HWControl::GameCore)
  target_compile_features(hwcontrol_game_core_tests PRIVATE cxx_std_17)
  if(MSVC)
    target_compile_options(hwcontrol_game_core_tests PRIVATE /W4 /permissive- /GS /sdl /guard:cf)
    target_link_options(hwcontrol_game_core_tests PRIVATE /GUARD:CF /DYNAMICBASE /NXCOMPAT)
  elseif(CMAKE_CXX_COMPILER_ID MATCHES "GNU|Clang|AppleClang")
    target_compile_options(hwcontrol_game_core_tests PRIVATE -Wall -Wextra -Wpedantic -Wconversion -fstack-protector-strong)
  endif()
  add_test(NAME hwcontrol_game_core_tests COMMAND hwcontrol_game_core_tests)
endif()
