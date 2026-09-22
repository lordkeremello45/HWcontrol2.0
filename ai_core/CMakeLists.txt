# ai_core/CMakeLists.txt

add_executable(ai_engine
    src/main.cpp
    src/engine.cpp
    src/telemetry.cpp
    src/bsod_shield.cpp
    src/monitor.cpp
)

target_link_libraries(ai_engine PRIVATE llama)
target_include_directories(ai_engine PRIVATE include)

include(CTest)
if(BUILD_TESTING)
    add_executable(ai_core_tests
        tests/core_tests.cpp
        src/engine.cpp
        src/telemetry.cpp
        src/bsod_shield.cpp
    )
    target_link_libraries(ai_core_tests PRIVATE llama)
    target_include_directories(ai_core_tests PRIVATE include)

    add_executable(ai_telemetry_tests
        tests/telemetry_tests.cpp
        src/telemetry.cpp
    )
    target_include_directories(ai_telemetry_tests PRIVATE include)

    add_test(NAME ai_core_tests COMMAND ai_core_tests)
    add_test(NAME ai_telemetry_tests COMMAND ai_telemetry_tests)
endif()
