// Copyright (C) 2025 Laurynas 'Deviltry' Ekekeke
// SPDX-License-Identifier: BSD-3-Clause

#include "leds.h"

#include <hardware/gpio.h>
#include <stddef.h>
#include <utils.h>

#include "defines/config.h"
#include "shared_config.h"

void leds_init() {
	static const u8 pins[] = {
		MOD_LEDS_RED,
		MOD_LEDS_WHITE,
	};

	for (size_t i = 0; i < ARRAY_SIZE(pins); i++) {
		const u8 pin = pins[i];
		gpio_init(pin);
		gpio_set_dir(pin, true);
		gpio_set_drive_strength(pin, GPIO_DRIVE_STRENGTH_2MA);
	}
}

void leds_toggle_red(const bool on) {
	gpio_put(MOD_LEDS_RED, on);
}

void leds_toggle_white(const bool on) {
	gpio_put(MOD_LEDS_WHITE, on);
}
