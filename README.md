This README is AI-generated from the current repository state. Treat it as orientation, not as the source of truth for design intent.

# PicoRC2

PicoRC2 is a remote-control tank project with two first-party pieces:

- `tank/` contains the Raspberry Pi Pico 2 W firmware for the vehicle.
- `app/` contains the iOS companion app that displays live telemetry, logs, and app-side settings over Bluetooth Low Energy.

The tank is driven by a Bluetooth gamepad connected directly to the Pico firmware through Bluepad32. The iOS app is a monitoring and diagnostic UI: it subscribes to the tank's custom BLE stream, visualizes tank/system state, shows firmware logs, and writes the debug-log setting back to the tank.

## Repository Layout

- `app/` - Xcode/SwiftUI iOS app.
- `tank/` - Pico 2 W firmware project; firmware sources live under `tank/src/`.
- `lib/` - vendored or shared firmware dependencies.
  - `bluepad32` - gamepad Bluetooth stack integration.
  - `FreeRTOS-Kernel` - RTOS kernel.
  - `littlefs` - flash-backed persistence.
  - `pico-shared` - local shared Pico helper library.
- `AGENTS.md` - project coding/style instructions for agents.

## Architecture Overview

The firmware owns real-time control:

1. Bluepad32 discovers and connects a gamepad.
2. Controller events update the desired control state.
3. FreeRTOS control tasks apply that state to drive motors, turret outputs, and LEDs.
4. Firmware telemetry is serialized into a custom BLE GATT service.

The app owns presentation and diagnostics:

1. CoreBluetooth scans for the PicoRC service.
2. The app subscribes to a notification characteristic for logs and telemetry.
3. SwiftUI views render tank state, system metrics, and console output.
4. The app reads/writes a settings characteristic for debug-log visibility.

The shared BLE service UUID is `F7A4C001-2E2D-4E4B-9F2C-5049434F5243`.

## Development Entry Points

For the app, open:

```sh
open app/PicoRC.xcodeproj
```

For the firmware, work from:

```sh
cd tank/src
```

The firmware CMake project expects the Pico SDK environment to be configured, especially `PICO_SDK_PATH`. Release and Debug builds also have post-build flashing commands wired into `tank/src/CMakeLists.txt`.

## Protocol At A Glance

The PicoRC BLE service exposes:

- `F7A4C002-2E2D-4E4B-9F2C-5049434F5243` - notify-only typed stream.
- `F7A4C003-2E2D-4E4B-9F2C-5049434F5243` - read/write settings payload.

Stream packet types:

- `0` - UTF-8 log chunk.
- `1` - full tank telemetry snapshot.
- `2` - tank telemetry diff.
- `3` - system telemetry snapshot.

Tank telemetry is sent every 50 ms. System telemetry is sent when notifications start and then every 500 ms.

Settings payload version `1` is `[version, flags]`; flag bit `0` enables debug logs.
