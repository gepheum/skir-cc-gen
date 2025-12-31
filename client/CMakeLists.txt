cmake_minimum_required(VERSION 3.20)
project(skir-client CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# ============================================================================
# Dependencies - Use existing targets if available, otherwise find them
# ============================================================================

# Abseil - check if already provided by parent project
if(NOT TARGET absl::base)
  find_package(absl REQUIRED)
endif()

# GoogleTest - check if already provided by parent project
if(NOT TARGET GTest::gtest)
  find_package(GTest REQUIRED)
endif()

# ============================================================================
# Main skir library
# ============================================================================

add_library(skir
  skir.cc
  skir.h
)

target_include_directories(skir PUBLIC 
  $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>
  $<INSTALL_INTERFACE:include>
)

target_link_libraries(skir PUBLIC
  absl::base
  absl::flat_hash_map
  absl::hash
  absl::check
  absl::die_if_null
  absl::status
  absl::statusor
  absl::strings
  absl::time
  absl::optional
  absl::variant
)

# ============================================================================
# Testing library (interface library with header-only implementation)
# ============================================================================

add_library(skir_testing INTERFACE)

target_sources(skir_testing INTERFACE
  $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/skir.testing.h>
  $<INSTALL_INTERFACE:include/skir.testing.h>
)

target_include_directories(skir_testing INTERFACE
  $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>
  $<INSTALL_INTERFACE:include>
)

target_link_libraries(skir_testing INTERFACE
  skir
  absl::base
  absl::die_if_null
  GTest::gtest
  GTest::gmock
)
