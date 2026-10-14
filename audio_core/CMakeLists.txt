add_library(hwcontrol_audio_core
  src/audio_engine.cpp
  src/audio_analyzer.cpp
  src/audio_device_host.cpp
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

if(BUILD_TESTING)
  add_executable(hwcontrol_audio_core_tests tests/audio_engine_tests.cpp)
  target_link_libraries(hwcontrol_audio_core_tests PRIVATE HWControl::AudioCore)
  add_test(NAME hwcontrol_audio_core_tests COMMAND hwcontrol_audio_core_tests)
endif()
