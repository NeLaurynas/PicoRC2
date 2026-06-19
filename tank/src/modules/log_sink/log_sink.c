// Copyright (C) 2026 Laurynas 'Deviltry' Ekekeke
// SPDX-License-Identifier: BSD-3-Clause

#include "utils.h"

#include "bt/uni_bt_service.h"

void utils_printf_sink(const char *text, const size_t len) {
	uni_bt_service_log_write_safe(text, len);
}
