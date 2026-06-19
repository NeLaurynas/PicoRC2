// Copyright (C) 2026 Laurynas 'Deviltry' Ekekeke
// SPDX-License-Identifier: BSD-3-Clause

#include "state.h"

#include <pico/sync.h>

#include "defines/config.h"

static critical_section_t sampled_input_critical_section;
static critical_section_t telemetry_critical_section;
static critical_section_t system_telemetry_critical_section;

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
	},
};

void state_init() {
	critical_section_init(&sampled_input_critical_section);
	critical_section_init(&telemetry_critical_section);
	critical_section_init(&system_telemetry_critical_section);
}

void state_sampled_input_set(const control_input_state_t *input) {
	configASSERT(input != nullptr);

	critical_section_enter_blocking(&sampled_input_critical_section);
	state.sampled_input = *input;
	critical_section_exit(&sampled_input_critical_section);
}

void state_sampled_input_get(control_input_state_t *input) {
	configASSERT(input != nullptr);

	critical_section_enter_blocking(&sampled_input_critical_section);
	*input = state.sampled_input;
	critical_section_exit(&sampled_input_critical_section);
}

void state_telemetry_set(const telemetry_t *telemetry) {
	configASSERT(telemetry != nullptr);

	critical_section_enter_blocking(&telemetry_critical_section);
	state.telemetry = *telemetry;
	critical_section_exit(&telemetry_critical_section);
}

void state_telemetry_get(telemetry_t *telemetry) {
	configASSERT(telemetry != nullptr);

	critical_section_enter_blocking(&telemetry_critical_section);
	*telemetry = state.telemetry;
	critical_section_exit(&telemetry_critical_section);
}

void state_system_telemetry_set(const system_telemetry_t *telemetry) {
	configASSERT(telemetry != nullptr);

	critical_section_enter_blocking(&system_telemetry_critical_section);
	state.system_telemetry = *telemetry;
	critical_section_exit(&system_telemetry_critical_section);
}

void state_system_telemetry_get(system_telemetry_t *telemetry) {
	configASSERT(telemetry != nullptr);

	critical_section_enter_blocking(&system_telemetry_critical_section);
	*telemetry = state.system_telemetry;
	critical_section_exit(&system_telemetry_critical_section);
}
