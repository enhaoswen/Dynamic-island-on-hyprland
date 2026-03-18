cmake_minimum_required(VERSION 3.16)
project(IslandBackend VERSION 1.0 LANGUAGES CXX)

set(CMAKE_INSTALL_RPATH "$ORIGIN")
set(CMAKE_BUILD_RPATH "$ORIGIN")

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_AUTOUIC ON)

find_package(Qt6 REQUIRED COMPONENTS Core Qml Network DBus)

qt_add_qml_module(IslandBackend
    URI IslandBackend
    VERSION 1.0
    SOURCES
        SysBackend.h 
        SysBackend.cpp
)

target_link_libraries(IslandBackend PRIVATE
    Qt6::Core 
    Qt6::Qml 
    Qt6::Network 
    Qt6::DBus
)
