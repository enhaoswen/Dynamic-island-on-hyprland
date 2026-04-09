cmake_minimum_required(VERSION 3.16)
project(LyricsProviderTest LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

find_package(Qt6 REQUIRED COMPONENTS Core)

add_executable(test_lyrics
    main.cpp
    LyricsProvider.cpp
    LyricsProvider.h
)

target_link_libraries(test_lyrics PRIVATE Qt6::Core)
