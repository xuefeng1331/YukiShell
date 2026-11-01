cmake_minimum_required(VERSION 3.21)
project(yukivideo LANGUAGES CXX)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)
find_package(Qt6 6.5 REQUIRED COMPONENTS Core Qml Multimedia)
qt_policy(SET QTP0001 NEW)
qt_add_qml_module(yukivideo
    URI YukiVideo
    VERSION 1.0
    PLUGIN_TARGET yukivideo
    OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/YukiVideo"
    SOURCES wallfeed.h wallfeed.cpp
)
target_link_libraries(yukivideo PRIVATE Qt6::Core Qt6::Qml Qt6::Multimedia)
