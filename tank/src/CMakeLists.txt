cmake_minimum_required(VERSION 3.30)

set(PROJECT_NAME "Tank")

set(CMAKE_C_STANDARD 23)
set(CMAKE_C_EXTENSIONS ON)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

set(PICO_BOARD pico2_w CACHE STRING "Board type")

add_compile_definitions(PICO_FLASH_ASSERT_ON_UNSAFE=0)

include($ENV{PICO_SDK_PATH}/external/pico_sdk_import.cmake)

project(${PROJECT_NAME} C CXX ASM)

pico_sdk_init()

set(BLUEPAD32_ROOT "${CMAKE_CURRENT_LIST_DIR}/../../lib/bluepad32")
set(PICO_SHARED_SOURCE_DIR "${CMAKE_CURRENT_LIST_DIR}/../../lib/pico-shared")
set(BTSTACK_ROOT "${PICO_SDK_PATH}/lib/btstack")

set(FREERTOS_CONFIG_FILE_DIRECTORY "${CMAKE_CURRENT_LIST_DIR}")

if (NOT FREERTOS_KERNEL_PATH AND (NOT DEFINED ENV{FREERTOS_KERNEL_PATH} OR "$ENV{FREERTOS_KERNEL_PATH}" STREQUAL ""))
	set(FREERTOS_KERNEL_PATH
			"${CMAKE_CURRENT_LIST_DIR}/../../lib/FreeRTOS-Kernel"
			CACHE PATH "Path to the FreeRTOS Kernel"
	)
endif ()

include(FreeRTOS_Kernel_import.cmake)

if (NOT TARGET FreeRTOS-Kernel-Heap4)
	message(FATAL_ERROR "FreeRTOS import did not expose FreeRTOS-Kernel-Heap4")
endif ()

set(BASE_CPU_FEATURE_FLAGS
		-mcpu=cortex-m33
		-mtune=cortex-m33
		-mfpu=fpv5-sp-d16
		-mthumb
)

set(BASE_SECTION_FLAGS
		-ffunction-sections
		-fdata-sections
)

set(BASE_WARNING_FLAGS
		-Wall
		-Wextra
		-Winline
		-Wno-error=old-style-declaration
)

set(BASE_DEBUG_FLAGS
		-Og
		-g3
)

set(BASE_RELEASE_FLAGS
		-O1
		-g0
)

add_subdirectory("${PICO_SHARED_SOURCE_DIR}" "${CMAKE_BINARY_DIR}/pico-shared")
add_subdirectory("${BLUEPAD32_ROOT}/src/components/bluepad32" "${CMAKE_BINARY_DIR}/bluepad32")
target_include_directories(bluepad32 PRIVATE
		${CMAKE_CURRENT_SOURCE_DIR}
)

add_executable(${PROJECT_NAME}
		FreeRTOSConfig.h
		btstack_config.h
		control/actuation.c
		control/actuation.h
		control/input.c
		control/input.h
		defines/config.h
		hooks.c
		hooks.h
		main.c
		rc_platform.c
		sdkconfig.h
		shared_config.h
		state.c
		state.h
		tasks/control_actuation.c
		tasks/control_input.c
		tasks/startup.c
		tasks/tasks.c
		tasks/tasks.h
		modules/engine/turret_ctrl.c
		modules/engine/turret_ctrl.h
		modules/engine/main_engine.c
		modules/engine/main_engine.h
		modules/leds/leds.c
		modules/leds/leds.h
)

pico_set_program_name(${PROJECT_NAME} "${PROJECT_NAME}")
pico_set_program_version(${PROJECT_NAME} "0.1.0")

target_compile_options(${PROJECT_NAME} PRIVATE
		${BASE_CPU_FEATURE_FLAGS}
		${BASE_SECTION_FLAGS}
		${BASE_WARNING_FLAGS}
		$<$<CONFIG:Debug>:${BASE_DEBUG_FLAGS}>
		$<$<CONFIG:Release>:${BASE_RELEASE_FLAGS}>
)

target_compile_options(${PROJECT_NAME} PRIVATE
		$<$<COMPILE_LANGUAGE:C>:-Wno-old-style-declaration>
)

target_compile_definitions(${PROJECT_NAME} PUBLIC
		PICO_MALLOC_PANIC=0
		PICO_FLASH_ASSUME_CORE1_SAFE=1
)

target_compile_definitions(${PROJECT_NAME} PRIVATE
		CYW43_PIO_CLOCK_DIV_DYNAMIC=1
)

target_link_options(${PROJECT_NAME} PRIVATE
		${BASE_CPU_FEATURE_FLAGS}
		-Wl,--gc-sections
		$<$<CONFIG:Release>:-Wl,--strip-all>
)

if (CMAKE_BUILD_TYPE STREQUAL "Debug")
	pico_enable_stdio_uart(${PROJECT_NAME} 1)
	pico_enable_stdio_usb(${PROJECT_NAME} 0)
elseif (CMAKE_BUILD_TYPE STREQUAL "Release")
	pico_enable_stdio_uart(${PROJECT_NAME} 0)
	pico_enable_stdio_usb(${PROJECT_NAME} 1)
else ()
	message(WARNING "Unhandled build type: ${CMAKE_BUILD_TYPE}")
endif ()

target_include_directories(${PROJECT_NAME} PRIVATE
		${CMAKE_CURRENT_SOURCE_DIR}
		${BLUEPAD32_ROOT}/src/components/bluepad32/include
		${BTSTACK_ROOT}/3rd-party/bluedroid/encoder/include
		${BTSTACK_ROOT}/3rd-party/bluedroid/decoder/include
		${BTSTACK_ROOT}/src
)

target_link_libraries(${PROJECT_NAME}
		FreeRTOS-Kernel-Heap4
		pico_shared_frtos
		pico_shared_utils
		pico_shared_memory
		pico_status_led
		pico_stdlib
)

target_link_libraries(${PROJECT_NAME}
		bluepad32
		pico_cyw43_arch_none
		pico_btstack_ble
		pico_btstack_classic
		pico_btstack_cyw43
		hardware_clocks
		hardware_dma
		hardware_pio
		hardware_pwm
		$<$<CONFIG:Debug>:hardware_uart>
)

pico_add_extra_outputs(${PROJECT_NAME})

if (CMAKE_BUILD_TYPE STREQUAL "Release")
	add_custom_command(
			TARGET ${PROJECT_NAME}
			POST_BUILD
			COMMAND /opt/homebrew/bin/picotool load -f ${PROJECT_NAME}.uf2
	)
endif ()

if (CMAKE_BUILD_TYPE STREQUAL "Debug")
	add_custom_command(
			TARGET ${PROJECT_NAME}
			POST_BUILD
			COMMAND /usr/local/bin/openocd -s tcl -f interface/cmsis-dap.cfg -f target/rp2350.cfg -c "adapter speed 5000" -c "program ${PROJECT_NAME}.elf verify reset exit"
	)
endif ()
