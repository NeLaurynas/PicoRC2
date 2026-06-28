// Copyright (C) 2026 Laurynas 'Deviltry' Ekekeke
// SPDX-License-Identifier: BSD-3-Clause

#pragma once

#include <stddef.h>

typedef enum {
	APP_BT_PACKET_LOG = 0,
	APP_BT_PACKET_TANK_STATE_FULL = 1,
	APP_BT_PACKET_TANK_STATE_DIFF = 2,
	APP_BT_PACKET_SYSTEM_STATE = 3,
	APP_BT_PACKET_SYSTEM_STATE_DIFF = 4,
} app_bt_packet_type_t;

void app_bt_start();

void app_bt_pause_advertising_for_controller_connect();
void app_bt_resume_advertising();

void app_bt_log_write_safe(const char *text, size_t len);
