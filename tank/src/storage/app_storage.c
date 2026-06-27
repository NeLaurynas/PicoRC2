// Copyright (C) 2026 Laurynas 'Deviltry' Ekekeke
// SPDX-License-Identifier: BSD-3-Clause

#include "storage/app_storage.h"

#include <FreeRTOS.h>
#include <queue.h>
#include <string.h>
#include <task.h>
#include <utils.h>

#include "storage/app_lfs.h"

#define APP_FS_SETTINGS_PATH "/settings.bin"
#define APP_FS_DATA_PATH "/app_data.bin"

#define APP_SETTINGS_MAGIC "ASET"
#define APP_DATA_MAGIC "ADAT"

#define APP_SETTINGS_SCHEMA 1u
#define APP_DATA_SCHEMA 1u

#define APP_MAX_BLOB_PAYLOAD_SIZE (sizeof(app_settings_t) > sizeof(app_data_t) ? sizeof(app_settings_t) : sizeof(app_data_t))

static_assert(sizeof(app_settings_t) <= UINT16_MAX);
static_assert(sizeof(app_data_t) <= UINT16_MAX);

typedef struct __attribute__((packed)) {
	char magic[4];
	u16 schema;
	u16 payload_len;
	u32 payload_crc;
} blob_header_t;

static bool initialized = false;
static QueueHandle_t app_settings_save_queue = nullptr;

static void default_settings(app_settings_t *settings) {
	memset(settings, 0, sizeof *settings);
	settings->debug_logs = true;
}

static bool write_file(const char *path, const char magic[4], const u16 schema, const void *payload, const u16 payload_len) {
	if (payload == nullptr) return false;

	blob_header_t header = {
		.schema = schema,
		.payload_len = payload_len,
		.payload_crc = utils_crc(payload, payload_len),
	};
	memcpy(header.magic, magic, sizeof header.magic);

	const app_lfs_write_part_t parts[] = {
		{ .data = &header, .len = (u32)sizeof header },
		{ .data = payload, .len = payload_len },
	};
	return app_lfs_write_atomic(path, parts, ARRAY_SIZE(parts));
}

static bool read_file(const char *path, const char magic[4], const u16 schema, void *payload, const u16 payload_len) {
	if (payload == nullptr || payload_len > APP_MAX_BLOB_PAYLOAD_SIZE) return false;

	blob_header_t header;
	u8 payload_buffer[APP_MAX_BLOB_PAYLOAD_SIZE]; // staging buffer, so payload is untouched on failure
	const app_lfs_read_part_t parts[] = {
		{ .data = &header, .len = (u32)sizeof header },
		{ .data = payload_buffer, .len = payload_len },
	};

	bool ok = app_lfs_read_exact(path, parts, ARRAY_SIZE(parts));
	if (ok) ok = memcmp(header.magic, magic, sizeof header.magic) == 0;
	if (ok) ok = header.schema == schema;
	if (ok) ok = header.payload_len == payload_len;
	if (ok) ok = utils_crc(payload_buffer, payload_len) == header.payload_crc;
	if (ok) memcpy(payload, payload_buffer, payload_len);

	return ok;
}

bool app_settings_load(app_settings_t *out) {
	return read_file(APP_FS_SETTINGS_PATH, APP_SETTINGS_MAGIC, APP_SETTINGS_SCHEMA, out, sizeof *out);
}

bool app_settings_save(const app_settings_t *settings) {
	return write_file(APP_FS_SETTINGS_PATH, APP_SETTINGS_MAGIC, APP_SETTINGS_SCHEMA, settings, sizeof *settings);
}

bool app_storage_deferred_init() {
	if (app_settings_save_queue != nullptr) return true;

	app_settings_save_queue = xQueueCreate(1, sizeof(app_settings_t));
	return app_settings_save_queue != nullptr;
}

bool app_settings_save_deferred(const app_settings_t *settings) {
	if (settings == nullptr || app_settings_save_queue == nullptr) return false;

	return xQueueOverwrite(app_settings_save_queue, settings) == pdPASS;
}

bool app_data_load(app_data_t *out) {
	return read_file(APP_FS_DATA_PATH, APP_DATA_MAGIC, APP_DATA_SCHEMA, out, sizeof *out);
}

bool app_data_save(const app_data_t *data) {
	return write_file(APP_FS_DATA_PATH, APP_DATA_MAGIC, APP_DATA_SCHEMA, data, sizeof *data);
}

bool app_storage_init() {
	if (initialized) return true;

	utils_crc_init();

	if (!app_lfs_init()) return false;

	if (!app_settings_load(&state.app_settings)) {
		default_settings(&state.app_settings);
		if (!app_settings_save(&state.app_settings)) return false;
	}

	if (!app_data_load(&state.app_data)) memset(&state.app_data, 0, sizeof state.app_data);

	state.app_data.boot_count = 1;
	if (!app_data_save(&state.app_data)) return false;

	initialized = true;
	return true;
}

[[noreturn]]
void task_storage(void *task_parameter) {
	(void)task_parameter;
	configASSERT(app_settings_save_queue != nullptr);

	while (true) {
		app_settings_t settings;
		const auto received = xQueueReceive(app_settings_save_queue, &settings, portMAX_DELAY);
		configASSERT(received == pdTRUE);

		if (!app_settings_save(&settings)) {
			utils_printf("app_settings_save failed\n");
		}

		const auto stack_watermark = uxTaskGetStackHighWaterMark(nullptr);
		state.tasks.storage.stack_used = state.tasks.storage.stack_depth - stack_watermark;
	}
}
