// Copyright (C) 2026 Laurynas 'Deviltry' Ekekeke
// SPDX-License-Identifier: BSD-3-Clause

#pragma once

#include <pico/sync.h>
#include <string.h>

#include "shared_config.h"
#include "tasks/tasks.h"

typedef struct {
	i32 x;
	i32 y;

	i32 rx;
	i32 ry;

	bool btn_a;
	bool btn_x;
	bool btn_b;
	bool btn_y;

	bool btn_start;
	bool btn_select;

	bool dpad_up;
	bool dpad_down;
	bool dpad_left;
	bool dpad_right;

	bool shoulder_l;
	bool shoulder_r;

	i32 throttle;
	i32 brake;

	// derived, owned by the applied state only (unused in desired_state)
	bool white_leds;
	bool red_led;
	bool advanced_mode;

	bool connected;
} control_state_t;

typedef struct {
	bool connected;
	bool advanced_mode;
	bool white_leds;
	bool red_led;

	i8 main_left;
	i8 main_right;
	i8 turret_rotate;
	i8 turret_lift;
} telemetry_t;

typedef struct {
	u16 cpu_x10;
	u16 cpu_speed_mhz_x100;
	i16 cpu_temp_c_x100;
	u16 freertos_used_kib;
	u16 freertos_total_kib;
	u16 system_used_kib;
	u16 system_total_kib;
	u16 boot_count;
	u32 uptime_seconds;
} system_telemetry_t;

typedef struct {
	bool debug_logs;
} app_settings_t;

typedef struct {
	u16 boot_count;
} app_data_t;

typedef struct {
	control_state_t control;
	telemetry_t telemetry;
	system_telemetry_t system_telemetry;
	app_settings_t app_settings;
	app_data_t app_data;

	struct {
		task_t startup;
		task_t heartbeat;
		task_t system_monitor;
		task_t storage;
		task_t control_input;
		task_t control_actuation;
		task_t shutdown;
	} tasks;
} state_t;

typedef struct {
	control_state_t control;
} desired_state_t;

extern state_t state;
extern desired_state_t desired_state;

void state_init();

// Copy `size` bytes between `dst` and `src` while holding `cs`, so the shared
// side is stored/loaded atomically with respect to other tasks.
static inline void sync_copy(critical_section_t *const cs, void *const dst, const void *const src, const size_t size) {
	critical_section_enter_blocking(cs);
	memcpy(dst, src, size);
	critical_section_exit(cs);
}

void state_telemetry_sync_store(const telemetry_t *telemetry);
void state_telemetry_sync_load(telemetry_t *telemetry);
void state_system_telemetry_sync_store(const system_telemetry_t *telemetry);
void state_system_telemetry_sync_load(system_telemetry_t *telemetry);
