// Copyright (C) 2026 Laurynas 'Deviltry' Ekekeke
// SPDX-License-Identifier: BSD-3-Clause

#pragma once

#include "state.h"

void control_actuation_init();
void control_actuation_apply(const control_input_state_t *input);

