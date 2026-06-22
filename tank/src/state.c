// Copyright (C) 2026 Laurynas 'Deviltry' Ekekeke
// SPDX-License-Identifier: BSD-3-Clause

#include "state.h"

#include <pico/sync.h>

#include "defines/config.h"

static critical_section_t telemetry_critical_section;
static critical_section_t system_telemetry_critical_section;

desired_state_t desired_state = { 0 };

state_t state = {
	.tasks = {
		.startup = {
			.name = "startup",
			.stack_depth = TASK_STARTUP_STACK_DEPTH,
			.priority = TASK_STARTUP_PRIORITY,
			.ticks = TASK_STARTUP_TICKS,
			.function = task_startup,
		},
		.heartbeat = {
			.name = "heartbeat",
			.stack_depth = TASK_HEARTBEAT_STACK_DEPTH,
			.priority = TASK_HEARTBEAT_PRIORITY,
			.ticks = TASK_HEARTBEAT_TICKS,
			.function = task_heartbeat,
		},
		.system_monitor = {
			.name = "system_monitor",
			.stack_depth = TASK_SYSTEM_MONITOR_STACK_DEPTH,
			.priority = TASK_SYSTEM_MONITOR_PRIORITY,
			.ticks = TASK_SYSTEM_MONITOR_TICKS,
			.function = task_system_monitor,
		},
		.control_input = {
			.name = "control_input",
			.stack_depth = TASK_CONTROL_INPUT_STACK_DEPTH,
			.priority = TASK_CONTROL_INPUT_PRIORITY,
			.ticks = TASK_CONTROL_INPUT_TICKS,
			.function = task_control_input,
		},
		.control_actuation = {
			.name = "control_actuation",
			.stack_depth = TASK_CONTROL_ACTUATION_STACK_DEPTH,
			.priority = TASK_CONTROL_ACTUATION_PRIORITY,
			.ticks = TASK_CONTROL_ACTUATION_TICKS,
			.function = task_control_actuation,
		},
		.shutdown = {
			.name = "shutdown",
			.stack_depth = TASK_SHUTDOWN_STACK_DEPTH,
			.priority = TASK_SHUTDOWN_PRIORITY,
			.ticks = TASK_SHUTDOWN_TICKS,
			.function = task_debug,
		},
	},
};

void state_init() {
	critical_section_init(&telemetry_critical_section);
	critical_section_init(&system_telemetry_critical_section);
}

void state_telemetry_sync_store(const telemetry_t *telemetry) {
	configASSERT(telemetry != nullptr);
	sync_copy(&telemetry_critical_section, &state.telemetry, telemetry, sizeof state.telemetry);
}

void state_telemetry_sync_load(telemetry_t *telemetry) {
	configASSERT(telemetry != nullptr);
	sync_copy(&telemetry_critical_section, telemetry, &state.telemetry, sizeof state.telemetry);
}

void state_system_telemetry_sync_store(const system_telemetry_t *telemetry) {
	configASSERT(telemetry != nullptr);
	sync_copy(&system_telemetry_critical_section, &state.system_telemetry, telemetry, sizeof state.system_telemetry);
}

void state_system_telemetry_sync_load(system_telemetry_t *telemetry) {
	configASSERT(telemetry != nullptr);
	sync_copy(&system_telemetry_critical_section, telemetry, &state.system_telemetry, sizeof state.system_telemetry);
}
