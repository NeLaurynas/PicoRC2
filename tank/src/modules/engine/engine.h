// Copyright (C) 2025 Laurynas 'Deviltry' Ekekeke
// SPDX-License-Identifier: BSD-3-Clause

#pragma once

#include "shared_config.h"

void main_engine_init();

void main_engine_advanced(i32 left, i32 right);

void main_engine_basic(i32 gas, i32 steer, i32 *left, i32 *right);

void turret_ctrl_init();

void turret_ctrl_rotate(i32 val);

void turret_ctrl_lift(i32 val);
