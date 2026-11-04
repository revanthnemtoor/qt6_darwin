cmake_minimum_required(VERSION 3.20)
project(qt6_darwin_smoketest LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Enable moc, rcc, and uic developer tool integration
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_AUTOUIC ON)

set(CMAKE_PREFIX_PATH "/opt/pacman")
set(CMAKE_IGNORE_PREFIX_PATH "/opt/local;/usr/local")

find_package(Qt6 REQUIRED COMPONENTS
    Core
    Gui
    Widgets
    Network
    Sql
    Svg
    SvgWidgets
    OpenGL
    OpenGLWidgets
    UiTools
    Help
    Qml
    Quick
    QuickWidgets
    QuickTimeline
    Quick3D
    Multimedia
    SpatialAudio
    NetworkAuth
    WebSockets
    SerialPort
    Bluetooth
)

add_executable(qt6_smoketest main.cpp)
target_link_libraries(qt6_smoketest PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Widgets
    Qt6::Network
    Qt6::Sql
    Qt6::Svg
    Qt6::SvgWidgets
    Qt6::OpenGL
    Qt6::OpenGLWidgets
    Qt6::UiTools
    Qt6::Help
    Qt6::Qml
    Qt6::Quick
    Qt6::QuickWidgets
    Qt6::QuickTimeline
    Qt6::Quick3D
    Qt6::Multimedia
    Qt6::SpatialAudio
    Qt6::NetworkAuth
    Qt6::WebSockets
    Qt6::SerialPort
    Qt6::Bluetooth
)
