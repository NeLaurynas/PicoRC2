// Copyright (C) 2026 Laurynas 'Deviltry' Ekekeke
// SPDX-License-Identifier: BSD-3-Clause

#include "control/input.h"

#include <pico/sync.h>

static critical_section_t input_critical_section;
static control_input_state_t latest_input = { 0 };

static control_input_state_t neutral_input(const bool connected) {
	control_input_state_t input = { 0 };
	input.connected = connected;
	return input;
}

void control_input_init() {
	critical_section_init(&input_critical_section);
	latest_input = neutral_input(false);
}

void control_input_on_connected() {
	critical_section_enter_blocking(&input_critical_section);
	latest_input.connected = true;
	critical_section_exit(&input_critical_section);
}

void control_input_on_disconnected() {
	const auto input = neutral_input(false);

	critical_section_enter_blocking(&input_critical_section);
	latest_input = input;
	critical_section_exit(&input_critical_section);
}

void control_input_on_gamepad(const uni_gamepad_t *gamepad) {
	if (gamepad == nullptr) return;

	control_input_state_t input = {
		.x = gamepad->axis_x,
		.y = gamepad->axis_y,
		.rx = gamepad->axis_rx,
		.ry = gamepad->axis_ry,
		.btn_a = (gamepad->buttons & BUTTON_A) != 0,
		.btn_x = (gamepad->buttons & BUTTON_X) != 0,
		.btn_b = (gamepad->buttons & BUTTON_B) != 0,
		.btn_y = (gamepad->buttons & BUTTON_Y) != 0,
		.btn_start = (gamepad->misc_buttons & MISC_BUTTON_START) != 0,
		.btn_select = (gamepad->misc_buttons & MISC_BUTTON_SELECT) != 0,
		.throttle = gamepad->throttle,
		.brake = gamepad->brake,
		.connected = true,
	};

	critical_section_enter_blocking(&input_critical_section);
	latest_input = input;
	critical_section_exit(&input_critical_section);
}

void control_input_sample(control_input_state_t *input) {
	if (input == nullptr) return;

	critical_section_enter_blocking(&input_critical_section);
	*input = latest_input;
	critical_section_exit(&input_critical_section);
}

