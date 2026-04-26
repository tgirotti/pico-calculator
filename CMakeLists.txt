set(PROJECT pico_calc)
cmake_minimum_required(VERSION 3.12)
include($ENV{PICO_SDK_PATH}/external/pico_sdk_import.cmake)
project(${PROJECT} C CXX ASM)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON) # For VSCode LSP autocomplete
pico_sdk_init()
add_executable(${PROJECT} main.c pico_calc.S)
target_link_libraries(${PROJECT} pico_stdlib)
target_compile_options(${PROJECT} PRIVATE -Wall -Werror)

pico_add_extra_outputs(${PROJECT})
pico_enable_stdio_usb(${PROJECT}  1)
pico_enable_stdio_uart(${PROJECT} 0)
