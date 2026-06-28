// Copyright (C) 2025 Laurynas 'Deviltry' Ekekeke
// SPDX-License-Identifier: BSD-3-Clause

#include "engine.h"

#include <hardware/gpio.h>
#include <hardware/pwm.h>
#include <pico/time.h>
#include <utils.h>

#include "defines/config.h"
#include "state.h"

typedef struct {
	u8 slice;
	u8 channel;
} pwm_gpio_t;

typedef struct {
	pwm_gpio_t forward_pwm;
	pwm_gpio_t backward_pwm;
} dual_pwm_motor_t;

typedef struct {
	u8 dir_pin;
	u8 pwm_pin;
} dir_gpio_motor_t;

static constexpr u16 main_pwm_top = 100;
static constexpr u16 main_pwm_full = main_pwm_top + 1;
static constexpr u16 main_pwm_floor_command = 45;
static constexpr u16 main_pwm_floor = 40 + (5 * (main_pwm_floor_command - 10)) / 8;

static dual_pwm_motor_t main_left;
static dual_pwm_motor_t main_right;
static dir_gpio_motor_t turret_rotate = {.dir_pin = MOD_TURRET_CTRL_ROTATE_DIR, .pwm_pin = MOD_TURRET_CTRL_ROTATE_PWM};
static dir_gpio_motor_t turret_tilt = {.dir_pin = MOD_TURRET_CTRL_TILT_DIR, .pwm_pin = MOD_TURRET_CTRL_TILT_PWM};

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

static void set_dual_pwm(const dual_pwm_motor_t *const motor, const i32 val, const u16 pwm) {
	pwm_set_chan_level(motor->forward_pwm.slice, motor->forward_pwm.channel, val > 0 ? pwm : 0);
	pwm_set_chan_level(motor->backward_pwm.slice, motor->backward_pwm.channel, val < 0 ? pwm : 0);
}

static i8 set_turret(const dir_gpio_motor_t *const motor, const i32 val) {
	const bool active = val != 0;
	gpio_put(motor->dir_pin, val > 0);
	gpio_put(motor->pwm_pin, active);

	if (val == 0) return 0;
	return val > 0 ? 100 : -100;
}

static i8 command_value(const i32 val, const i32 deadzone, const i32 max_val) {
	const auto magnitude = utils_scaled_pwm_percentage(val, deadzone, max_val);
	return (i8)(val < 0 ? -magnitude : magnitude);
}

static void adjust_drive_pwm(u16 *const pwm) {
	if (*pwm == 0) return;
	if (*pwm >= main_pwm_top) {
		*pwm = main_pwm_full;
		return;
	}

	*pwm = main_pwm_floor + ((main_pwm_top - main_pwm_floor) * *pwm) / main_pwm_top;
}

void main_engine_init() {
	const auto clk_div = utils_calculate_pio_clk_div(0.5f); // 3.f for 5 khz frequency (2.f for 7.5 khz 1.f for 15 khz)
	if (state.app_settings.debug_logs) utils_printf("MAIN ENGINE CLK DIV: %f\n", clk_div);

	const auto left_forward = init_pwm(MOD_ENGINE_MAIN_LEFT_PWM_FORWARD, main_pwm_top, clk_div);
	const auto left_backward = init_pwm(MOD_ENGINE_MAIN_LEFT_PWM_BACKWARD, main_pwm_top, clk_div);
	const auto right_forward = init_pwm(MOD_ENGINE_MAIN_RIGHT_PWM_FORWARD, main_pwm_top, clk_div);
	const auto right_backward = init_pwm(MOD_ENGINE_MAIN_RIGHT_PWM_BACKWARD, main_pwm_top, clk_div);
	sleep_ms(1);

	main_left.forward_pwm = left_forward;
	main_left.backward_pwm = left_backward;
	main_right.forward_pwm = right_forward;
	main_right.backward_pwm = right_backward;
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

	set_dual_pwm(&main_left, left, pwm_left);
	set_dual_pwm(&main_right, right, pwm_right);

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
			*gas_passive = TRIG_MAX * scaled_value / 100;
		} else {
			const u8 scaled_value = utils_scaled_pwm_percentage(steer_perc - steer_split, 0, 100 - steer_split);
			*gas_active = -TRIG_MAX * scaled_value / 100;
			*gas_passive = TRIG_MAX;
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

	set_dual_pwm(&main_left, gas_left, pwm_left);
	set_dual_pwm(&main_right, gas_right, pwm_right);

	return (main_engine_command_t){
		.left = command_value(gas_left, TRIG_DEAD_ZONE, TRIG_MAX),
		.right = command_value(gas_right, TRIG_DEAD_ZONE, TRIG_MAX),
	};
}

void turret_ctrl_init() {
	static constexpr u8 pins[] = {
		MOD_TURRET_CTRL_ROTATE_PWM,
		MOD_TURRET_CTRL_ROTATE_DIR,
		MOD_TURRET_CTRL_TILT_PWM,
		MOD_TURRET_CTRL_TILT_DIR,
	};
	outputs_init(pins, ARRAY_SIZE(pins));
	sleep_ms(1);
}

i8 turret_ctrl_rotate(const i32 val) {
	return set_turret(&turret_rotate, val);
}

i8 turret_ctrl_lift(const i32 val) {
	return set_turret(&turret_tilt, val);
}
