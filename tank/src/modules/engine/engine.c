// Copyright (C) 2025 Laurynas 'Deviltry' Ekekeke
// SPDX-License-Identifier: BSD-3-Clause

#include "engine.h"

#include <hardware/gpio.h>
#include <hardware/pwm.h>
#include <pico/time.h>
#include <stdlib.h>
#include <utils.h>

#include "defines/config.h"
#include "state.h"

typedef struct {
	u8 slice;
	u8 channel;
} pwm_gpio_t;

typedef struct {
	u8 positive_pin;
	u8 negative_pin;
	u16 *cc;
} pwm_motor_t;

static constexpr u8 no_pin = 0b11111111;
static constexpr u16 main_pwm_top = 100;
static constexpr u16 main_pwm_full = main_pwm_top + 1;
static constexpr u16 turret_pwm_top = 10000;
static constexpr u16 turret_pwm_full = turret_pwm_top + 1;

static pwm_motor_t main_left = {.positive_pin = no_pin, .negative_pin = MOD_ENGINE_MAIN_ENABLE1};
static pwm_motor_t main_right = {.positive_pin = no_pin, .negative_pin = MOD_ENGINE_MAIN_ENABLE2};
static pwm_motor_t turret_rotate = {.positive_pin = MOD_TURRET_CTRL_ENABLE1, .negative_pin = MOD_TURRET_CTRL_ENABLE2};

static void output_init(const u8 pin) {
	gpio_init(pin);
	gpio_set_dir(pin, true);
}

static void outputs_init(const u8 pins[], const size_t count) {
	for (size_t i = 0; i < count; i++) output_init(pins[i]);
}

static pwm_gpio_t init_pwm(const u8 pin, const u16 top, const float clk_div) {
	gpio_set_function(pin, GPIO_FUNC_PWM);
	const u8 slice = pwm_gpio_to_slice_num(pin);
	const u8 channel = pwm_gpio_to_channel(pin);

	auto cfg = pwm_get_default_config();
	cfg.top = top;
	pwm_init(slice, &cfg, false);
	pwm_set_clkdiv(slice, clk_div);
	pwm_set_phase_correct(slice, false);
	pwm_set_enabled(slice, true);

	return (pwm_gpio_t){.slice = slice, .channel = channel};
}

static void set_motor(const pwm_motor_t *const motor, const i32 val, const u16 pwm) {
	if (motor->positive_pin != no_pin) gpio_put(motor->positive_pin, val > 0);
	if (motor->negative_pin != no_pin) gpio_put(motor->negative_pin, val < 0);
	*motor->cc = pwm;
}

static i8 command_value(const i32 val, const i32 deadzone, const i32 max_val) {
	const auto magnitude = utils_scaled_pwm_percentage(val, deadzone, max_val);
	return (i8)(val < 0 ? -magnitude : magnitude);
}

static void adjust_drive_pwm(u16 *pwm) {
	if (*pwm == 0) return;
	if (*pwm >= main_pwm_top) {
		*pwm = main_pwm_full;
		return;
	}
	if (*pwm >= 90) return;

	u16 out;
	if (*pwm <= 10) out = 4UL * *pwm;
	else out = 40UL + (5UL * (*pwm - 10UL)) / 8UL;

	*pwm = out;
}

static void adjust_rotate_pwm(u16 *pwm) {
	if (*pwm >= turret_pwm_top) {
		*pwm = turret_pwm_full;
		return;
	}
	if (*pwm <= 4000) {
		*pwm = *pwm * 1.05;
	} else if (*pwm <= 5000) {
		*pwm = *pwm * (1.05 - 0.025 * ((*pwm - 4000) / 1000.0));
	} else if (*pwm <= 6000) {
		*pwm = *pwm * (1.025 - 0.02 * ((*pwm - 5000) / 1000.0)); // Gradual reduction from 1.05x to 1.02x
	} else if (*pwm <= 9000) {
		*pwm = *pwm * (1.005 - 0.27 * ((*pwm - 6000) / 3000.0)); // Gradual decrease to 0.75x
	}
}

void main_engine_init() {
	static const u8 pins[] = {
		MOD_ENGINE_MAIN_ENABLE1,
		MOD_ENGINE_MAIN_ENABLE2,
	};
	outputs_init(pins, ARRAY_SIZE(pins));

	const auto clk_div = utils_calculate_pio_clk_div(0.5f); // 3.f for 5 khz frequency (2.f for 7.5 khz 1.f for 15 khz)
	if (state.app_settings.debug_logs) utils_printf("MAIN ENGINE CLK DIV: %f\n", clk_div);

	const auto pwm1 = init_pwm(MOD_ENGINE_MAIN_PWM1, main_pwm_top, clk_div);
	const auto pwm2 = init_pwm(MOD_ENGINE_MAIN_PWM2, main_pwm_top, clk_div);
	sleep_ms(1);

	main_left.cc = utils_pwm_cc_for_16bit(pwm1.slice, pwm1.channel);
	main_right.cc = utils_pwm_cc_for_16bit(pwm2.slice, pwm2.channel);
	sleep_ms(1);
}

