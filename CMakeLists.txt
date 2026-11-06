cmake_minimum_required(VERSION 3.14)
project(RlnUiPlugin LANGUAGES CXX)

if(DEFINED ENV{LOGOS_MODULE_BUILDER_ROOT})
    include($ENV{LOGOS_MODULE_BUILDER_ROOT}/cmake/LogosModule.cmake)
else()
    message(FATAL_ERROR "LogosModule.cmake not found. Set LOGOS_MODULE_BUILDER_ROOT (nix provides it).")
endif()

# Module name is the single source of truth in metadata.json.
file(READ "${CMAKE_CURRENT_SOURCE_DIR}/metadata.json" METADATA_JSON)
string(JSON MODULE_NAME GET ${METADATA_JSON} name)

# Universal UI module: we write the .rep + the *Backend class. REP_FILE runs repc and the
# generated *Plugin glue is compiled automatically. modules().<dep> wrappers come from the
# dependencies declared in metadata.json.
logos_module(
    NAME ${MODULE_NAME}
    REP_FILE src/rln_ui.rep
    SOURCES
        src/rln_ui_backend.h
        src/rln_ui_backend.cpp
    INCLUDE_DIRS
        src
)
