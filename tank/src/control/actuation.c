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

void control_actuation_apply(void) {
	control_state_t *applied = &state.control;
	telemetry_t telemetry;
	state_telemetry_get(&telemetry);

	if (applied->btn_start != desired_state.control.btn_start || applied->btn_select != desired_state.control.btn_select) {
		applied->btn_start = desired_state.control.btn_start;
		applied->btn_select = desired_state.control.btn_select;
		const bool toggle_advanced = desired_state.control.btn_start && desired_state.control.btn_select;
		if (toggle_advanced) {
			applied->advanced_mode = !applied->advanced_mode;
		}
	}

	if (applied->btn_a != desired_state.control.btn_a || applied->btn_y != desired_state.control.btn_y) {
		applied->btn_a = desired_state.control.btn_a;
		applied->btn_y = desired_state.control.btn_y;
		if (desired_state.control.btn_a || desired_state.control.btn_y) applied->white_leds = !applied->white_leds;
		leds_toggle_white(applied->white_leds);
	}
	if (applied->btn_x != desired_state.control.btn_x || applied->btn_b != desired_state.control.btn_b) {
		applied->btn_x = desired_state.control.btn_x;
		applied->btn_b = desired_state.control.btn_b;
		if (desired_state.control.btn_x || desired_state.control.btn_b) applied->red_led = !applied->red_led;
		leds_toggle_red(applied->red_led);
	}

	if (!desired_state.control.connected) {
		if (applied->connected) {
			main_engine_basic(0, 0, nullptr, nullptr);
			turret_ctrl_rotate(0);
			turret_ctrl_lift(0);
		}

		applied->x = 0;
		applied->y = 0;
		applied->rx = 0;
		applied->ry = 0;
		applied->dpad_up = false;
		applied->dpad_down = false;
		applied->dpad_left = false;
		applied->dpad_right = false;
		applied->throttle = 0;
		applied->brake = 0;
		applied->connected = false;
		telemetry = (telemetry_t){
			.connected = false,
			.advanced_mode = applied->advanced_mode,
			.white_leds = applied->white_leds,
			.red_led = applied->red_led,
		};
		state_telemetry_set(&telemetry);
		return;
	}

	applied->connected = true;
	telemetry.connected = true;
	telemetry.advanced_mode = applied->advanced_mode;
	telemetry.white_leds = applied->white_leds;
	telemetry.red_led = applied->red_led;

	if (applied->advanced_mode) {
		if (applied->y != desired_state.control.y || applied->ry != desired_state.control.ry) {
			applied->y = desired_state.control.y;
			applied->ry = desired_state.control.ry;
			main_engine_advanced(desired_state.control.y, desired_state.control.ry);
			telemetry.main_left = normalized_command(desired_state.control.y, XY_DEAD_ZONE, XY_MAX);
			telemetry.main_right = normalized_command(desired_state.control.ry, XY_DEAD_ZONE, XY_MAX);
		}
	} else {
		if (
			applied->brake != desired_state.control.brake || applied->throttle != desired_state.control.throttle ||
			applied->x != desired_state.control.x
		) {
			applied->brake = desired_state.control.brake;
			applied->throttle = desired_state.control.throttle;
			applied->x = desired_state.control.x;
			i32 left;
			i32 right;
			main_engine_basic(desired_state.control.throttle - desired_state.control.brake, desired_state.control.x, &left, &right);
			telemetry.main_left = normalized_command(left, TRIG_DEAD_ZONE, TRIG_MAX);
			telemetry.main_right = normalized_command(right, TRIG_DEAD_ZONE, TRIG_MAX);
		}
	}

	if (applied->dpad_left != desired_state.control.dpad_left || applied->dpad_right != desired_state.control.dpad_right) {
		applied->dpad_left = desired_state.control.dpad_left;
		applied->dpad_right = desired_state.control.dpad_right;
		const i32 rotate = (desired_state.control.dpad_left ? -XY_MAX : 0) + (desired_state.control.dpad_right ? XY_MAX : 0);
		turret_ctrl_rotate(rotate);
		telemetry.turret_rotate = normalized_command(rotate, XY_DEAD_ZONE, XY_MAX);
	}
	if (applied->dpad_up != desired_state.control.dpad_up || applied->dpad_down != desired_state.control.dpad_down) {
		applied->dpad_up = desired_state.control.dpad_up;
		applied->dpad_down = desired_state.control.dpad_down;
		const i32 lift = (desired_state.control.dpad_up ? XY_MAX : 0) + (desired_state.control.dpad_down ? -XY_MAX : 0);
		turret_ctrl_lift(lift);
		telemetry.turret_lift = normalized_command(lift, XY_DEAD_ZONE + 200, XY_MAX);
	}

	state_telemetry_set(&telemetry);
}
