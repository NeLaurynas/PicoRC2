// Copyright (C) 2026 Laurynas 'Deviltry' Ekekeke
// SPDX-License-Identifier: BSD-3-Clause

#include "modules/app_bt/app_bt.h"

#include <btstack.h>
#include <FreeRTOS.h>
#include <queue.h>
#include <stdatomic.h>
#include <string.h>
#include <utils.h>

#include "modules/app_bt/picorc_bt_service.gatt.h"
#include "state.h"
#include "storage/app_storage.h"

#define ATT_DEFAULT_MTU_BYTES 23
#define LOG_PAYLOAD_MAX 64
#define NOTIFICATION_MTU (LOG_PAYLOAD_MAX + 1)
#define NOTIFICATION_QUEUE_SIZE 128
#define APP_BT_AD_FLAGS 0b00000110
#define APP_BT_ADV_INTERVAL_MIN 0b00000000'00110000
#define APP_BT_ADV_INTERVAL_MAX 0b00000000'00110000
#define APP_BT_ADV_CHANNEL_MAP 0b00000111
#define TANK_STATE_VERSION 2
#define TANK_STATE_LEN 5
#define SYSTEM_STATE_VERSION 2
#define SYSTEM_STATE_LEN 12
#define APP_SETTINGS_VERSION 1
#define APP_SETTINGS_LEN 2
#define APP_SETTINGS_DEBUG_LOGS_FLAG 0b00000001
#define TANK_STATE_PERIOD_MS 50
#define TANK_STATE_FULL_INTERVAL 10

typedef struct {
	u8 data[NOTIFICATION_MTU];
	u8 len;
} notification_packet_t;

static const u8 picorc_adv_data[] = {
	2, BLUETOOTH_DATA_TYPE_FLAGS, APP_BT_AD_FLAGS,
	7, BLUETOOTH_DATA_TYPE_COMPLETE_LOCAL_NAME, 'P', 'i', 'c', 'o', 'R', 'C',
	17, BLUETOOTH_DATA_TYPE_COMPLETE_LIST_OF_128_BIT_SERVICE_CLASS_UUIDS,
	0x43, 0x52, 0x4F, 0x43, 0x49, 0x50, 0x2C, 0x9F,
	0x4B, 0x4E, 0x2D, 0x2E, 0x01, 0xC0, 0xA4, 0xF7,
};
static_assert(sizeof picorc_adv_data <= 31, "picorc_adv_data too big");

static atomic_bool notification_client_subscribed;
static atomic_bool notification_send_request_pending;
static atomic_bool notification_notify_request_pending;
static atomic_uint negotiated_att_mtu;
static QueueHandle_t notification_queue;
static hci_con_handle_t notification_connection_handle = HCI_CON_HANDLE_INVALID;
static bool notification_enabled;
static btstack_context_callback_registration_t notification_send_callback_registration;
static btstack_context_callback_registration_t notification_notify_callback_registration;
static btstack_timer_source_t tank_state_timer;
static bool tank_state_timer_active;
static u8 tank_state_previous[TANK_STATE_LEN];
static bool tank_state_previous_valid;
static u8 tank_state_tick;
static att_service_handler_t picorc_service_handler;

static void app_settings_build_current(u8 bytes[APP_SETTINGS_LEN]) {
	bytes[0] = APP_SETTINGS_VERSION;
	bytes[1] = state.app_settings.debug_logs ? APP_SETTINGS_DEBUG_LOGS_FLAG : 0;
}

static bool notification_queue_has_packets() {
	return notification_queue != nullptr && uxQueueMessagesWaiting(notification_queue) > 0;
}

static void notification_queue_clear() {
	if (notification_queue == nullptr) return;
	(void)xQueueReset(notification_queue);
}

static bool notification_queue_push_packet(const u8 *data, const u8 len) {
	if (data == nullptr || len == 0 || len > NOTIFICATION_MTU) return false;
	if (notification_queue == nullptr) return false;

	notification_packet_t packet = {0};
	memcpy(packet.data, data, len);
	packet.len = len;

	return xQueueSend(notification_queue, &packet, 0) == pdTRUE;
}

