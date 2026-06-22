// Copyright (C) 2025 Laurynas 'Deviltry' Ekekeke
// SPDX-License-Identifier: BSD-3-Clause

#pragma once

#include "shared_config.h"

typedef struct {
	i8 left;
	i8 right;
} main_engine_command_t;

void main_engine_init();

main_engine_command_t main_engine_advanced(i32 left, i32 right);

main_engine_command_t main_engine_basic(i32 gas, i32 steer);

void turret_ctrl_init();

i8 turret_ctrl_rotate(i32 val);

i8 turret_ctrl_lift(i32 val);
