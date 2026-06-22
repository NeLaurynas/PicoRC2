// Copyright (C) 2026 Laurynas 'Deviltry' Ekekeke
// SPDX-License-Identifier: BSD-3-Clause

#include "storage/app_lfs.h"

#include <FreeRTOS.h>
#include <hardware/flash.h>
#include <hardware/platform_defs.h>
#include <lfs.h>
#include <pico/flash.h>
#include <semphr.h>
#include <string.h>

#define APP_FS_TMP_PATH "/write.tmp"

#define APP_LFS_READ_SIZE 256u
#define APP_LFS_PROG_SIZE 256u
#define APP_LFS_CACHE_SIZE 256u
#define APP_LFS_LOOKAHEAD_SIZE 64u
#define APP_LFS_BLOCK_CYCLES 500

static_assert(MOD_STORAGE_SECTOR_SIZE == 4096u);
static_assert(MOD_STORAGE_PAGE_SIZE == 256u);
static_assert(MOD_STORAGE_SECTORS >= 16u);
static_assert(MOD_STORAGE_BYTES == (MOD_STORAGE_SECTORS * MOD_STORAGE_SECTOR_SIZE));
static_assert(MOD_STORAGE_OFFSET + MOD_STORAGE_BYTES <= PICO_FLASH_SIZE_BYTES);
static_assert(MOD_STORAGE_OFFSET + MOD_STORAGE_BYTES <= PICO_FLASH_BANK_STORAGE_OFFSET);

typedef struct {
	u32 flash_off;
	const u8 *data;
	u32 len;
} prog_params_t;

static lfs_t lfs;
static bool mounted = false;

static u8 read_buffer[APP_LFS_CACHE_SIZE];
static u8 prog_buffer[APP_LFS_CACHE_SIZE];
static u8 lookahead_buffer[APP_LFS_LOOKAHEAD_SIZE];
static u8 file_buffer[APP_LFS_CACHE_SIZE];

static SemaphoreHandle_t fs_mutex = nullptr;

static void call_flash_range_erase(void *param) {
	const u32 flash_off = (uintptr_t)param;
	flash_range_erase(flash_off, MOD_STORAGE_SECTOR_SIZE);
}

static void call_flash_range_program(void *param) {
	const prog_params_t *params = param;
	flash_range_program(params->flash_off, params->data, params->len);
}

static bool lock_fs() {
	if (fs_mutex == nullptr) return false;
	return xSemaphoreTakeRecursive(fs_mutex, portMAX_DELAY) == pdTRUE;
}

static void unlock_fs() {
	(void)xSemaphoreGiveRecursive(fs_mutex);
}

static const u8 *flash_location(const u32 offset) {
	return (const u8*)(XIP_BASE + (uintptr_t)MOD_STORAGE_OFFSET + offset);
}

static u32 block_offset(const lfs_block_t block, const lfs_off_t off) {
	return (u32)(block * MOD_STORAGE_SECTOR_SIZE + off);
}

static int block_device_read(
	const struct lfs_config *config,
	const lfs_block_t block,
	const lfs_off_t off,
	void *buffer,
	const lfs_size_t size
) {
	(void)config;

	memcpy(buffer, flash_location(block_offset(block, off)), size);
	return 0;
}

static int block_device_prog(
	const struct lfs_config *config,
	const lfs_block_t block,
	const lfs_off_t off,
	const void *buffer,
	const lfs_size_t size
) {
	(void)config;

	const u32 rel_off = block_offset(block, off);
	prog_params_t params = {
		.flash_off = MOD_STORAGE_OFFSET + rel_off,
		.data = buffer,
		.len = size,
	};
	const int rc = flash_safe_execute(call_flash_range_program, &params, UINT32_MAX);
	return rc == PICO_OK ? 0 : LFS_ERR_IO;
}

static int block_device_erase(const struct lfs_config *config, const lfs_block_t block) {
	(void)config;

	const u32 rel_off = block_offset(block, 0);
	const int rc = flash_safe_execute(call_flash_range_erase, (void*)(uintptr_t)(MOD_STORAGE_OFFSET + rel_off), UINT32_MAX);
	return rc == PICO_OK ? 0 : LFS_ERR_IO;
}