static bool push_versioned_packet(const app_bt_packet_type_t type, const u8 version, const u8 payload[], const u8 payload_len) {
	if (payload_len > NOTIFICATION_MTU - 2) return false;

	u8 packet[NOTIFICATION_MTU] = {(u8)type, version};
	memcpy(packet + 2, payload, payload_len);
	return notification_queue_push_packet(packet, (u8)(payload_len + 2));
}

static bool notification_queue_pop_packet(notification_packet_t *packet) {
	if (packet == nullptr) return false;
	if (notification_queue == nullptr) return false;

	return xQueueReceive(notification_queue, packet, 0) == pdTRUE;
}

static u16 read_notification_configuration(const bool enabled, const u16 offset, u8 *buffer, const u16 buffer_size) {
	u8 value[2] = {0, 0};
	if (enabled) little_endian_store_16(value, 0, GATT_CLIENT_CHARACTERISTICS_CONFIGURATION_NOTIFICATION);

	return att_read_callback_handle_blob(value, sizeof value, offset, buffer, buffer_size);
}

static void tank_state_timer_stop() {
	if (!tank_state_timer_active) return;

	(void)btstack_run_loop_remove_timer(&tank_state_timer);
	tank_state_timer_active = false;
}

static void notification_disable(const bool clear_connection, const bool reset_state, const bool reset_mtu) {
	if (clear_connection) notification_connection_handle = HCI_CON_HANDLE_INVALID;
	notification_enabled = false;
	if (reset_state) {
		tank_state_timer_active = false;
		tank_state_previous_valid = false;
		tank_state_tick = 0;
		atomic_store_explicit(&notification_send_request_pending, false, memory_order_release);
	} else {
		tank_state_timer_stop();
	}
	if (reset_state || reset_mtu) atomic_store_explicit(&negotiated_att_mtu, 0, memory_order_release);
	atomic_store_explicit(&notification_client_subscribed, false, memory_order_release);
	atomic_store_explicit(&notification_notify_request_pending, false, memory_order_release);
	notification_queue_clear();
}

static void tank_state_build_current(u8 bytes[TANK_STATE_LEN]) {
	telemetry_t telemetry;
	state_telemetry_sync_load(&telemetry);

	bytes[0] = (telemetry.connected ? 0b00000001 : 0) |
		(telemetry.advanced_mode ? 0b00000010 : 0) |
		(telemetry.white_leds ? 0b00000100 : 0) |
		(telemetry.red_led ? 0b00001000 : 0);
	bytes[1] = (u8)telemetry.main_left;
	bytes[2] = (u8)telemetry.main_right;
	bytes[3] = (u8)telemetry.turret_rotate;
	bytes[4] = (u8)telemetry.turret_lift;
}

static bool tank_state_queue_packet(const app_bt_packet_type_t type, const u8 bytes[TANK_STATE_LEN], const u8 changed_mask) {
	if (type == APP_BT_PACKET_TANK_STATE_FULL) {
		return push_versioned_packet(type, TANK_STATE_VERSION, bytes, TANK_STATE_LEN);
	}

	u8 payload[TANK_STATE_LEN + 1] = {changed_mask};
	u8 len = 1;
	for (u8 i = 0; i < TANK_STATE_LEN; i++) {
		if ((changed_mask & (u8)(1u << i)) == 0) continue;
		payload[len++] = bytes[i];
	}

	return push_versioned_packet(type, TANK_STATE_VERSION, payload, len);
}

static void tank_state_remember(const u8 bytes[TANK_STATE_LEN]) {
	memcpy(tank_state_previous, bytes, sizeof tank_state_previous);
	tank_state_previous_valid = true;
}

static bool tank_state_queue_full(const u8 bytes[TANK_STATE_LEN]) {
	if (!tank_state_queue_packet(APP_BT_PACKET_TANK_STATE_FULL, bytes, 0)) return false;

	tank_state_remember(bytes);
	return true;
}

static void tank_state_queue_full_snapshot() {
	u8 bytes[TANK_STATE_LEN];
	tank_state_build_current(bytes);

	if (!tank_state_queue_full(bytes)) return;
	tank_state_tick = 0;
}

