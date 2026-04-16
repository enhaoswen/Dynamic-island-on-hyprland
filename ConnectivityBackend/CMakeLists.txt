cmake_minimum_required(VERSION 3.21)

project(ConnectivityBackend LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_AUTOUIC ON)

find_package(Qt6 REQUIRED COMPONENTS Core DBus Qml)

qt_standard_project_setup()

add_library(ConnectivityBackendplugin SHARED
    ConnectivityBackendPlugin.cpp
    ConnectivityBackendPlugin.h
    WifiController.cpp
    WifiController.h
    WifiNetworkModel.cpp
    WifiNetworkModel.h
)

target_link_libraries(ConnectivityBackendplugin PRIVATE
    Qt6::Core
    Qt6::DBus
    Qt6::Qml
)

set_target_properties(ConnectivityBackendplugin PROPERTIES
    LIBRARY_OUTPUT_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"
    RUNTIME_OUTPUT_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"
)
