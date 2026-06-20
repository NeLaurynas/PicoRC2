cmake_minimum_required(VERSION 3.30)

set(PROJECT_NAME "Tank")

set(CMAKE_C_STANDARD 23)
set(CMAKE_C_EXTENSIONS ON)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

set(PICO_BOARD pico2_w CACHE STRING "Board type")

add_compile_definitions(PICO_FLASH_ASSERT_ON_UNSAFE=0)

add_compile_definitions(
		PICO_STDIO_USB_STDOUT_TIMEOUT_US=0
		CFG_TUD_CDC_TX_BUFSIZE=128
)

# DBG is defined once in shared_config.h (single source of truth). Read its value
# here so the entire build - including the pico-shared submodule and FreeRTOS - sees
# the same value, and so USB stdio can be disabled when DBG is 0.
file(STRINGS "${CMAKE_CURRENT_LIST_DIR}/shared_config.h" DBG_CONFIG_LINES
		REGEX "#[ \t]*define[ \t]+DBG[ \t]+[0-9]+")
set(DBG_VALUE 1)
foreach (DBG_CONFIG_LINE IN LISTS DBG_CONFIG_LINES)
	if (DBG_CONFIG_LINE MATCHES "#[ \t]*define[ \t]+DBG[ \t]+([0-9]+)")
		set(DBG_VALUE "${CMAKE_MATCH_1}")
	endif ()
endforeach ()
message(STATUS "PicoRC: DBG=${DBG_VALUE} (from shared_config.h)")
add_compile_definitions(DBG=${DBG_VALUE})

include($ENV{PICO_SDK_PATH}/external/pico_sdk_import.cmake)

project(${PROJECT_NAME} C CXX ASM)

pico_sdk_init()

# Flash layout.
if (NOT DEFINED FLASH_TOTAL_BYTES)
	set(FLASH_TOTAL_BYTES 4194304 CACHE STRING "Total on-board flash size (bytes)") # Pico 2 flash size - 4 mB
endif ()

# Reserve 1 MiB for LittleFS below BTstack's TLV bank and the RP2350 E10 tail sector.
set(MOD_STORAGE_SECTOR_SIZE 4096 CACHE STRING "Flash sector size (bytes)" FORCE)
set(MOD_STORAGE_SECTORS 256 CACHE STRING "Number of sectors to reserve for LittleFS" FORCE)
set(BTSTACK_FLASH_BANK_TOTAL_SIZE 8192 CACHE STRING "BTstack TLV flash bank size (bytes)" FORCE)
set(BTSTACK_FLASH_RESERVED_BYTES 12288 CACHE STRING "Flash reserved above LittleFS for BTstack and RP2350 E10" FORCE)
math(EXPR MOD_STORAGE_BYTES "${MOD_STORAGE_SECTORS} * ${MOD_STORAGE_SECTOR_SIZE}")
math(EXPR BTSTACK_FLASH_BANK_OFFSET "${FLASH_TOTAL_BYTES} - ${BTSTACK_FLASH_RESERVED_BYTES}")
math(EXPR MOD_STORAGE_OFFSET "${BTSTACK_FLASH_BANK_OFFSET} - ${MOD_STORAGE_BYTES}")
set(APP_FLASH_BYTES "${MOD_STORAGE_OFFSET}")

set(BLUEPAD32_ROOT "${CMAKE_CURRENT_LIST_DIR}/../../lib/bluepad32")
set(PICO_SHARED_SOURCE_DIR "${CMAKE_CURRENT_LIST_DIR}/../../lib/pico-shared")
set(LITTLEFS_SOURCE_DIR "${CMAKE_CURRENT_LIST_DIR}/../../lib/littlefs")
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
target_compile_definitions(bluepad32 PRIVATE
		PICO_FLASH_SIZE_BYTES=${FLASH_TOTAL_BYTES}
		PICO_FLASH_BANK_TOTAL_SIZE=${BTSTACK_FLASH_BANK_TOTAL_SIZE}
		PICO_FLASH_BANK_STORAGE_OFFSET=${BTSTACK_FLASH_BANK_OFFSET}
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
		storage/app_lfs.c
		storage/app_lfs.h
		storage/app_storage.c
		storage/app_storage.h
		tasks/control_actuation.c
		tasks/control_input.c
		tasks/heartbeat.c
		tasks/startup.c
		tasks/system_monitor.c
		tasks/tasks.c
		tasks/tasks.h
		modules/app_bt/app_bt.c
		modules/app_bt/app_bt.h
		modules/app_bt/picorc_bt_service.gatt.h
		modules/engine/turret_ctrl.c
		modules/engine/turret_ctrl.h
		modules/engine/main_engine.c
		modules/engine/main_engine.h
		modules/leds/leds.c
		modules/leds/leds.h
		modules/log_sink/log_sink.c
)

pico_set_program_name(${PROJECT_NAME} "${PROJECT_NAME}")
pico_set_program_version(${PROJECT_NAME} "0.1.0")

target_compile_definitions(${PROJECT_NAME} PRIVATE
		PICO_FLASH_SIZE_BYTES=${FLASH_TOTAL_BYTES}
		MOD_STORAGE_SECTORS=${MOD_STORAGE_SECTORS}
		MOD_STORAGE_SECTOR_SIZE=${MOD_STORAGE_SECTOR_SIZE}
		MOD_STORAGE_PAGE_SIZE=256
		MOD_STORAGE_BYTES=${MOD_STORAGE_BYTES}
		MOD_STORAGE_OFFSET=${MOD_STORAGE_OFFSET}
		PICO_FLASH_BANK_TOTAL_SIZE=${BTSTACK_FLASH_BANK_TOTAL_SIZE}
		PICO_FLASH_BANK_STORAGE_OFFSET=${BTSTACK_FLASH_BANK_OFFSET}
)

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
	pico_enable_stdio_usb(${PROJECT_NAME} ${DBG_VALUE})
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

add_library(littlefs STATIC
		${LITTLEFS_SOURCE_DIR}/lfs.c
		${LITTLEFS_SOURCE_DIR}/lfs.h
		${LITTLEFS_SOURCE_DIR}/lfs_util.c
		${LITTLEFS_SOURCE_DIR}/lfs_util.h
)
target_compile_definitions(littlefs PUBLIC
		LFS_NO_DEBUG
		LFS_NO_ERROR
		LFS_NO_MALLOC
		LFS_NO_WARN
)
target_include_directories(littlefs PUBLIC
		${LITTLEFS_SOURCE_DIR}
)
target_compile_options(littlefs PRIVATE
		${BASE_CPU_FEATURE_FLAGS}
		${BASE_SECTION_FLAGS}
		${BASE_WARNING_FLAGS}
		-Wno-unused-function
		$<$<CONFIG:Debug>:${BASE_DEBUG_FLAGS}>
		$<$<CONFIG:Release>:${BASE_RELEASE_FLAGS}>
)
target_link_options(littlefs PRIVATE
		${BASE_CPU_FEATURE_FLAGS}
)

target_link_libraries(${PROJECT_NAME}
		FreeRTOS-Kernel-Heap4
		littlefs
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
		hardware_flash
		hardware_pio
		hardware_pwm
		pico_flash
		$<$<CONFIG:Debug>:hardware_uart>
)

configure_file(
		"${PICO_SHARED_SOURCE_DIR}/memmap_storage.ld.in"
		${CMAKE_CURRENT_BINARY_DIR}/memmap_storage.ld
		@ONLY
)
pico_set_linker_script(${PROJECT_NAME} ${CMAKE_CURRENT_BINARY_DIR}/memmap_storage.ld)

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
