// Copyright (C) 2026 Laurynas 'Deviltry' Ekekeke
// SPDX-License-Identifier: BSD-3-Clause

#include <FreeRTOS.h>
#include <pico/cyw43_arch.h>
#include <pico/cyw43_driver.h>
#include <pico/status_led.h>
#include <task.h>
#include <uni.h>

#include "control/actuation.h"
#include "control/input.h"
#include "state.h"
#include "tasks/tasks.h"
#include "utils.h"

struct uni_platform *get_rc_platform(void);

[[noreturn]]
void task_startup(void *task_parameter) {
	(void)task_parameter;

	control_input_init();
	control_actuation_init();

	if (cyw43_arch_init_with_country(CYW43_COUNTRY_LITHUANIA)) {
		utils_printf("failed to initialise cyw43_arch\n");
		utils_error_mode(66);
	}
	(void)status_led_init_with_context(cyw43_arch_async_context());
	cyw43_set_pio_clock_divisor(1, 0);

	cyw43_arch_gpio_put(CYW43_WL_GPIO_LED_PIN, 1);
	uni_platform_set_custom(get_rc_platform());
	uni_init(0, nullptr);

	tasks_create(&state.tasks.control_actuation);
	tasks_create(&state.tasks.control_input);

	vTaskDelete(nullptr);

	while (true) {
		taskYIELD();
	}
}

