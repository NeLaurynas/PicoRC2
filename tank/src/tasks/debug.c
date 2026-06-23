// Copyright (C) 2026 Laurynas 'Deviltry' Ekekeke
// SPDX-License-Identifier: BSD-3-Clause

#include <FreeRTOS.h>
#include <task.h>
#include <utils.h>

#include "shared_modules/cpu_cores/cpu_cores.h"
#include "state.h"
#include "tasks/tasks.h"

[[noreturn]]
void task_debug(void *task_parameter) {
	(void)task_parameter;

	state.tasks.shutdown.last_wake = 0;
	tasks_delay(&state.tasks.shutdown);

	// cpu_cores_shutdown_from_core0(); // never returns
	// utils_error_mode(36);

	state.tasks.shutdown.handle = nullptr;
	vTaskDelete(nullptr);
}
