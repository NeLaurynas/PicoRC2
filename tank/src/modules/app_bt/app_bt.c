// Copyright (C) 2026 Laurynas 'Deviltry' Ekekeke
// SPDX-License-Identifier: BSD-3-Clause

#include "modules/app_bt/app_bt.h"

#include <stdatomic.h>
#include <string.h>

#include <btstack.h>

#include "bt/uni_bt_service.h"
#include "modules/app_bt/picorc_bt_service.gatt.h"

#define NOTIFICATION_MTU 20
#define LOG_CHUNK_QUEUE_SIZE 32
#define APP_BT_AD_FLAGS 0b00000110

typedef struct {
	uint8_t data[NOTIFICATION_MTU];
	uint8_t len;
} log_chunk_t;

static void app_bt_on_att_server_ready(void);
static uint16_t app_bt_att_read_callback(hci_con_handle_t conn_handle, uint16_t att_handle, uint16_t offset,
                                         uint8_t *buffer, uint16_t buffer_size);
static int app_bt_att_write_callback(hci_con_handle_t con_handle, uint16_t att_handle, uint16_t transaction_mode,
                                     uint16_t offset, uint8_t *buffer, uint16_t buffer_size);
static void app_bt_att_packet_handler(uint8_t packet_type, uint16_t channel, uint8_t *packet, uint16_t size);
static bool log_queue_has_chunks(void);
static bool log_queue_try_lock(void);
static void log_queue_unlock(void);
static void log_queue_clear(void);
static void log_queue_reset_locked(void);
static bool log_queue_push_chunk(const uint8_t *data, uint8_t len);
static bool log_queue_pop_chunk(log_chunk_t *chunk);
static uint16_t read_notification_configuration(bool enabled, uint16_t offset, uint8_t *buffer, uint16_t buffer_size);
static void request_log_send_safe(void);
static void request_log_send_from_main(void);
static void schedule_log_send_callback(void *context);
static void notify_log_client_callback(void *context);

static const uint8_t picorc_adv_data[] = {
	2, BLUETOOTH_DATA_TYPE_FLAGS, APP_BT_AD_FLAGS,
	7, BLUETOOTH_DATA_TYPE_COMPLETE_LOCAL_NAME, 'P', 'i', 'c', 'o', 'R', 'C',
	17, BLUETOOTH_DATA_TYPE_COMPLETE_LIST_OF_128_BIT_SERVICE_CLASS_UUIDS,
	0x43, 0x52, 0x4F, 0x43, 0x49, 0x50, 0x2C, 0x9F,
	0x4B, 0x4E, 0x2D, 0x2E, 0x01, 0xC0, 0xA4, 0xF7,
};
static_assert(sizeof picorc_adv_data <= 31, "picorc_adv_data too big");

static const uni_bt_service_config_t service_config = {
	.profile_data = picorc_bt_profile_data,
	.adv_data = picorc_adv_data,
	.adv_data_len = (uint8_t)sizeof picorc_adv_data,
	.on_att_server_ready = app_bt_on_att_server_ready,
};

static log_chunk_t log_chunks[LOG_CHUNK_QUEUE_SIZE];
static atomic_flag log_queue_lock = ATOMIC_FLAG_INIT;
static atomic_uint log_chunk_count;
static size_t log_chunk_head;
static size_t log_chunk_tail;
static atomic_bool log_client_subscribed;
static atomic_bool log_queue_clear_requested;
static atomic_bool log_send_request_pending;
static atomic_bool log_notify_request_pending;
static hci_con_handle_t log_connection_handle = HCI_CON_HANDLE_INVALID;
static bool log_notification_enabled;
static btstack_context_callback_registration_t log_send_callback_registration;
static btstack_context_callback_registration_t log_notify_callback_registration;
static att_service_handler_t picorc_service_handler;

void app_bt_init(void) {
	(void)uni_bt_service_set_config(&service_config);
}

void app_bt_log_write_safe(const char *text, size_t len) {
	if (text == nullptr || len == 0) return;
	if (!atomic_load_explicit(&log_client_subscribed, memory_order_acquire)) return;

	auto queued = false;
	while (len > 0) {
		const auto chunk_len = len > NOTIFICATION_MTU ? NOTIFICATION_MTU : len;
		if (!log_queue_push_chunk((const uint8_t *)text, (uint8_t)chunk_len)) break;

		queued = true;
		text += chunk_len;
		len -= chunk_len;
	}

	if (queued) request_log_send_safe();
}

