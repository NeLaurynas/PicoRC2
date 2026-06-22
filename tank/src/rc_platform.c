// Copyright (C) 2025 Laurynas 'Deviltry' Ekekeke
// SPDX-License-Identifier: BSD-3-Clause

#include <pico/cyw43_arch.h>
#include <stddef.h>
#include <string.h>
#include <uni.h>

#include "control/input.h"
#include "modules/app_bt/app_bt.h"
#include "sdkconfig.h"

#ifndef CONFIG_BLUEPAD32_PLATFORM_CUSTOM
#error "Pico W must use BLUEPAD32_PLATFORM_CUSTOM"
#endif

static void rc_platform_init(int argc, const char **argv) {
	ARG_UNUSED(argc);
	ARG_UNUSED(argv);

	logi("rc_platform: init()\n");

	uni_gamepad_mappings_t mappings = GAMEPAD_DEFAULT_MAPPINGS;

	mappings.axis_ry_inverted = true;
	mappings.axis_y_inverted = true;

	uni_gamepad_set_mappings(&mappings);
}

static void rc_platform_on_init_complete() {
	logi("rc_platform: on_init_complete()\n");

	uni_bt_del_keys_unsafe();
	uni_bt_bredr_delete_bonded_keys();
	uni_bt_le_delete_bonded_keys();

	uni_bt_start_scanning_and_autoconnect_unsafe();

	cyw43_arch_gpio_put(CYW43_WL_GPIO_LED_PIN, 0);

	app_bt_start();
}

static uni_error_t rc_platform_on_device_discovered(bd_addr_t addr, const char *name, u16 cod, u8 rssi) {
	(void)addr;
	ARG_UNUSED(name);
	ARG_UNUSED(rssi);

	if (((cod & UNI_BT_COD_MINOR_MASK) & UNI_BT_COD_MINOR_KEYBOARD) == UNI_BT_COD_MINOR_KEYBOARD) {
		logi("Ignoring keyboard\n");
		return UNI_ERROR_IGNORE_DEVICE;
	}

	return UNI_ERROR_SUCCESS;
}

static void rc_platform_on_device_connected(uni_hid_device_t *d) {
	logi("rc_platform: device connected: %p\n", d);
	control_input_on_connected();
	uni_bt_stop_scanning_unsafe();
}

static void rc_platform_on_device_disconnected(uni_hid_device_t *d) {
	logi("rc_platform: device disconnected: %p\n", d);
	control_input_on_disconnected();
	uni_bt_start_scanning_and_autoconnect_unsafe();
}

static uni_error_t rc_platform_on_device_ready(uni_hid_device_t *d) {
	logi("rc_platform: device ready: %p\n", d);

	return UNI_ERROR_SUCCESS;
}

static void rc_platform_on_controller_data(uni_hid_device_t *d, uni_controller_t *ctl) {
	ARG_UNUSED(d);

	switch (ctl->klass) {
		case UNI_CONTROLLER_CLASS_GAMEPAD:
			control_input_on_gamepad(&ctl->gamepad);
			break;
		default:
			loge("Unsupported controller class: %d\n", ctl->klass);
			break;
	}
}

static const uni_property_t *rc_platform_get_property(uni_property_idx_t idx) {
	ARG_UNUSED(idx);
	return nullptr;
}

static void trigger_event_on_gamepad(uni_hid_device_t *d) {
	if (d->report_parser.play_dual_rumble != nullptr) {
		d->report_parser.play_dual_rumble(d, 0 /* delayed start ms */, 50 /* duration ms */, 128 /* weak magnitude */,
		                                  40 /* strong magnitude */);
	}
}

static void rc_platform_on_oob_event(uni_platform_oob_event_t event, void *data) {
	switch (event) {
		case UNI_PLATFORM_OOB_GAMEPAD_SYSTEM_BUTTON:
			trigger_event_on_gamepad((uni_hid_device_t *)data);
			break;

		case UNI_PLATFORM_OOB_BLUETOOTH_ENABLED:
			logi("rc_platform_on_oob_event: Bluetooth enabled: %d\n", (bool)(data));
			break;

		default:
			logi("rc_platform_on_oob_event: unsupported event: 0x%04x\n", event);
	}
}

struct uni_platform *get_rc_platform() {
	static struct uni_platform plat = {
		.name = "RC Platform",
		.init = rc_platform_init,
		.on_init_complete = rc_platform_on_init_complete,
		.on_device_discovered = rc_platform_on_device_discovered,
		.on_device_connected = rc_platform_on_device_connected,
		.on_device_disconnected = rc_platform_on_device_disconnected,
		.on_device_ready = rc_platform_on_device_ready,
		.on_oob_event = rc_platform_on_oob_event,
		.on_controller_data = rc_platform_on_controller_data,
		.get_property = rc_platform_get_property,
	};

	return &plat;
}