static void tank_state_queue_tick_packet() {
	if (!tank_state_previous_valid) {
		tank_state_queue_full_snapshot();
		return;
	}

	u8 bytes[TANK_STATE_LEN];
	tank_state_build_current(bytes);

	tank_state_tick++;
	if (tank_state_tick >= TANK_STATE_FULL_INTERVAL) {
		tank_state_tick = 0;
		(void)tank_state_queue_full(bytes);
		return;
	}

	u8 changed_mask = 0;
	for (u8 i = 0; i < TANK_STATE_LEN; i++) {
		if (tank_state_previous[i] != bytes[i]) changed_mask |= (u8)(1u << i);
	}

	if (!tank_state_queue_packet(APP_BT_PACKET_TANK_STATE_DIFF, bytes, changed_mask)) return;

	tank_state_remember(bytes);
}

static void system_state_build_current(u8 bytes[SYSTEM_STATE_LEN]) {
	system_telemetry_t telemetry;
	state_system_telemetry_sync_load(&telemetry);

	little_endian_store_16(bytes, 0, telemetry.cpu_x10);
	little_endian_store_16(bytes, 2, telemetry.freertos_used_kib);
	little_endian_store_16(bytes, 4, telemetry.freertos_total_kib);
	little_endian_store_16(bytes, 6, telemetry.system_used_kib);
	little_endian_store_16(bytes, 8, telemetry.system_total_kib);
	little_endian_store_16(bytes, 10, telemetry.boot_count);
}

static void system_state_queue_packet() {
	u8 bytes[SYSTEM_STATE_LEN];
	system_state_build_current(bytes);

	(void)push_versioned_packet(APP_BT_PACKET_SYSTEM_STATE, SYSTEM_STATE_VERSION, bytes, SYSTEM_STATE_LEN);
}

static void request_notification_send_from_main() {
	if (notification_connection_handle == HCI_CON_HANDLE_INVALID || !notification_enabled) {
		notification_disable(notification_connection_handle == HCI_CON_HANDLE_INVALID, false, false);
		return;
	}
	if (!notification_queue_has_packets()) return;
	if (atomic_exchange_explicit(&notification_notify_request_pending, true, memory_order_acq_rel)) return;

	const auto status = att_server_request_to_send_notification(
		&notification_notify_callback_registration,
		notification_connection_handle
	);
	if (status == ERROR_CODE_COMMAND_DISALLOWED) return;
	if (status != ERROR_CODE_SUCCESS) {
		atomic_store_explicit(&notification_notify_request_pending, false, memory_order_release);
	}
}

static void request_notification_send_safe() {
	if (atomic_exchange_explicit(&notification_send_request_pending, true, memory_order_acq_rel)) return;

	btstack_run_loop_execute_on_main_thread(&notification_send_callback_registration);
}

static void schedule_notification_send_callback(void *context) {
	(void)context;

	atomic_store_explicit(&notification_send_request_pending, false, memory_order_release);
	request_notification_send_from_main();
}

static void notify_client_callback(void *context) {
	(void)context;

	atomic_store_explicit(&notification_notify_request_pending, false, memory_order_release);

	if (notification_connection_handle == HCI_CON_HANDLE_INVALID || !notification_enabled) {
		notification_queue_clear();
		return;
	}

	auto packet = (notification_packet_t){0};
	if (!notification_queue_pop_packet(&packet)) {
		if (notification_queue_has_packets()) request_notification_send_from_main();
		return;
	}

	(void)att_server_notify(
		notification_connection_handle,
		ATT_CHARACTERISTIC_F7A4C002_2E2D_4E4B_9F2C_5049434F5243_01_VALUE_HANDLE,
		packet.data,
		packet.len
	);

	if (notification_queue_has_packets()) request_notification_send_from_main();
}

static void tank_state_timer_start() {
	if (tank_state_timer_active) return;
	if (notification_connection_handle == HCI_CON_HANDLE_INVALID || !notification_enabled) return;

	btstack_run_loop_set_timer(&tank_state_timer, TANK_STATE_PERIOD_MS);
	btstack_run_loop_add_timer(&tank_state_timer);
	tank_state_timer_active = true;
}

