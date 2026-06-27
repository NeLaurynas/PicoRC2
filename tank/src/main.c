// Copyright (C) 2026 Laurynas 'Deviltry' Ekekeke
// SPDX-License-Identifier: BSD-3-Clause

#include <FreeRTOS.h>
#include <pico/stdio.h>
#include <pico/time.h>
#include <stdio.h>
#include <task.h>

#include "shared_config.h"
#include "shared_modules/cpu_cores/cpu_cores.h"
#include "state.h"
#include "tasks/tasks.h"

#undef PICO_FLASH_ASSERT_ON_UNSAFE
#define PICO_FLASH_ASSERT_ON_UNSAFE 0

[[noreturn]]
int main() {
	(void)cpu_set_clock_khz(APP_SYS_CLK_KHZ, true);

	stdio_init_all();

// #if DBG
	// sleep_ms(2000);
	// printf("Slept for 2 seconds\n");
// #endif

	state_init();
	tasks_create(&state.tasks.startup);
	tasks_create(&state.tasks.shutdown);

	vTaskStartScheduler();

	while (true) {
		tight_loop_contents();
	}
}
