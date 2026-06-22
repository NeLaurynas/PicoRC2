// Copyright (C) 2026 Laurynas 'Deviltry' Ekekeke
// SPDX-License-Identifier: BSD-3-Clause

#pragma once

#include <FreeRTOS.h>
#include <stdint.h>
#include <task.h>

#include "defines/config.h"
#include "shared_config.h"

#define TASK_PRIO_0_IDLE tskIDLE_PRIORITY
#define TASK_PRIO_1_LOWEST (TASK_PRIO_0_IDLE + 1U)
#define TASK_PRIO_2_LOWER (TASK_PRIO_0_IDLE + 2U)
#define TASK_PRIO_3_NORMAL (TASK_PRIO_0_IDLE + 3U)
#define TASK_PRIO_4_HIGHER (TASK_PRIO_0_IDLE + 4U)
#define TASK_PRIO_5_HIGHEST (TASK_PRIO_0_IDLE + 5U)
#define TASK_PRIO_6_REALTIME (TASK_PRIO_0_IDLE + 6U)

static_assert(TASK_PRIO_6_REALTIME == (configMAX_PRIORITIES - 1U));

#define TASK_STACK_256 ((configSTACK_DEPTH_TYPE)256) // 256 words - 1 kB
#define TASK_STACK_384 ((configSTACK_DEPTH_TYPE)384) // 384 words - 1.5 kB
#define TASK_STACK_512 ((configSTACK_DEPTH_TYPE)512) // 512 words - 2 kB
#define TASK_STACK_640 ((configSTACK_DEPTH_TYPE)640) // 640 words - 2.5 kB
#define TASK_STACK_768 ((configSTACK_DEPTH_TYPE)768) // 768 words - 3 kB
#define TASK_STACK_896 ((configSTACK_DEPTH_TYPE)896) // 896 words - 3.5 kB
#define TASK_STACK_1024 ((configSTACK_DEPTH_TYPE)1024) // 1024 words - 4 kB
#define TASK_STACK_1152 ((configSTACK_DEPTH_TYPE)1152) // 1152 words - 4.5 kB
#define TASK_STACK_1280 ((configSTACK_DEPTH_TYPE)1280) // 1280 words - 5 kB
#define TASK_STACK_1408 ((configSTACK_DEPTH_TYPE)1408) // 1408 words - 5.5 kB
#define TASK_STACK_1536 ((configSTACK_DEPTH_TYPE)1536) // 1536 words - 6 kB

static_assert(TASK_STACK_256 == configMINIMAL_STACK_SIZE);

#define US_TO_TICKS(us) ((TickType_t)((((u64)(us)) * configTICK_RATE_HZ + 999'999ULL) / 1'000'000ULL))
#define MS_TO_TICKS(ms) US_TO_TICKS(((u64)(ms)) * US_IN_MS)
#define SECONDS_TO_TICKS(seconds) US_TO_TICKS(((u64)(seconds)) * US_IN_SECOND)

typedef void (*task_function_t)(void *task_parameter);

typedef struct {
	const char *name;
	UBaseType_t stack_used;
	u32 delay_overruns;
	configSTACK_DEPTH_TYPE stack_depth;
	UBaseType_t priority;
	TickType_t ticks;
	TickType_t last_wake;
	TaskHandle_t handle;
	task_function_t function;
} task_t;

void tasks_create(task_t *task);
void tasks_delay(task_t *task);

#define TASK_HEARTBEAT_STACK_DEPTH TASK_STACK_1024
#define TASK_HEARTBEAT_PRIORITY TASK_PRIO_2_LOWER
#define TASK_HEARTBEAT_TICKS SECONDS_TO_TICKS(10)
[[noreturn]]
void task_heartbeat(void *task_parameter);

#define TASK_SYSTEM_MONITOR_STACK_DEPTH TASK_STACK_256
#define TASK_SYSTEM_MONITOR_PRIORITY TASK_PRIO_3_NORMAL
#define TASK_SYSTEM_MONITOR_TICKS MS_TO_TICKS(500)
[[noreturn]]
void task_system_monitor(void *task_parameter);

#define TASK_STARTUP_STACK_DEPTH TASK_STACK_512
#define TASK_STARTUP_PRIORITY TASK_PRIO_6_REALTIME
#define TASK_STARTUP_TICKS SECONDS_TO_TICKS(1)
[[noreturn]]
void task_startup(void *task_parameter);

#define TASK_CONTROL_INPUT_STACK_DEPTH TASK_STACK_256
#define TASK_CONTROL_INPUT_PRIORITY TASK_PRIO_5_HIGHEST
#define TASK_CONTROL_INPUT_TICKS MS_TO_TICKS(10)
[[noreturn]]
void task_control_input(void *task_parameter);

#define TASK_CONTROL_ACTUATION_STACK_DEPTH TASK_STACK_640
#define TASK_CONTROL_ACTUATION_PRIORITY TASK_PRIO_4_HIGHER
#define TASK_CONTROL_ACTUATION_TICKS SECONDS_TO_TICKS(1)
[[noreturn]]
void task_control_actuation(void *task_parameter);