static void tank_state_timer_callback(btstack_timer_source_t *timer) {
	(void)timer;

	tank_state_timer_active = false;
	if (notification_connection_handle == HCI_CON_HANDLE_INVALID || !notification_enabled) return;

	tank_state_queue_tick_packet();
	system_state_queue_packet();
	request_notification_send_from_main();
	tank_state_timer_start();
}

static u16 app_bt_att_read_callback(
	hci_con_handle_t conn_handle,
	u16 att_handle,
	u16 offset,
	u8 *buffer,
	u16 buffer_size
) {
	switch (att_handle) {
		case ATT_CHARACTERISTIC_F7A4C002_2E2D_4E4B_9F2C_5049434F5243_01_VALUE_HANDLE:
			return 0;

		case ATT_CHARACTERISTIC_F7A4C003_2E2D_4E4B_9F2C_5049434F5243_01_VALUE_HANDLE: {
			u8 bytes[APP_SETTINGS_LEN];
			app_settings_build_current(bytes);
			return att_read_callback_handle_blob(bytes, sizeof bytes, offset, buffer, buffer_size);
		}

		case ATT_CHARACTERISTIC_F7A4C002_2E2D_4E4B_9F2C_5049434F5243_01_CLIENT_CONFIGURATION_HANDLE:
			return read_notification_configuration(
				conn_handle == notification_connection_handle && notification_enabled,
				offset,
				buffer,
				buffer_size
			);

		default:
			return 0;
	}
}

static int app_bt_att_write_callback(
	hci_con_handle_t con_handle,
	u16 att_handle,
	u16 transaction_mode,
	u16 offset,
	u8 *buffer,
	u16 buffer_size
) {
	if (transaction_mode != ATT_TRANSACTION_MODE_NONE) return ATT_ERROR_REQUEST_NOT_SUPPORTED;

	switch (att_handle) {
		case ATT_CHARACTERISTIC_F7A4C002_2E2D_4E4B_9F2C_5049434F5243_01_CLIENT_CONFIGURATION_HANDLE: {
			if (buffer_size != 2 || offset != 0) return ATT_ERROR_REQUEST_NOT_SUPPORTED;

			const auto configuration = little_endian_read_16(buffer, 0);
			notification_connection_handle = con_handle;
			notification_enabled = (configuration & GATT_CLIENT_CHARACTERISTICS_CONFIGURATION_NOTIFICATION) != 0;
			atomic_store_explicit(&notification_client_subscribed, notification_enabled, memory_order_release);

			if (notification_enabled) {
				tank_state_queue_full_snapshot();
				system_state_queue_packet();
				tank_state_timer_start();
				request_notification_send_from_main();
			} else {
				notification_disable(false, false, false);
			}
			return ATT_ERROR_SUCCESS;
		}

		case ATT_CHARACTERISTIC_F7A4C003_2E2D_4E4B_9F2C_5049434F5243_01_VALUE_HANDLE: {
			if (offset != 0) return ATT_ERROR_INVALID_OFFSET;
			if (buffer_size != APP_SETTINGS_LEN) return ATT_ERROR_INVALID_ATTRIBUTE_VALUE_LENGTH;
			if (buffer[0] != APP_SETTINGS_VERSION) return ATT_ERROR_VALUE_NOT_ALLOWED;

			const bool debug_logs = (buffer[1] & APP_SETTINGS_DEBUG_LOGS_FLAG) != 0;
			if (state.app_settings.debug_logs == debug_logs) return ATT_ERROR_SUCCESS;

			app_settings_t candidate = state.app_settings;
			candidate.debug_logs = debug_logs;
			if (!app_settings_save(&candidate)) return ATT_ERROR_UNLIKELY_ERROR;

			state.app_settings = candidate;
			return ATT_ERROR_SUCCESS;
		}

		default:
			return ATT_ERROR_ATTRIBUTE_NOT_FOUND;
	}
}

