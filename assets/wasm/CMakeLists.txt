cmake_minimum_required(VERSION 3.20)
project(sqlite3_wasm C)

# Ensure we're targeting WASM
if(NOT CMAKE_SYSTEM_NAME STREQUAL "WASI")
    message(FATAL_ERROR "This CMakeLists.txt is for WASM builds only")
endif()

# WASM-specific compiler flags
set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} \
    -Ofast \
    -nostartfiles \
    -Wl,--import-memory \
    -Wl,--no-entry \
    -Wl,--export-dynamic \
    -DSQLITE_API='__attribute__((visibility(\"default\")))' \
    -DSQLITE_THREADSAFE=0 \
    -DSQLITE_DISABLE_LFS"
)

# Source files
set(SOURCES
    ../../sqlite/sqlite3.c
    os_web_minimal.c
)

# Create the WASM library
add_executable(sqlite3_wasm ${SOURCES})

# Set output name to include .wasm extension
set_target_properties(sqlite3_wasm PROPERTIES 
    OUTPUT_NAME "sqlite3"
    SUFFIX ".wasm"
)

# Custom post-build optimization (if wasm-strip is available)
find_program(WASM_STRIP wasm-strip)
if(WASM_STRIP)
    add_custom_command(TARGET sqlite3_wasm POST_BUILD
        COMMAND ${WASM_STRIP} sqlite3.wasm
        COMMENT "Stripping debug symbols from WASM binary"
        WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
    )
endif()