// Copyright (C) 2026 Laurynas 'Deviltry' Ekekeke
// SPDX-License-Identifier: BSD-3-Clause

#include "control/actuation.h"

#include "modules/engine/main_engine.h"
#include "modules/engine/turret_ctrl.h"
#include "modules/leds/leds.h"

void control_actuation_init() {
	main_engine_init();
	leds_init();
	turret_ctrl_init();
}

void control_actuation_apply(const control_input_state_t *input) {
	if (input == nullptr) return;

	control_actuation_state_t *current_state = &state.actuation;

	if (current_state->btn_start != input->btn_start || current_state->btn_select != input->btn_select) {
		current_state->btn_start = input->btn_start;
		current_state->btn_select = input->btn_select;
		const bool toggle_advanced = input->btn_start && input->btn_select;
		if (toggle_advanced) {
			current_state->advanced_mode = !current_state->advanced_mode;
		}
	}

	if (current_state->btn_a != input->btn_a || current_state->btn_y != input->btn_y) {
		current_state->btn_a = input->btn_a;
		current_state->btn_y = input->btn_y;
		if (input->btn_a || input->btn_y) current_state->white_leds = !current_state->white_leds;
		leds_toggle_white(current_state->white_leds);
	}
	if (current_state->btn_x != input->btn_x || current_state->btn_b != input->btn_b) {
		current_state->btn_x = input->btn_x;
		current_state->btn_b = input->btn_b;
		if (input->btn_x || input->btn_b) current_state->red_led = !current_state->red_led;
		leds_toggle_red(current_state->red_led);
	}

	if (!input->connected) {
		if (current_state->connected) {
			main_engine_basic(0, 0);
			turret_ctrl_rotate(0);
			turret_ctrl_lift(0);
		}

		current_state->x = 0;
		current_state->y = 0;
		current_state->rx = 0;
		current_state->ry = 0;
		current_state->throttle = 0;
		current_state->brake = 0;
		current_state->connected = false;
		return;
	}

	current_state->connected = true;

	if (current_state->advanced_mode) {
		if (current_state->y != input->y || current_state->ry != input->ry) {
			current_state->y = input->y;
			current_state->ry = input->ry;
			main_engine_advanced(input->y, input->ry);
		}
	} else {
		if (
			current_state->brake != input->brake || current_state->throttle != input->throttle ||
			current_state->x != input->x
		) {
			current_state->brake = input->brake;
			current_state->throttle = input->throttle;
			current_state->x = input->x;
			main_engine_basic(input->throttle - input->brake, input->x);
		}
	}

	if (current_state->rx != input->rx) {
		current_state->rx = input->rx;
		turret_ctrl_rotate(input->rx);
	}
	if (current_state->ry != input->ry) {
		current_state->ry = input->ry;
		if (!current_state->advanced_mode) turret_ctrl_lift(input->ry);
	}
}