static void app_bt_att_packet_handler(u8 packet_type, u16 channel, u8 *packet, u16 size) {
	(void)channel;
	(void)size;

	if (packet_type != HCI_EVENT_PACKET) return;

	switch (hci_event_packet_get_type(packet)) {
		case ATT_EVENT_CONNECTED:
			atomic_store_explicit(&negotiated_att_mtu, 0, memory_order_release);
			if (notification_connection_handle == HCI_CON_HANDLE_INVALID) {
				notification_connection_handle = att_event_connected_get_handle(packet);
			}
			break;

		case ATT_EVENT_MTU_EXCHANGE_COMPLETE:
			atomic_store_explicit(
				&negotiated_att_mtu,
				att_event_mtu_exchange_complete_get_MTU(packet),
				memory_order_release
			);
			break;

		case ATT_EVENT_DISCONNECTED:
			if (notification_connection_handle != att_event_disconnected_get_handle(packet)) break;

			notification_disable(true, false, true);
			break;

		default:
			break;
	}
}

void app_bt_log_write_safe(const char *text, size_t len) {
	if (text == nullptr || len == 0) return;
	if (!atomic_load_explicit(&notification_client_subscribed, memory_order_acquire)) return;

	const u16 negotiated_mtu = (u16)atomic_load_explicit(&negotiated_att_mtu, memory_order_acquire);
	const u16 mtu = negotiated_mtu < ATT_DEFAULT_MTU_BYTES ? ATT_DEFAULT_MTU_BYTES : negotiated_mtu;
	const size_t mtu_payload_cap = (size_t)(mtu - 3 - 1); // ATT notification header (3) + our 1-byte packet type
	const size_t chunk_cap = mtu_payload_cap > LOG_PAYLOAD_MAX ? LOG_PAYLOAD_MAX : mtu_payload_cap;

	auto queued = false;
	while (len > 0) {
		const auto chunk_len = len > chunk_cap ? chunk_cap : len;
		u8 packet[NOTIFICATION_MTU] = {APP_BT_PACKET_LOG};
		memcpy(packet + 1, text, chunk_len);
		if (!notification_queue_push_packet(packet, (u8)(chunk_len + 1))) break;

		queued = true;
		text += chunk_len;
		len -= chunk_len;
	}

	if (queued) request_notification_send_safe();
}

void utils_printf_sink(const char *text, const size_t len) {
	app_bt_log_write_safe(text, len);
}

void app_bt_start() {
	notification_send_callback_registration.callback = schedule_notification_send_callback;
	notification_send_callback_registration.context = nullptr;
	notification_notify_callback_registration.callback = notify_client_callback;
	notification_notify_callback_registration.context = nullptr;
	btstack_run_loop_set_timer_handler(&tank_state_timer, tank_state_timer_callback);

	att_server_init(picorc_bt_profile_data, app_bt_att_read_callback, app_bt_att_write_callback);

	picorc_service_handler = (att_service_handler_t){
		.read_callback = app_bt_att_read_callback,
		.write_callback = app_bt_att_write_callback,
		.packet_handler = app_bt_att_packet_handler,
		.start_handle = ATT_SERVICE_F7A4C001_2E2D_4E4B_9F2C_5049434F5243_START_HANDLE,
		.end_handle = ATT_SERVICE_F7A4C001_2E2D_4E4B_9F2C_5049434F5243_END_HANDLE,
	};
	att_server_register_service_handler(&picorc_service_handler);

	if (notification_queue == nullptr) {
		notification_queue = xQueueCreate(NOTIFICATION_QUEUE_SIZE, sizeof(notification_packet_t));
	}
	configASSERT(notification_queue != nullptr);
	notification_disable(true, true, true);

	bd_addr_t null_addr = {0};
	gap_advertisements_set_params(APP_BT_ADV_INTERVAL_MIN, APP_BT_ADV_INTERVAL_MAX, 0, 0, null_addr, APP_BT_ADV_CHANNEL_MAP, 0);
	gap_advertisements_set_data((u8)sizeof picorc_adv_data, (u8 *)picorc_adv_data);
	gap_advertisements_enable(true);
}
