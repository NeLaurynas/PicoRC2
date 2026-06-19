// Copyright (C) 2026 Laurynas 'Deviltry' Ekekeke
// SPDX-License-Identifier: BSD-3-Clause

#include "control/actuation.h"

#include "defines/config.h"
#include "modules/engine/main_engine.h"
#include "modules/engine/turret_ctrl.h"
#include "modules/leds/leds.h"
#include "utils.h"

static i8 normalized_command(const i32 val, const i32 deadzone, const i32 max_val) {
	const auto magnitude = utils_scaled_pwm_percentage(val, deadzone, max_val);
	return (i8)(val < 0 ? -magnitude : magnitude);
}

void control_actuation_init() {
	main_engine_init();
	leds_init();
	turret_ctrl_init();
}

void control_actuation_apply(const control_input_state_t *input) {
	if (input == nullptr) return;

	control_actuation_state_t *current_state = &state.actuation;
	telemetry_t telemetry;
	state_telemetry_get(&telemetry);

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
			main_engine_basic(0, 0, nullptr, nullptr);
			turret_ctrl_rotate(0);
			turret_ctrl_lift(0);
		}

		current_state->x = 0;
		current_state->y = 0;
		current_state->rx = 0;
		current_state->ry = 0;
		current_state->dpad_up = false;
		current_state->dpad_down = false;
		current_state->dpad_left = false;
		current_state->dpad_right = false;
		current_state->throttle = 0;
		current_state->brake = 0;
		current_state->connected = false;
		telemetry = (telemetry_t){
			.connected = false,
			.advanced_mode = current_state->advanced_mode,
			.white_leds = current_state->white_leds,
			.red_led = current_state->red_led,
		};
		state_telemetry_set(&telemetry);
		return;
	}

	current_state->connected = true;
	telemetry.connected = true;
	telemetry.advanced_mode = current_state->advanced_mode;
	telemetry.white_leds = current_state->white_leds;
	telemetry.red_led = current_state->red_led;

	if (current_state->advanced_mode) {
		if (current_state->y != input->y || current_state->ry != input->ry) {
			current_state->y = input->y;
			current_state->ry = input->ry;
			main_engine_advanced(input->y, input->ry);
			telemetry.main_left = normalized_command(input->y, XY_DEAD_ZONE, XY_MAX);
			telemetry.main_right = normalized_command(input->ry, XY_DEAD_ZONE, XY_MAX);
		}
	} else {
		if (
			current_state->brake != input->brake || current_state->throttle != input->throttle ||
			current_state->x != input->x
		) {
			current_state->brake = input->brake;
			current_state->throttle = input->throttle;
			current_state->x = input->x;
			i32 left;
			i32 right;
			main_engine_basic(input->throttle - input->brake, input->x, &left, &right);
			telemetry.main_left = normalized_command(left, TRIG_DEAD_ZONE, TRIG_MAX);
			telemetry.main_right = normalized_command(right, TRIG_DEAD_ZONE, TRIG_MAX);
		}
	}

	if (current_state->dpad_left != input->dpad_left || current_state->dpad_right != input->dpad_right) {
		current_state->dpad_left = input->dpad_left;
		current_state->dpad_right = input->dpad_right;
		const i32 rotate = (input->dpad_left ? -XY_MAX : 0) + (input->dpad_right ? XY_MAX : 0);
		turret_ctrl_rotate(rotate);
		telemetry.turret_rotate = normalized_command(rotate, XY_DEAD_ZONE, XY_MAX);
	}
	if (current_state->dpad_up != input->dpad_up || current_state->dpad_down != input->dpad_down) {
		current_state->dpad_up = input->dpad_up;
		current_state->dpad_down = input->dpad_down;
		const i32 lift = (input->dpad_up ? XY_MAX : 0) + (input->dpad_down ? -XY_MAX : 0);
		turret_ctrl_lift(lift);
		telemetry.turret_lift = normalized_command(lift, XY_DEAD_ZONE + 200, XY_MAX);
	}

	state_telemetry_set(&telemetry);
}
