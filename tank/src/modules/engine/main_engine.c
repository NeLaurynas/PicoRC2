// Copyright (C) 2025 Laurynas 'Deviltry' Ekekeke
// SPDX-License-Identifier: BSD-3-Clause

#include "main_engine.h"

#include <hardware/gpio.h>
#include <hardware/pwm.h>
#include <pico/time.h>
#include <utils.h>

#include "defines/config.h"
#include "state.h"

static u16 *cc1 = nullptr;
static u16 *cc2 = nullptr;
static constexpr u16 pwm_top = 100;
static constexpr u16 pwm_full = pwm_top + 1;

static void pwm_slice_init(const uint slice, const float clk_div) {
	auto cfg = pwm_get_default_config();
	cfg.top = pwm_top;
	pwm_init(slice, &cfg, false);
	pwm_set_clkdiv(slice, clk_div);
	pwm_set_phase_correct(slice, false);
	pwm_set_enabled(slice, true);
}

void main_engine_init() {
	gpio_init(MOD_ENGINE_MAIN_ENABLE1);
	gpio_init(MOD_ENGINE_MAIN_ENABLE2);
	gpio_set_dir(MOD_ENGINE_MAIN_ENABLE1, true);
	gpio_set_dir(MOD_ENGINE_MAIN_ENABLE2, true);
	gpio_set_function(MOD_ENGINE_MAIN_PWM1, GPIO_FUNC_PWM);
	gpio_set_function(MOD_ENGINE_MAIN_PWM2, GPIO_FUNC_PWM);

	const u8 slice1 = pwm_gpio_to_slice_num(MOD_ENGINE_MAIN_PWM1);
	const u8 slice2 = pwm_gpio_to_slice_num(MOD_ENGINE_MAIN_PWM2);
	const u8 channel1 = pwm_gpio_to_channel(MOD_ENGINE_MAIN_PWM1);
	const u8 channel2 = pwm_gpio_to_channel(MOD_ENGINE_MAIN_PWM2);

	const auto clk_div = utils_calculate_pio_clk_div(0.5f); // 3.f for 5 khz frequency (2.f for 7.5 khz 1.f for 15 khz)
	if (state.app_settings.debug_logs) utils_printf("MAIN ENGINE CLK DIV: %f\n", clk_div);

	pwm_slice_init(slice1, clk_div);
	pwm_slice_init(slice2, clk_div);
	sleep_ms(1);

	cc1 = utils_pwm_cc_for_16bit(slice1, channel1);
	cc2 = utils_pwm_cc_for_16bit(slice2, channel2);
	sleep_ms(1);
}

static void set_motor_ctrl(const i32 val, const u16 pwm, const bool is_left_motor) {
	const u8 enable_pin = is_left_motor ? MOD_ENGINE_MAIN_ENABLE1 : MOD_ENGINE_MAIN_ENABLE2;
	u16 *const cc = is_left_motor ? cc1 : cc2;

	gpio_put(enable_pin, val < 0);
	*cc = pwm;
}

static void adjust_pwm(u16 *pwm) {
	if (*pwm == 0) return;
	if (*pwm >= pwm_top) {
		*pwm = pwm_full;
		return;
	}
	if (*pwm >= 90) return;

	u16 out;
	if (*pwm <= 10) out = 4UL * *pwm;
	else out = 40UL + (5UL * (*pwm - 10UL)) / 8UL;

	*pwm = out;
}

void main_engine_advanced(const i32 left, const i32 right) {
	u16 pwm_left = utils_scaled_pwm_percentage(left, XY_DEAD_ZONE, XY_MAX);
	u16 pwm_right = utils_scaled_pwm_percentage(right, XY_DEAD_ZONE, XY_MAX);
	if (left < 0) pwm_left += 1;
	if (right < 0) pwm_right += 1;
	adjust_pwm(&pwm_left);
	adjust_pwm(&pwm_right);
	if (state.app_settings.debug_logs) utils_printf("%d<<>>%d\n", pwm_left, pwm_right);

	set_motor_ctrl(left, pwm_left, true);
	set_motor_ctrl(right, pwm_right, false);
}

void main_engine_basic(const i32 gas, const i32 steer, i32 *left, i32 *right) {
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
	adjust_pwm(&pwm_left);
	adjust_pwm(&pwm_right);
	if (state.app_settings.debug_logs) {
		utils_printf("%c%d<<%ld>>%c%d\n", gas_left < 0 ? '-' : '+', pwm_left, gas, gas_right < 0 ? '-' : '+', pwm_right);
	}

	set_motor_ctrl(gas_left, pwm_left, true);
	set_motor_ctrl(gas_right, pwm_right, false);

	if (left != nullptr) *left = gas_left;
	if (right != nullptr) *right = gas_right;
}
