// Copyright (C) 2026 Laurynas 'Deviltry' Ekekeke
// SPDX-License-Identifier: BSD-3-Clause

#include <FreeRTOS.h>
#include <task.h>

#include "control/actuation.h"
#include "state.h"

[[noreturn]]
void task_control_actuation(void *task_parameter) {
	(void)task_parameter;

	while (true) {
		(void)ulTaskNotifyTake(pdTRUE, portMAX_DELAY);
		control_actuation_apply();
	}
}
