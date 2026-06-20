// Copyright (C) 2026 Laurynas 'Deviltry' Ekekeke
// SPDX-License-Identifier: BSD-3-Clause

#include <FreeRTOS.h>
#include <task.h>
#include <utils.h>

#include "state.h"
#include "tasks/tasks.h"

[[noreturn]]
void task_control_input(void *task_parameter) {
	(void)task_parameter;
	state.tasks.control_input.last_wake = xTaskGetTickCount();

	while (true) {
		if (likely(state.tasks.control_actuation.handle != nullptr)) {
			xTaskNotifyGive(state.tasks.control_actuation.handle);
		}

		tasks_delay(&state.tasks.control_input);
	}
}
