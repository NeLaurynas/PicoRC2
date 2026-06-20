// Copyright (C) 2026 Laurynas 'Deviltry' Ekekeke
// SPDX-License-Identifier: BSD-3-Clause

#include <FreeRTOS.h>
#include <stddef.h>
#include <task.h>
#include <utils.h>

#include "state.h"
#include "tasks/tasks.h"

static void update_tasks(task_t *const tasks[], const size_t task_count) {
	for (size_t i = 0; i < task_count; i++) {
		task_t *const task = tasks[i];
		if (unlikely(task == nullptr) || unlikely(task->handle == nullptr)) continue;

		const auto stack_watermark = uxTaskGetStackHighWaterMark(task->handle);
		task->stack_used = task->stack_depth - stack_watermark;
	}
}

static void print_tasks(task_t *const tasks[], const size_t task_count) {
	for (size_t i = 0; i < task_count; i++) {
		const task_t *const task = tasks[i];
		if (unlikely(task == nullptr)) continue;

		utils_printf(
			"tsk %s: stack - %lu/%lu words | overruns - %ld\n",
			task->name,
			(unsigned long)task->stack_used,
			(unsigned long)task->stack_depth,
			(unsigned long)task->delay_overruns
		);
	}
}

[[noreturn]]
void task_heartbeat(void *task_parameter) {
	(void)task_parameter;
	state.tasks.heartbeat.last_wake = xTaskGetTickCount();

	task_t *const tasks[] = {
		&state.tasks.heartbeat,
		&state.tasks.startup,
		&state.tasks.system_monitor,
		&state.tasks.control_input,
		&state.tasks.control_actuation,
	};

	while (true) {
		update_tasks(tasks, ARRAY_SIZE(tasks));
		print_tasks(tasks, ARRAY_SIZE(tasks));
		utils_printf("-\n");

		tasks_delay(&state.tasks.heartbeat);
	}
}