static void app_bt_on_att_server_ready(void) {
	picorc_service_handler = (att_service_handler_t){
		.read_callback = app_bt_att_read_callback,
		.write_callback = app_bt_att_write_callback,
		.packet_handler = app_bt_att_packet_handler,
		.start_handle = ATT_SERVICE_F7A4C001_2E2D_4E4B_9F2C_5049434F5243_START_HANDLE,
		.end_handle = ATT_SERVICE_F7A4C001_2E2D_4E4B_9F2C_5049434F5243_END_HANDLE,
	};
	att_server_register_service_handler(&picorc_service_handler);

	log_connection_handle = HCI_CON_HANDLE_INVALID;
	log_notification_enabled = false;
	atomic_store_explicit(&log_client_subscribed, false, memory_order_release);
	atomic_store_explicit(&log_send_request_pending, false, memory_order_release);
	atomic_store_explicit(&log_notify_request_pending, false, memory_order_release);
	log_queue_clear();
}

static uint16_t app_bt_att_read_callback(hci_con_handle_t conn_handle, uint16_t att_handle, uint16_t offset,
                                         uint8_t *buffer, uint16_t buffer_size) {
	switch (att_handle) {
		case ATT_CHARACTERISTIC_F7A4C002_2E2D_4E4B_9F2C_5049434F5243_01_VALUE_HANDLE:
			return 0;

		case ATT_CHARACTERISTIC_F7A4C002_2E2D_4E4B_9F2C_5049434F5243_01_CLIENT_CONFIGURATION_HANDLE:
			return read_notification_configuration(conn_handle == log_connection_handle && log_notification_enabled, offset,
			                                       buffer, buffer_size);

		default:
			return 0;
	}
}

static int app_bt_att_write_callback(hci_con_handle_t con_handle, uint16_t att_handle, uint16_t transaction_mode,
                                     uint16_t offset, uint8_t *buffer, uint16_t buffer_size) {
	if (transaction_mode != ATT_TRANSACTION_MODE_NONE) return ATT_ERROR_SUCCESS;

	switch (att_handle) {
		case ATT_CHARACTERISTIC_F7A4C002_2E2D_4E4B_9F2C_5049434F5243_01_CLIENT_CONFIGURATION_HANDLE: {
			if (buffer_size != 2 || offset != 0) return ATT_ERROR_REQUEST_NOT_SUPPORTED;

			const auto configuration = little_endian_read_16(buffer, 0);
			log_connection_handle = con_handle;
			log_notification_enabled = (configuration & GATT_CLIENT_CHARACTERISTICS_CONFIGURATION_NOTIFICATION) != 0;
			atomic_store_explicit(&log_client_subscribed, log_notification_enabled, memory_order_release);

			if (log_notification_enabled) {
				request_log_send_from_main();
			} else {
				log_queue_clear();
			}
			return ATT_ERROR_SUCCESS;
		}

		default:
			return ATT_ERROR_ATTRIBUTE_NOT_FOUND;
	}
}

static void app_bt_att_packet_handler(uint8_t packet_type, uint16_t channel, uint8_t *packet, uint16_t size) {
	(void)channel;
	(void)size;

	if (packet_type != HCI_EVENT_PACKET) return;

	switch (hci_event_packet_get_type(packet)) {
		case ATT_EVENT_CONNECTED:
			if (log_connection_handle == HCI_CON_HANDLE_INVALID) {
				log_connection_handle = att_event_connected_get_handle(packet);
			}
			break;

		case ATT_EVENT_DISCONNECTED:
			if (log_connection_handle != att_event_disconnected_get_handle(packet)) break;

			log_connection_handle = HCI_CON_HANDLE_INVALID;
			log_notification_enabled = false;
			atomic_store_explicit(&log_client_subscribed, false, memory_order_release);
			atomic_store_explicit(&log_notify_request_pending, false, memory_order_release);
			log_queue_clear();
			break;

		default:
			break;
	}
}

static bool log_queue_has_chunks(void) {
	return atomic_load_explicit(&log_chunk_count, memory_order_acquire) > 0;
}

static bool log_queue_try_lock(void) {
	return !atomic_flag_test_and_set_explicit(&log_queue_lock, memory_order_acquire);
}

static void log_queue_unlock(void) {
	atomic_flag_clear_explicit(&log_queue_lock, memory_order_release);
}

static void log_queue_clear(void) {
	atomic_store_explicit(&log_queue_clear_requested, true, memory_order_release);
	if (!log_queue_try_lock()) return;

	log_queue_reset_locked();
	log_queue_unlock();
}

