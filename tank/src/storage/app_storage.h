// Copyright (C) 2026 Laurynas 'Deviltry' Ekekeke
// SPDX-License-Identifier: BSD-3-Clause

#pragma once

#include "shared_config.h"

typedef struct {
	bool debug_logs;
} app_settings_t;

typedef struct {
	u16 boot_count;
} app_data_t;

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

[[nodiscard]]
u16 app_storage_boot_count();