main_engine_command_t main_engine_advanced(const i32 left, const i32 right) {
	u16 pwm_left = utils_scaled_pwm_percentage(left, XY_DEAD_ZONE, XY_MAX);
	u16 pwm_right = utils_scaled_pwm_percentage(right, XY_DEAD_ZONE, XY_MAX);
	if (left < 0) pwm_left += 1;
	if (right < 0) pwm_right += 1;
	adjust_drive_pwm(&pwm_left);
	adjust_drive_pwm(&pwm_right);
	if (state.app_settings.debug_logs) utils_printf("%d<<>>%d\n", pwm_left, pwm_right);

	set_motor(&main_left, left, pwm_left);
	set_motor(&main_right, right, pwm_right);

	return (main_engine_command_t){
		.left = command_value(left, XY_DEAD_ZONE, XY_MAX),
		.right = command_value(right, XY_DEAD_ZONE, XY_MAX),
	};
}

main_engine_command_t main_engine_basic(const i32 gas, const i32 steer) {
	const bool go_left = steer < 0;
	const bool go_backward = gas < 0;
	const auto steer_perc = utils_scaled_pwm_percentage(steer, XY_DEAD_ZONE, XY_MAX);

	auto gas_left = gas;
	auto gas_right = gas;

	i32 *const gas_active = go_left ? &gas_left : &gas_right;
	i32 *const gas_passive = go_left ? &gas_right : &gas_left;
	const u8 steer_split = 50;

	if (gas == 0) {
		if (steer_perc <= steer_split) {
			const u8 scaled_value = utils_scaled_pwm_percentage(steer_perc, 0, steer_split);
			*gas_active = -TRIG_MAX * scaled_value / 100;
		} else {
			const u8 scaled_value = utils_scaled_pwm_percentage(steer_perc - steer_split, 0, 100 - steer_split);
			*gas_active = -TRIG_MAX;
			*gas_passive = TRIG_MAX * scaled_value / 100;
		}
	} else {
		const i8 sign = go_backward ? 1 : -1;

		if (steer_perc <= steer_split) {
			const u8 scaled_value = utils_scaled_pwm_percentage(steer_perc, 0, steer_split);
			*gas_active -= (*gas_active * scaled_value) / 100;
		} else {
			const u8 scaled_value = utils_scaled_pwm_percentage(steer_perc - steer_split, 0, 100 - steer_split);
			*gas_active = sign * TRIG_MAX * scaled_value / 100;
		}
	}

	u16 pwm_left = utils_scaled_pwm_percentage(gas_left, TRIG_DEAD_ZONE, TRIG_MAX);
	u16 pwm_right = utils_scaled_pwm_percentage(gas_right, TRIG_DEAD_ZONE, TRIG_MAX);
	adjust_drive_pwm(&pwm_left);
	adjust_drive_pwm(&pwm_right);
	if (state.app_settings.debug_logs) {
		utils_printf("%c%d<<%ld>>%c%d\n", gas_left < 0 ? '-' : '+', pwm_left, gas, gas_right < 0 ? '-' : '+', pwm_right);
	}

	set_motor(&main_left, gas_left, pwm_left);
	set_motor(&main_right, gas_right, pwm_right);

	return (main_engine_command_t){
		.left = command_value(gas_left, TRIG_DEAD_ZONE, TRIG_MAX),
		.right = command_value(gas_right, TRIG_DEAD_ZONE, TRIG_MAX),
	};
}

void turret_ctrl_init() {
	static const u8 pins[] = {
		MOD_TURRET_CTRL_ENABLE1,
		MOD_TURRET_CTRL_ENABLE2,
		MOD_TURRET_CTRL_ENABLE3,
		MOD_TURRET_CTRL_ENABLE4,
		MOD_TURRET_CTRL_PWM2,
	};
	outputs_init(pins, ARRAY_SIZE(pins));

	const auto pwm1 = init_pwm(MOD_TURRET_CTRL_PWM1, turret_pwm_top, 20.f); // 3.f for 5 khz frequency (2.f for 7.5 khz 1.f for 15 khz)
	sleep_ms(1);

	turret_rotate.cc = utils_pwm_cc_for_16bit(pwm1.slice, pwm1.channel);
	sleep_ms(1);
}

i8 turret_ctrl_rotate(const i32 val) {
	u16 pwm = utils_scaled_pwm_percentage(val, XY_DEAD_ZONE, XY_MAX) * 100;
	adjust_rotate_pwm(&pwm);

	set_motor(&turret_rotate, val, pwm);
	return command_value(val, XY_DEAD_ZONE, XY_MAX);
}

i8 turret_ctrl_lift(const i32 val) {
	const bool active = abs(val) > XY_DEAD_ZONE + 200;
	gpio_put(MOD_TURRET_CTRL_PWM2, active);
	gpio_put(MOD_TURRET_CTRL_ENABLE3, active && val > 0);
	gpio_put(MOD_TURRET_CTRL_ENABLE4, active && val < 0);
	return command_value(val, XY_DEAD_ZONE + 200, XY_MAX);
}