static int block_device_sync(const struct lfs_config *config) {
	(void)config;
	return 0;
}

static const struct lfs_config lfs_config = {
	.context = nullptr,
	.read = block_device_read,
	.prog = block_device_prog,
	.erase = block_device_erase,
	.sync = block_device_sync,
	.read_size = APP_LFS_READ_SIZE,
	.prog_size = APP_LFS_PROG_SIZE,
	.block_size = MOD_STORAGE_SECTOR_SIZE,
	.block_count = MOD_STORAGE_SECTORS,
	.block_cycles = APP_LFS_BLOCK_CYCLES,
	.cache_size = APP_LFS_CACHE_SIZE,
	.lookahead_size = APP_LFS_LOOKAHEAD_SIZE,
	.read_buffer = read_buffer,
	.prog_buffer = prog_buffer,
	.lookahead_buffer = lookahead_buffer,
	.name_max = 64,
};

static const struct lfs_file_config file_config = {
	.buffer = file_buffer,
};

static bool write_parts(lfs_file_t *file, const app_lfs_write_part_t parts[], const size_t count) {
	for (size_t i = 0; i < count; i++) {
		const app_lfs_write_part_t part = parts[i];
		if (part.data == nullptr && part.len > 0u) return false;
		if (lfs_file_write(&lfs, file, part.data, part.len) != (lfs_ssize_t)part.len) return false;
	}

	return lfs_file_sync(&lfs, file) == 0;
}

static bool read_parts(lfs_file_t *file, const app_lfs_read_part_t parts[], const size_t count) {
	for (size_t i = 0; i < count; i++) {
		const app_lfs_read_part_t part = parts[i];
		if (part.data == nullptr && part.len > 0u) return false;
		if (lfs_file_read(&lfs, file, part.data, part.len) != (lfs_ssize_t)part.len) return false;
	}

	return true;
}

bool app_lfs_init() {
	if (mounted) return true;

	if (fs_mutex == nullptr) {
		fs_mutex = xSemaphoreCreateRecursiveMutex();
		if (fs_mutex == nullptr) return false;
	}

	if (!lock_fs()) return false;

	bool ok = lfs_mount(&lfs, &lfs_config) == 0;
	if (!ok) ok = lfs_format(&lfs, &lfs_config) == 0 && lfs_mount(&lfs, &lfs_config) == 0;
	if (ok) mounted = true;

	unlock_fs();
	return ok;
}

bool app_lfs_write_atomic(const char *path, const app_lfs_write_part_t parts[], const size_t part_count) {
	if (path == nullptr || !mounted || (part_count > 0u && parts == nullptr)) return false;
	if (!lock_fs()) return false;

	lfs_file_t file;
	bool ok = lfs_file_opencfg(&lfs, &file, APP_FS_TMP_PATH, LFS_O_WRONLY | LFS_O_CREAT | LFS_O_TRUNC, &file_config) >= 0;
	if (ok) {
		ok = write_parts(&file, parts, part_count);
		if (lfs_file_close(&lfs, &file) < 0) ok = false;
	}

	if (ok) ok = lfs_rename(&lfs, APP_FS_TMP_PATH, path) == 0;
	else (void)lfs_remove(&lfs, APP_FS_TMP_PATH);

	unlock_fs();
	return ok;
}

bool app_lfs_read_exact(const char *path, const app_lfs_read_part_t parts[], const size_t part_count) {
	if (path == nullptr || !mounted || (part_count > 0u && parts == nullptr)) return false;
	if (!lock_fs()) return false;

	lfs_file_t file;
	bool ok = lfs_file_opencfg(&lfs, &file, path, LFS_O_RDONLY, &file_config) >= 0;
	if (ok) {
		ok = read_parts(&file, parts, part_count);
		if (lfs_file_close(&lfs, &file) < 0) ok = false;
	}

	unlock_fs();
	return ok;
}
