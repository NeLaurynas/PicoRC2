// Copyright (C) 2026 Laurynas 'Deviltry' Ekekeke
// SPDX-License-Identifier: BSD-3-Clause

#include <FreeRTOS.h>
#include <frtos.h>
#include <pico/time.h>
#include <shared_modules/cpu_cores/cpu_cores.h>
#include <shared_modules/memory/memory.h>
#include <shared_modules/v_monitor/v_monitor.h>
#include <stddef.h>
#include <stdint.h>
#include <task.h>
#include <utils.h>

#include "state.h"
#include "storage/app_storage.h"
#include "tasks/tasks.h"

#define BYTES_IN_KIB 1024U
#define PICO2_SRAM_KIB 520U
#define CPU_TEMP_EMA_ALPHA 0.07f
#define CPU_SAMPLE_TICKS MS_TO_TICKS(100)
#define BATTERY_LOG_TICKS SECONDS_TO_TICKS(1)
#define BATTERY_SHUTDOWN_V_X100 660U
#define SYSTEM_MEMORY_SAMPLE_TICKS MS_TO_TICKS(10'000)

static bool sys_led_on = true;

static u16 bytes_to_kib(const size_t bytes) {
	const auto kib = bytes / BYTES_IN_KIB;
	return kib > UINT16_MAX ? UINT16_MAX : (u16)kib;
}

static size_t used_bytes(const size_t total, const size_t free) {
	return free > total ? 0 : total - free;
}

static u16 cpu_percent_to_x10(const float percent) {
	if (percent <= 0.0f) return 0;
	if (percent >= 100.0f) return 1000;
	return (u16)(percent * 10.0f + 0.5f);
}

static u16 cpu_mhz_to_x100(const float mhz) {
	if (mhz <= 0.0f) return 0;
	if (mhz >= (float)UINT16_MAX / 100.0f) return UINT16_MAX;
	return (u16)(mhz * 100.0f + 0.5f);
}

static u16 voltage_to_x100(const float voltage) {
	if (voltage <= 0.0f) return 0;
	if (voltage >= (float)UINT16_MAX / 100.0f) return UINT16_MAX;
	return (u16)(voltage * 100.0f + 0.5f);
}

static i16 cpu_temp_to_x100(const float temp_c) {
	if (temp_c <= (float)INT16_MIN / 100.0f) return INT16_MIN;
	if (temp_c >= (float)INT16_MAX / 100.0f) return INT16_MAX;
	return (i16)(temp_c * 100.0f + (temp_c >= 0.0f ? 0.5f : -0.5f));
}

static void sample_voltage() {
	taskENTER_CRITICAL();
	v_monitor_sample(true);
	taskEXIT_CRITICAL();
}

static float sample_temp() {
	taskENTER_CRITICAL();
	const auto temp_c = cpu_temp(false);
	taskEXIT_CRITICAL();

	return temp_c;
}

static void request_shutdown() {
	const auto shutdown_task = state.tasks.shutdown.handle;
	if (shutdown_task == nullptr) {
		cpu_cores_shutdown_from_core0();
	}

	(void)xTaskNotifyGive(shutdown_task);
}

// Returns true once `period` ticks have elapsed since `*last`, advancing `*last`
// to `now` when it does. Unsigned tick subtraction keeps it wrap-safe.
static bool interval_elapsed(const TickType_t now, TickType_t *const last, const TickType_t period) {
	if (now - *last < period) return false;
	*last = now;
	return true;
}

[[noreturn]]
void task_system_monitor(void *task_parameter) {
	(void)task_parameter;
	const auto start = xTaskGetTickCount();
	state.tasks.system_monitor.last_wake = start;

	constexpr size_t system_total_bytes = PICO2_SRAM_KIB * BYTES_IN_KIB;
	const u16 system_total_kib = bytes_to_kib(system_total_bytes);

	// Seed sample times one period in the past so both sample on the first loop.
	TickType_t cpu_last_sample = start - CPU_SAMPLE_TICKS;
	TickType_t battery_log_last = start - BATTERY_LOG_TICKS;
	TickType_t system_memory_last_sample = start - SYSTEM_MEMORY_SAMPLE_TICKS;
	u16 cpu_x10 = 0;
	u16 cpu_speed_mhz_x100 = 0;
	float cpu_temp_c = 0.0f;
	i16 cpu_temp_c_x100 = 0;
	bool cpu_temp_valid = false;
	u16 system_used_kib = 0;
	u16 battery_voltage_v_x100 = 0;

	while (true) {
		const auto ticks = xTaskGetTickCount();

		utils_internal_led(sys_led_on);
		sys_led_on = !sys_led_on;

		sample_voltage();
		const bool print_battery = state.app_settings.debug_logs && interval_elapsed(ticks, &battery_log_last, BATTERY_LOG_TICKS);
		battery_voltage_v_x100 = voltage_to_x100(v_monitor_voltage(print_battery));
		if (battery_voltage_v_x100 < BATTERY_SHUTDOWN_V_X100) {
			request_shutdown();
		}

		if (interval_elapsed(ticks, &cpu_last_sample, CPU_SAMPLE_TICKS)) {
			float cpu_usage = 0.0f;
			(void)frtos_cpu_usage_percent(&cpu_usage);
			cpu_x10 = cpu_percent_to_x10(cpu_usage);
			cpu_speed_mhz_x100 = cpu_mhz_to_x100(cpu_speed(false));
			const auto raw_temp_c = sample_temp();
			if (!cpu_temp_valid) {
				cpu_temp_c = raw_temp_c;
				cpu_temp_valid = true;
			} else {
				cpu_temp_c += (raw_temp_c - cpu_temp_c) * CPU_TEMP_EMA_ALPHA;
			}
			cpu_temp_c_x100 = cpu_temp_to_x100(cpu_temp_c);
		}

		if (interval_elapsed(ticks, &system_memory_last_sample, SYSTEM_MEMORY_SAMPLE_TICKS)) {
			const auto system_free_bytes = memory_remaining_heap(false);
			system_used_kib = bytes_to_kib(used_bytes(system_total_bytes, system_free_bytes));
		}

		const auto freertos_total_bytes = (size_t)configTOTAL_HEAP_SIZE;
		const auto freertos_free_bytes = xPortGetFreeHeapSize();

		const u32 uptime_seconds = to_ms_since_boot(get_absolute_time()) / 1000U;

		const system_telemetry_t telemetry = {
			.cpu_x10 = cpu_x10,
			.cpu_speed_mhz_x100 = cpu_speed_mhz_x100,
			.cpu_temp_c_x100 = cpu_temp_c_x100,
			.freertos_used_kib = bytes_to_kib(used_bytes(freertos_total_bytes, freertos_free_bytes)),
			.freertos_total_kib = bytes_to_kib(freertos_total_bytes),
			.system_used_kib = system_used_kib,
			.system_total_kib = system_total_kib,
			.boot_count = state.app_data.boot_count,
			.battery_voltage_v_x100 = battery_voltage_v_x100,
			.uptime_seconds = uptime_seconds,
		};
		state_system_telemetry_sync_store(&telemetry);

		tasks_delay(&state.tasks.system_monitor);
	}
}
