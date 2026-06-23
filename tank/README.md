This README is AI-generated from the current repository state. Treat it as orientation, not as the source of truth for design intent.

# PicoRC Tank Firmware

`tank/` contains the Raspberry Pi Pico 2 W firmware for the PicoRC tank. The actual CMake project and source code live in `tank/src/`.

The firmware is a C23 Pico SDK application for RP2350/Pico 2 W. It uses FreeRTOS for task scheduling, Bluepad32 for gamepad input, BTstack/CYW43 for Bluetooth, LittleFS for flash-backed settings, and `lib/pico-shared` for local utility modules.

## Project Layout

- `src/CMakeLists.txt` - Pico SDK build, flash layout, dependencies, compiler flags, and post-build flashing commands.
- `src/main.c` - clock setup, stdio init, shared CPU init, state init, startup task creation, scheduler start.
- `src/tasks/` - FreeRTOS task definitions and task helpers.
- `src/control/` - gamepad input normalization and control-state application.
- `src/modules/app_bt/` - PicoRC BLE service, packet serialization, log streaming, settings characteristic.
- `src/modules/engine/` - main drive and turret PWM/GPIO output control.
- `src/modules/leds/` - red/white LED GPIO control.
- `src/storage/` - LittleFS block-device glue and persisted settings/app data.
- `src/state.*` - global runtime state and synchronized telemetry storage.
- `src/defines/config.h` - pin assignments and control constants.
- `src/shared_config.h` - shared integer aliases, timing constants, and `DBG` source of truth.

## Architecture Overview

Boot flow:

1. `main.c` sets the system clock to `APP_SYS_CLK_KHZ`, initializes stdio and CPU helpers, initializes shared state, creates the startup task, and starts FreeRTOS.
2. `task_startup` initializes LittleFS-backed storage, control input, actuation modules, CYW43, the status LED, and Bluepad32.
3. The custom Bluepad32 platform in `rc_platform.c` starts controller scanning and starts the PicoRC BLE app service when Bluetooth init completes.
4. Runtime tasks handle control, telemetry sampling, and diagnostics.

Runtime tasks:

- `control_input` runs every 10 ms and notifies `control_actuation`.
- `control_actuation` waits for notifications, applies the desired gamepad state to motors/turret/LEDs, and updates tank telemetry.
- `system_monitor` samples CPU load, CPU speed, CPU temperature, FreeRTOS heap, system heap, and boot count.
- `heartbeat` logs task stack usage and delay overruns.

Shared state is split between:

- `desired_state` - latest desired controller input.
- `state` - applied control state, telemetry, app settings, persisted app data, and task metadata.

Telemetry copies are protected with Pico critical sections in `state.c`.

## Control Model

Bluepad32 controller callbacks in `rc_platform.c` feed `control_input_on_gamepad`.

`control/input.c` normalizes gamepad axes, triggers, buttons, D-pad, dead zones, and connection state into `desired_state.control`.

`control/actuation.c` applies that state:

- Start + Select toggles advanced drive mode.
- A/Y toggles white LEDs.
- X/B toggles red LED.
- Basic mode uses throttle/brake plus steering.
- Advanced mode uses left/right stick-style drive inputs.
- D-pad controls turret rotation and lift.
- Disconnecting the controller stops drive and turret output.

## Bluetooth App Service

The firmware advertises as `PicoRC` and exposes a custom GATT service:

- Service UUID: `F7A4C001-2E2D-4E4B-9F2C-5049434F5243`
- Stream characteristic: `F7A4C002-2E2D-4E4B-9F2C-5049434F5243`, notify-only.
- Settings characteristic: `F7A4C003-2E2D-4E4B-9F2C-5049434F5243`, read/write.

Stream packet types are defined in `src/modules/app_bt/app_bt.h`:

- `APP_BT_PACKET_LOG = 0`
- `APP_BT_PACKET_TANK_STATE_FULL = 1`
- `APP_BT_PACKET_TANK_STATE_DIFF = 2`
- `APP_BT_PACKET_SYSTEM_STATE = 3`

Tank telemetry is sent every 50 ms. A full tank snapshot is sent when notifications start and then every 10 tank ticks; intermediate tank updates are diff packets. System telemetry is sent when notifications start and then every 500 ms.

Logs are routed through `utils_printf_sink` into BLE notifications when a client is subscribed.

## Persistence And Flash Layout

`src/storage/app_lfs.c` maps LittleFS onto a reserved flash region below BTstack's TLV bank. `src/storage/app_storage.c` stores:

- `/settings.bin` - app settings, currently the debug-log flag.
- `/app_data.bin` - app data, currently boot count.

Stored blobs include a magic value, schema version, payload length, and CRC.

## Building

Build from `tank/src` with the Pico SDK environment configured:

```sh
cd tank/src
cmake -S . -B cmake-build-release -DCMAKE_BUILD_TYPE=Release
cmake --build cmake-build-release
```

The default board is `pico2_w`. The CMake project expects `PICO_SDK_PATH`; it falls back to `lib/FreeRTOS-Kernel` when `FREERTOS_KERNEL_PATH` is not set.

Post-build behavior is configured in `src/CMakeLists.txt`:

- Release runs `/opt/homebrew/bin/picotool load -f Tank.uf2`.
- Debug runs `/usr/local/bin/openocd ... target/rp2350.cfg ... program Tank.elf verify reset exit`.

Change those commands if your local tool paths or flashing workflow differ.
