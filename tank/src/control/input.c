// Copyright (C) 2026 Laurynas 'Deviltry' Ekekeke
// SPDX-License-Identifier: BSD-3-Clause

#include "control/input.h"

#include <pico/sync.h>
#include <stdlib.h>

#include "defines/config.h"

static critical_section_t input_critical_section;

static i32 xy_dead_zone(const i32 val) {
	return abs(val) <= XY_DEAD_ZONE ? 0 : val;
}

static i32 trig_dead_zone(const i32 val) {
	return val <= TRIG_DEAD_ZONE ? 0 : val;
}

static control_state_t neutral_input(const bool connected) {
	control_state_t input = { 0 };
	input.connected = connected;
	return input;
}

void control_input_init() {
	critical_section_init(&input_critical_section);
	desired_state.control = neutral_input(false);
}

void control_input_on_connected() {
	critical_section_enter_blocking(&input_critical_section);
	desired_state.control.connected = true;
	critical_section_exit(&input_critical_section);
}

void control_input_on_disconnected() {
	const auto input = neutral_input(false);
	sync_copy(&input_critical_section, &desired_state.control, &input, sizeof desired_state.control);
}

void control_input_on_gamepad(const uni_gamepad_t *gamepad) {
	if (gamepad == nullptr) return;

	control_state_t input = {
		.x = xy_dead_zone(gamepad->axis_x),
		.y = xy_dead_zone(gamepad->axis_y),
		.rx = xy_dead_zone(gamepad->axis_rx),
		.ry = xy_dead_zone(gamepad->axis_ry),
		.btn_a = (gamepad->buttons & BUTTON_A) != 0,
		.btn_x = (gamepad->buttons & BUTTON_X) != 0,
		.btn_b = (gamepad->buttons & BUTTON_B) != 0,
		.btn_y = (gamepad->buttons & BUTTON_Y) != 0,
		.btn_start = (gamepad->misc_buttons & MISC_BUTTON_START) != 0,
		.btn_select = (gamepad->misc_buttons & MISC_BUTTON_SELECT) != 0,
		.dpad_up = (gamepad->dpad & DPAD_UP) != 0,
		.dpad_down = (gamepad->dpad & DPAD_DOWN) != 0,
		.dpad_left = (gamepad->dpad & DPAD_LEFT) != 0,
		.dpad_right = (gamepad->dpad & DPAD_RIGHT) != 0,
		.throttle = trig_dead_zone(gamepad->throttle),
		.brake = trig_dead_zone(gamepad->brake),
		.connected = true,
	};

	sync_copy(&input_critical_section, &desired_state.control, &input, sizeof desired_state.control);
}
