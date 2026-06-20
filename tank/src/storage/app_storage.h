// Copyright (C) 2026 Laurynas 'Deviltry' Ekekeke
// SPDX-License-Identifier: BSD-3-Clause

#pragma once

#include "state.h"

[[nodiscard]]
bool app_storage_init();

[[nodiscard]]
bool app_settings_load(app_settings_t *out);

[[nodiscard]]
bool app_settings_save(const app_settings_t *settings);

[[nodiscard]]
bool app_data_load(app_data_t *out);

[[nodiscard]]
bool app_data_save(const app_data_t *data);
