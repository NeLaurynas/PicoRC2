// Copyright (C) 2026 Laurynas 'Deviltry' Ekekeke
// SPDX-License-Identifier: BSD-3-Clause

#include "utils.h"

#include "modules/app_bt/app_bt.h"

void utils_printf_sink(const char *text, const size_t len) {
	app_bt_log_write_safe(text, len);
}
