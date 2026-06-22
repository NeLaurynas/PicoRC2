// Copyright (C) 2026 Laurynas 'Deviltry' Ekekeke
// SPDX-License-Identifier: BSD-3-Clause

#pragma once

#include <stddef.h>

#include "shared_config.h"

typedef struct {
	const void *data;
	u32 len;
} app_lfs_write_part_t;

typedef struct {
	void *data;
	u32 len;
} app_lfs_read_part_t;

[[nodiscard]]
bool app_lfs_init();

[[nodiscard]]
bool app_lfs_write_atomic(const char *path, const app_lfs_write_part_t parts[], size_t part_count);

[[nodiscard]]
bool app_lfs_read_exact(const char *path, const app_lfs_read_part_t parts[], size_t part_count);
