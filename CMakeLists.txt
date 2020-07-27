cmake_minimum_required(VERSION 3.8)

project(kubus-cmake-test)

list(APPEND CMAKE_MODULE_PATH ${CMAKE_SOURCE_DIR}/cmake)

set(KUBUS_SERVER "http://localhost:9090")
include(kubus)

kubus_find_package(testlib 1.0.0 REQUIRED)