static void log_queue_reset_locked(void) {
	log_chunk_head = 0;
	log_chunk_tail = 0;
	atomic_store_explicit(&log_chunk_count, 0, memory_order_release);
	atomic_store_explicit(&log_queue_clear_requested, false, memory_order_release);
}

static bool log_queue_push_chunk(const uint8_t *data, uint8_t len) {
	if (!log_queue_try_lock()) return false;

	if (atomic_load_explicit(&log_queue_clear_requested, memory_order_acquire)) log_queue_reset_locked();

	if (atomic_load_explicit(&log_chunk_count, memory_order_relaxed) == LOG_CHUNK_QUEUE_SIZE) {
		log_queue_unlock();
		return false;
	}

	memcpy(log_chunks[log_chunk_tail].data, data, len);
	log_chunks[log_chunk_tail].len = len;
	log_chunk_tail = (log_chunk_tail + 1) % LOG_CHUNK_QUEUE_SIZE;
	atomic_fetch_add_explicit(&log_chunk_count, 1, memory_order_release);
	log_queue_unlock();
	return true;
}

static bool log_queue_pop_chunk(log_chunk_t *chunk) {
	if (!log_queue_try_lock()) return false;

	if (atomic_load_explicit(&log_queue_clear_requested, memory_order_acquire)) {
		log_queue_reset_locked();
		log_queue_unlock();
		return false;
	}

	if (atomic_load_explicit(&log_chunk_count, memory_order_relaxed) == 0) {
		log_queue_unlock();
		return false;
	}

	*chunk = log_chunks[log_chunk_head];
	log_chunk_head = (log_chunk_head + 1) % LOG_CHUNK_QUEUE_SIZE;
	atomic_fetch_sub_explicit(&log_chunk_count, 1, memory_order_release);
	log_queue_unlock();
	return true;
}

static uint16_t read_notification_configuration(const bool enabled, const uint16_t offset, uint8_t *buffer,
                                                const uint16_t buffer_size) {
	uint8_t value[2] = {0, 0};
	if (enabled) little_endian_store_16(value, 0, GATT_CLIENT_CHARACTERISTICS_CONFIGURATION_NOTIFICATION);

	return att_read_callback_handle_blob(value, sizeof value, offset, buffer, buffer_size);
}

static void request_log_send_safe(void) {
	if (atomic_exchange_explicit(&log_send_request_pending, true, memory_order_acq_rel)) return;

	log_send_callback_registration.callback = schedule_log_send_callback;
	log_send_callback_registration.context = nullptr;
	btstack_run_loop_execute_on_main_thread(&log_send_callback_registration);
}

static void request_log_send_from_main(void) {
	if (log_connection_handle == HCI_CON_HANDLE_INVALID || !log_notification_enabled) {
		atomic_store_explicit(&log_notify_request_pending, false, memory_order_release);
		log_queue_clear();
		return;
	}
	if (!log_queue_has_chunks()) return;
	if (atomic_exchange_explicit(&log_notify_request_pending, true, memory_order_acq_rel)) return;

	log_notify_callback_registration.callback = notify_log_client_callback;
	log_notify_callback_registration.context = nullptr;
	const auto status = att_server_request_to_send_notification(&log_notify_callback_registration, log_connection_handle);
	if (status == ERROR_CODE_COMMAND_DISALLOWED) return;
	if (status != ERROR_CODE_SUCCESS) {
		atomic_store_explicit(&log_notify_request_pending, false, memory_order_release);
	}
}

static void schedule_log_send_callback(void *context) {
	(void)context;

	atomic_store_explicit(&log_send_request_pending, false, memory_order_release);
	request_log_send_from_main();
}

static void notify_log_client_callback(void *context) {
	(void)context;

	atomic_store_explicit(&log_notify_request_pending, false, memory_order_release);

	if (log_connection_handle == HCI_CON_HANDLE_INVALID || !log_notification_enabled) {
		log_queue_clear();
		return;
	}

	auto chunk = (log_chunk_t){0};
	if (!log_queue_pop_chunk(&chunk)) {
		if (log_queue_has_chunks()) request_log_send_from_main();
		return;
	}

	(void)att_server_notify(log_connection_handle,
	                        ATT_CHARACTERISTIC_F7A4C002_2E2D_4E4B_9F2C_5049434F5243_01_VALUE_HANDLE, chunk.data,
	                        chunk.len);

	if (log_queue_has_chunks()) request_log_send_from_main();
}
