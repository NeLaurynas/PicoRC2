// Copyright (C) 2026 Laurynas 'Deviltry' Ekekeke
// SPDX-License-Identifier: BSD-3-Clause

#include "control/actuation.h"

#include "defines/config.h"
#include "modules/engine/engine.h"
#include "modules/leds/leds.h"

static control_state_t disconnected_control() {
	return (control_state_t){
		.white_leds = state.control.white_leds,
		.red_led = state.control.red_led,
		.advanced_mode = state.control.advanced_mode,
	};
}

void control_actuation_init() {
	main_engine_init();
	leds_init();
	turret_ctrl_init();
}

void control_actuation_apply() {
	telemetry_t telemetry;
	state_telemetry_sync_load(&telemetry);

	if (state.control.btn_start != desired_state.control.btn_start || state.control.btn_select != desired_state.control.btn_select) {
		state.control.btn_start = desired_state.control.btn_start;
		state.control.btn_select = desired_state.control.btn_select;
		const bool toggle_advanced = desired_state.control.btn_start && desired_state.control.btn_select;
		if (toggle_advanced) {
			state.control.advanced_mode = !state.control.advanced_mode;
		}
	}

	if (state.control.btn_a != desired_state.control.btn_a || state.control.btn_y != desired_state.control.btn_y) {
		state.control.btn_a = desired_state.control.btn_a;
		state.control.btn_y = desired_state.control.btn_y;
		if (desired_state.control.btn_a || desired_state.control.btn_y) state.control.white_leds = !state.control.white_leds;
		leds_toggle_white(state.control.white_leds);
	}
	if (state.control.btn_x != desired_state.control.btn_x || state.control.btn_b != desired_state.control.btn_b) {
		state.control.btn_x = desired_state.control.btn_x;
		state.control.btn_b = desired_state.control.btn_b;
		if (desired_state.control.btn_x || desired_state.control.btn_b) state.control.red_led = !state.control.red_led;
		leds_toggle_red(state.control.red_led);
	}

	if (!desired_state.control.connected) {
		if (state.control.connected) {
			(void)main_engine_basic(0, 0);
			turret_ctrl_rotate(0);
			turret_ctrl_lift(0);
		}

		state.control = disconnected_control();
		telemetry = (telemetry_t){
			.connected = false,
			.advanced_mode = state.control.advanced_mode,
			.white_leds = state.control.white_leds,
			.red_led = state.control.red_led,
		};
		state_telemetry_sync_store(&telemetry);
		return;
	}

	state.control.connected = true;
	telemetry.connected = true;
	telemetry.advanced_mode = state.control.advanced_mode;
	telemetry.white_leds = state.control.white_leds;
	telemetry.red_led = state.control.red_led;

	if (state.control.advanced_mode) {
		if (state.control.y != desired_state.control.y || state.control.ry != desired_state.control.ry) {
			state.control.y = desired_state.control.y;
			state.control.ry = desired_state.control.ry;
			const auto main = main_engine_advanced(desired_state.control.y, desired_state.control.ry);
			telemetry.main_left = main.left;
			telemetry.main_right = main.right;
		}
	} else {
		if (
			state.control.brake != desired_state.control.brake || state.control.throttle != desired_state.control.throttle ||
			state.control.x != desired_state.control.x
		) {
			state.control.brake = desired_state.control.brake;
			state.control.throttle = desired_state.control.throttle;
			state.control.x = desired_state.control.x;
			const auto main = main_engine_basic(desired_state.control.throttle - desired_state.control.brake, desired_state.control.x);
			telemetry.main_left = main.left;
			telemetry.main_right = main.right;
		}
	}

	if (state.control.dpad_left != desired_state.control.dpad_left || state.control.dpad_right != desired_state.control.dpad_right) {
		state.control.dpad_left = desired_state.control.dpad_left;
		state.control.dpad_right = desired_state.control.dpad_right;
		const i32 rotate = (desired_state.control.dpad_left ? -XY_MAX : 0) + (desired_state.control.dpad_right ? XY_MAX : 0);
		telemetry.turret_rotate = turret_ctrl_rotate(rotate);
	}
	if (state.control.dpad_up != desired_state.control.dpad_up || state.control.dpad_down != desired_state.control.dpad_down) {
		state.control.dpad_up = desired_state.control.dpad_up;
		state.control.dpad_down = desired_state.control.dpad_down;
		const i32 lift = (desired_state.control.dpad_up ? XY_MAX : 0) + (desired_state.control.dpad_down ? -XY_MAX : 0);
		telemetry.turret_lift = turret_ctrl_lift(lift);
	}

	state_telemetry_sync_store(&telemetry);
}
