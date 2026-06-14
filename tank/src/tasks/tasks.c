// Copyright (C) 2026 Laurynas 'Deviltry' Ekekeke
// SPDX-License-Identifier: BSD-3-Clause

#include "tasks.h"

#include "utils.h"

void tasks_create(task_t *task) {
	configASSERT(task != nullptr);
	configASSERT(task->function != nullptr);
	configASSERT(task->name != nullptr);
	configASSERT(task->ticks > 0);

	task->handle = nullptr;

	[[maybe_unused]] const BaseType_t created = xTaskCreate(
		task->function,
		task->name,
		task->stack_depth,
		nullptr,
		task->priority,
		&task->handle
	);
	configASSERT(created == pdPASS);
}

void tasks_delay(task_t *task) {
	configASSERT(task != nullptr);
	configASSERT(task->ticks > 0);

	const BaseType_t delayed = xTaskDelayUntil(&task->last_wake, task->ticks);

	if (unlikely(delayed == pdFALSE) && likely(task->delay_overruns < UINT32_MAX)) {
		task->delay_overruns++;
	}
}

