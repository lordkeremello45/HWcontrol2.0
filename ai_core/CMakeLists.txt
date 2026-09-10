# ai_core/CMakeLists.txt

add_executable(ai_engine
    src/main.cpp
    src/engine.cpp
    src/bsod_shield.cpp
    src/monitor.cpp
)

# Llama kütüphanesini bağla
target_link_libraries(ai_engine PRIVATE llama)

# Include klasörünü tanıt
target_include_directories(ai_engine PRIVATE include)

# Phase 01 regression tests
include(CTest)
if(BUILD_TESTING)
    add_executable(ai_core_tests
        tests/core_tests.cpp
        src/engine.cpp
        src/bsod_shield.cpp
    )
    target_link_libraries(ai_core_tests PRIVATE llama)
    target_include_directories(ai_core_tests PRIVATE include)
    add_test(NAME ai_core_tests COMMAND ai_core_tests)
endif()
