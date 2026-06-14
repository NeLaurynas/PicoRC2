// Copyright (C) 2026 Laurynas 'Deviltry' Ekekeke
// SPDX-License-Identifier: BSD-3-Clause

#pragma once

#include <controller/uni_gamepad.h>

#include "state.h"

void control_input_init();
void control_input_on_connected();
void control_input_on_disconnected();
void control_input_on_gamepad(const uni_gamepad_t *gamepad);
void control_input_sample(control_input_state_t *input);

