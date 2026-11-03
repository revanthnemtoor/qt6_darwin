cmake_minimum_required(VERSION 3.20)
project(qt6_darwin_smoketest LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(CMAKE_PREFIX_PATH "/opt/pacman")
set(CMAKE_IGNORE_PREFIX_PATH "/opt/local;/usr/local")

find_package(Qt6 REQUIRED COMPONENTS Core Gui Widgets Network Sql)

add_executable(qt6_smoketest main.cpp)
target_link_libraries(qt6_smoketest PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Widgets
    Qt6::Network
    Qt6::Sql
)
