// Copyright (C) 2026 Laurynas 'Deviltry' Ekekeke
// SPDX-License-Identifier: BSD-3-Clause

#include <FreeRTOS.h>
#include <pico/cyw43_arch.h>
#include <pico/cyw43_driver.h>
#include <task.h>
#include <uni.h>
#include <utils.h>

#include "control/actuation.h"
#include "control/input.h"
#include "state.h"
#include "storage/app_storage.h"
#include "tasks/tasks.h"

struct uni_platform *get_rc_platform();

[[noreturn]]
void task_startup(void *task_parameter) {
	(void)task_parameter;

	if (cyw43_arch_init_with_country(CYW43_COUNTRY_LITHUANIA)) {
		utils_printf("failed to initialise cyw43_arch\n");
		utils_error_mode(11); // this will not blink but it's ok, as this is enormous failure - everything's fucked anyways
	}
	(void)utils_internal_led_init(cyw43_arch_async_context());
	utils_internal_led(true);

	if (!app_storage_init()) {
		utils_error_mode(21);
	}

	control_input_init();
	control_actuation_init();

	uni_platform_set_custom(get_rc_platform());
	uni_init(0, nullptr);

	tasks_create(&state.tasks.heartbeat);
	tasks_create(&state.tasks.system_monitor);
	tasks_create(&state.tasks.control_actuation);
	tasks_create(&state.tasks.control_input);

	const auto stack_watermark = uxTaskGetStackHighWaterMark(nullptr);
	state.tasks.startup.stack_used = state.tasks.startup.stack_depth - stack_watermark;
	state.tasks.startup.handle = nullptr;

	vTaskDelete(nullptr);
}
