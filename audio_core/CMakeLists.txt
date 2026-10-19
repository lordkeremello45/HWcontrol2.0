add_library(hwcontrol_audio_core
  src/audio_engine.cpp
  src/audio_analyzer.cpp
  src/loudness_meter.cpp
  src/audio_device_host.cpp
  src/argon_enhancer.cpp
)
add_library(HWControl::AudioCore ALIAS hwcontrol_audio_core)

target_include_directories(hwcontrol_audio_core
  PUBLIC
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
)
target_compile_features(hwcontrol_audio_core PUBLIC cxx_std_17)
target_include_directories(hwcontrol_audio_core PRIVATE "${miniaudio_SOURCE_DIR}")
target_link_libraries(hwcontrol_audio_core PRIVATE Threads::Threads ${CMAKE_DL_LIBS})
if(UNIX AND NOT APPLE)
  target_link_libraries(hwcontrol_audio_core PRIVATE m)
endif()
if(APPLE)
  target_link_libraries(hwcontrol_audio_core PRIVATE
    "-framework CoreAudio"
    "-framework AudioToolbox"
    "-framework AudioUnit"
    "-framework CoreFoundation"
  )
endif()
if(WIN32)
  target_compile_definitions(hwcontrol_audio_core PRIVATE NOMINMAX WIN32_LEAN_AND_MEAN)
  target_link_libraries(hwcontrol_audio_core PRIVATE ole32 winmm)
endif()
set_target_properties(hwcontrol_audio_core PROPERTIES
  CXX_EXTENSIONS OFF
  POSITION_INDEPENDENT_CODE ON
)

if(MSVC)
  target_compile_options(hwcontrol_audio_core PRIVATE /W4 /permissive-)
else()
  target_compile_options(hwcontrol_audio_core PRIVATE -Wall -Wextra -Wpedantic -Wconversion)
endif()

option(HWCONTROL_BUILD_AUDIO_PROBE "Build the local audio device probe utility" ON)
if(HWCONTROL_BUILD_AUDIO_PROBE)
  add_executable(hwcontrol_audio_probe tools/audio_device_probe.cpp)
  target_link_libraries(hwcontrol_audio_probe PRIVATE HWControl::AudioCore)
  target_compile_features(hwcontrol_audio_probe PRIVATE cxx_std_17)
endif()

if(BUILD_TESTING)
  add_executable(hwcontrol_audio_core_tests tests/audio_engine_tests.cpp)
  target_link_libraries(hwcontrol_audio_core_tests PRIVATE HWControl::AudioCore)
  add_test(NAME hwcontrol_audio_core_tests COMMAND hwcontrol_audio_core_tests)

  add_executable(argon_enhancer_tests tests/argon_enhancer_tests.cpp)
  target_link_libraries(argon_enhancer_tests PRIVATE HWControl::AudioCore)
  target_compile_features(argon_enhancer_tests PRIVATE cxx_std_17)
  add_test(NAME argon_enhancer_tests COMMAND argon_enhancer_tests)
  if(HWCONTROL_BUILD_AUDIO_PROBE)
    add_test(NAME hwcontrol_audio_probe_json COMMAND hwcontrol_audio_probe --json)
  endif()
endif()
