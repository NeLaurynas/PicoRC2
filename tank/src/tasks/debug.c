// Copyright (C) 2026 Laurynas 'Deviltry' Ekekeke
// SPDX-License-Identifier: BSD-3-Clause

#include <FreeRTOS.h>
#include <shared_modules/cpu_cores/cpu_cores.h>
#include <task.h>

[[noreturn]]
void task_debug(void *task_parameter) {
	(void)task_parameter;

	(void)ulTaskNotifyTake(pdTRUE, portMAX_DELAY);
	cpu_cores_shutdown_from_core0();
}
