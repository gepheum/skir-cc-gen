cmake_minimum_required(VERSION 3.20)
project(skir-client CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Find dependencies
# Users must provide Abseil in their environment (via system install, FetchContent, or find_package)
# Minimum version: 20250814.0+
find_package(absl REQUIRED)

# GTest is optional (only needed for skir_testing)
find_package(GTest)

# Main skir library
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

# Testing library (optional, only if GTest is available)
if(GTest_FOUND)
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
endif()

# Install rules
# Note: When using FetchContent for dependencies, we don't export the targets
# Users should use FetchContent in their own CMakeLists.txt or use find_package
# with locally installed versions
install(TARGETS skir
  LIBRARY DESTINATION lib
  ARCHIVE DESTINATION lib
  RUNTIME DESTINATION bin
  INCLUDES DESTINATION include
)

if(GTest_FOUND)
  install(TARGETS skir_testing)
endif()

install(FILES
  skir.h
  DESTINATION include
)

if(GTest_FOUND)
  install(FILES
    skir.testing.h
    DESTINATION include
  )
endif()
