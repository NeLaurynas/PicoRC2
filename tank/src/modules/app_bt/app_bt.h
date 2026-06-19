// Copyright (C) 2026 Laurynas 'Deviltry' Ekekeke
// SPDX-License-Identifier: BSD-3-Clause

#pragma once

#include <stddef.h>

void app_bt_start(void);

void app_bt_log_write_safe(const char *text, size_t len);
