cmake_minimum_required(VERSION 3.10)
project(flutter_filament_plugin LANGUAGES CXX)

set(PLUGIN_NAME "flutter_filament_plugin")

add_library(${PLUGIN_NAME} SHARED
  "flutter_filament_plugin.cc"
)

apply_standard_settings(${PLUGIN_NAME})

target_compile_definitions(${PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL)

target_include_directories(${PLUGIN_NAME} PUBLIC
  "include"
)

target_link_libraries(${PLUGIN_NAME} PRIVATE flutter)
target_link_libraries(${PLUGIN_NAME} PRIVATE PkgConfig::GTK)
