# Copyright (C) 2025 Laurynas 'Deviltry' Ekekeke
# SPDX-License-Identifier: AGPL-3.0-only

#!/bin/bash

find_device() {
	ls /dev/tty.usbmodem* 2>/dev/null | head -n 1
}

while true; do
		device=$(find_device)

		if [ -z "$device" ]; then
				echo "No serial device found. Trying to reconnect"
				sleep 1
				continue
		fi

		# use CTRL + A -> CTRL + X to quit
		picocom -b 115200 "$device"
		echo "Device disconnected. Trying to reconnect"
		sleep 1
done
