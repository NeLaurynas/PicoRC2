// Copyright (C) 2026 Laurynas 'Deviltry' Ekekeke
// SPDX-License-Identifier: BSD-3-Clause

#include <FreeRTOS.h>
#include <stddef.h>
#include <stdint.h>
#include <task.h>

#include "frtos.h"
#include "shared_modules/memory/memory.h"
#include "state.h"
#include "storage/app_storage.h"
#include "tasks/tasks.h"

#define BYTES_IN_KIB 1024U
#define PICO2_SRAM_KIB 520U
#define CPU_SAMPLE_TICKS MS_TO_TICKS(100)
#define SYSTEM_MEMORY_SAMPLE_TICKS MS_TO_TICKS(10'000)

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
	TickType_t system_memory_last_sample = start - SYSTEM_MEMORY_SAMPLE_TICKS;
	u16 cpu_x10 = 0;
	u16 system_used_kib = 0;

	while (true) {
		const auto ticks = xTaskGetTickCount();

		if (interval_elapsed(ticks, &cpu_last_sample, CPU_SAMPLE_TICKS)) {
			float cpu_usage = 0.0f;
			(void)frtos_cpu_usage_percent(&cpu_usage);
			cpu_x10 = cpu_percent_to_x10(cpu_usage);
		}

		if (interval_elapsed(ticks, &system_memory_last_sample, SYSTEM_MEMORY_SAMPLE_TICKS)) {
			const auto system_free_bytes = memory_remaining_heap(false);
			system_used_kib = bytes_to_kib(used_bytes(system_total_bytes, system_free_bytes));
		}

		const auto freertos_total_bytes = (size_t)configTOTAL_HEAP_SIZE;
		const auto freertos_free_bytes = xPortGetFreeHeapSize();

		const system_telemetry_t telemetry = {
			.cpu_x10 = cpu_x10,
			.freertos_used_kib = bytes_to_kib(used_bytes(freertos_total_bytes, freertos_free_bytes)),
			.freertos_total_kib = bytes_to_kib(freertos_total_bytes),
			.system_used_kib = system_used_kib,
			.system_total_kib = system_total_kib,
			.boot_count = app_storage_boot_count(),
		};
		state_system_telemetry_set(&telemetry);

		tasks_delay(&state.tasks.system_monitor);
	}
}
