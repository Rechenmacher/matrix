cmake_minimum_required(VERSION 3.16)
project(matrix-screensaver C)

set(CMAKE_C_STANDARD 11)

# Find required libraries
find_package(PkgConfig REQUIRED)
pkg_check_modules(GTK4 REQUIRED gtk4)

# Try webkitgtk-6.0 first (Ubuntu 24.04+, Fedora 40+),
# fall back to webkit2gtk-4.1 (Ubuntu 22.04, older distros)
pkg_check_modules(WEBKIT webkitgtk-6.0)
if(NOT WEBKIT_FOUND)
    pkg_check_modules(WEBKIT REQUIRED webkit2gtk-4.1)
    add_definitions(-DUSE_WEBKIT2GTK_4)
    message(STATUS "Using webkit2gtk-4.1 (legacy)")
else()
    message(STATUS "Using webkitgtk-6.0")
endif()

add_executable(matrix-screensaver src/main.c)

target_include_directories(matrix-screensaver PRIVATE
    ${GTK4_INCLUDE_DIRS}
    ${WEBKIT_INCLUDE_DIRS}
)

target_link_libraries(matrix-screensaver
    ${GTK4_LIBRARIES}
    ${WEBKIT_LIBRARIES}
)

target_compile_options(matrix-screensaver PRIVATE
    ${GTK4_CFLAGS_OTHER}
    ${WEBKIT_CFLAGS_OTHER}
)

# Install
install(TARGETS matrix-screensaver DESTINATION bin)
install(FILES matrix-screensaver.desktop
    DESTINATION share/applications)
install(FILES xscreensaver/matrix-webgl.xml
    DESTINATION share/xscreensaver/config OPTIONAL)
