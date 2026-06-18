// Copyright (C) 2026 Laurynas 'Deviltry' Ekekeke
// SPDX-License-Identifier: BSD-3-Clause

#pragma once

#include "shared_config.h"
#include "tasks/tasks.h"

typedef struct {
	i32 x;
	i32 y;

	i32 rx;
	i32 ry;

	bool btn_a;
	bool btn_x;
	bool btn_b;
	bool btn_y;

	bool btn_start;
	bool btn_select;

	bool dpad_up;
	bool dpad_down;
	bool dpad_left;
	bool dpad_right;

	bool shoulder_l;
	bool shoulder_r;

	i32 throttle;
	i32 brake;

	bool connected;
} control_input_state_t;

typedef struct {
	i32 x;
	i32 y;

	i32 rx;
	i32 ry;

	bool btn_a;
	bool btn_x;
	bool btn_b;
	bool btn_y;

	bool btn_start;
	bool btn_select;

	bool dpad_up;
	bool dpad_down;
	bool dpad_left;
	bool dpad_right;

	bool white_leds;
	bool red_led;

	bool advanced_mode;

	bool shoulder_l;
	bool shoulder_r;

	i32 throttle;
	i32 brake;

	bool connected;
} control_actuation_state_t;

typedef struct {
	control_input_state_t sampled_input;
	control_actuation_state_t actuation;

	struct {
		task_t startup;
		task_t heartbeat;
		task_t control_input;
		task_t control_actuation;
	} tasks;
} state_t;

extern state_t state;

void state_init();
void state_sampled_input_set(const control_input_state_t *input);
void state_sampled_input_get(control_input_state_t *input);
