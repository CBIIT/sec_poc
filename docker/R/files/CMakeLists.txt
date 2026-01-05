cmake_minimum_required(VERSION 3.16)
project(my_app_project)

# Pick the C++ standard to compile with.
# Abseil currently supports C++17 and C++20.
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF) # Optional: ensures compliance without compiler-specific extensions

add_subdirectory(abseil-cpp)

add_executable(my_exe source.cpp)
target_link_libraries(my_exe absl::base absl::synchronization absl::strings)