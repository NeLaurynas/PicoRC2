// Copyright (C) 2026 Laurynas 'Deviltry' Ekekeke
// SPDX-License-Identifier: BSD-3-Clause

#include <FreeRTOS.h>
#include <task.h>

#include "control/input.h"
#include "state.h"
#include "tasks/tasks.h"

[[noreturn]]
void task_control_input(void *task_parameter) {
	(void)task_parameter;
	state.tasks.control_input.last_wake = xTaskGetTickCount();

	while (true) {
		control_input_state_t input;
		control_input_sample(&input);
		state_sampled_input_set(&input);

		if (state.tasks.control_actuation.handle != nullptr) {
			xTaskNotifyGive(state.tasks.control_actuation.handle);
		}

		tasks_delay(&state.tasks.control_input);
	}
}

