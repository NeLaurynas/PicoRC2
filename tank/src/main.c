// Copyright (C) 2026 Laurynas 'Deviltry' Ekekeke
// SPDX-License-Identifier: BSD-3-Clause

#include <FreeRTOS.h>
#include <hardware/clocks.h>
#include <pico/stdio.h>
#include <pico/time.h>
#include <stdio.h>
#include <task.h>

#include "state.h"
#include "tasks/tasks.h"

#undef PICO_FLASH_ASSERT_ON_UNSAFE
#define PICO_FLASH_ASSERT_ON_UNSAFE 0

[[noreturn]]
int main() {
	set_sys_clock_khz(48'000, false);

	stdio_init_all();

#if DBG
	sleep_ms(2000);
	printf("Slept for 2 seconds\n");
#endif

	state_init();
	tasks_create(&state.tasks.startup);

	vTaskStartScheduler();

	while (true) {
		tight_loop_contents();
	}
}
