// Copyright (C) 2026 Laurynas 'Deviltry' Ekekeke
// SPDX-License-Identifier: BSD-3-Clause

#include "hooks.h"

#include <portable.h>
#include <stdio.h>

#include "utils.h"

[[noreturn]]
void vApplicationStackOverflowHook(TaskHandle_t task, char *task_name) {
	(void)task;
	while (true)
		printf("stack overflow: %s\n", unlikely(task_name == nullptr) ? "unknown" : task_name);
}

[[noreturn]]
void vApplicationMallocFailedHook() {
	while (true)
		printf(
			"freertos malloc failed: %zu/%zu bytes free\n",
			xPortGetFreeHeapSize(),
			(size_t)configTOTAL_HEAP_SIZE
		);
}
