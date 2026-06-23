This README is AI-generated from the current repository state. Treat it as orientation, not as the source of truth for design intent.

# PicoRC iOS App

`app/` contains the PicoRC iOS companion app. It is a SwiftUI/CoreBluetooth app that connects to the PicoRC tank over BLE and presents a live HUD for tank state, system metrics, logs, and debug-log settings.

The app does not drive the tank directly. Gamepad control is handled by the firmware via Bluepad32; the app visualizes the resulting firmware telemetry.

## Project Layout

- `PicoRC.xcodeproj` - Xcode project.
- `PicoRC/PicoRCApp.swift` - SwiftUI entry point; keeps the device awake while active.
- `PicoRC/ContentView.swift` - root UI with status bar and Tank/System/Log tabs.
- `PicoRC/Bluetooth/` - BLE profile constants, connection lifecycle, packet parsing.
- `PicoRC/Models/` - telemetry state, persisted app setting payload, and log buffering/filtering.
- `PicoRC/Views/` - SwiftUI screens and shared visual components.
- `PicoRC/Theme.swift` - color palette, background, panel styling, and section header components.
- `PicoRC/Assets.xcassets/` - app icon and asset catalog.

## Architecture Overview

`BluetoothStreamModel` is the app's central state owner. It:

1. Starts a `CBCentralManager`.
2. Scans for the PicoRC BLE service.
3. Connects to the tank peripheral.
4. Discovers the PicoRC stream and settings characteristics.
5. Subscribes to stream notifications.
6. Parses packets into published SwiftUI state.
7. Reads and writes the debug-log setting.

`ContentView` observes `BluetoothStreamModel` and fans state into three tabs:

- `TankView` renders controller connection, mode, LED state, drive output, and turret output.
- `SystemView` renders CPU load, clock, temperature, memory use, and boot count.
- `LogView` renders streamed firmware logs and provides the debug-log toggle.

The UI is intentionally read-mostly. The one writable BLE path is the debug-log setting.

## BLE Contract

The app uses the constants in `PicoRC/Bluetooth/PicoRCBluetoothProfile.swift`.

- Service UUID: `F7A4C001-2E2D-4E4B-9F2C-5049434F5243`
- Stream characteristic UUID: `F7A4C002-2E2D-4E4B-9F2C-5049434F5243`
- Settings characteristic UUID: `F7A4C003-2E2D-4E4B-9F2C-5049434F5243`

Stream packets are typed by the first byte:

- `0` - log text.
- `1` - full tank state, version `2`, 5-byte payload.
- `2` - tank state diff, version `2`.
- `3` - system state, version `4`, 20-byte payload.

Settings are version `1`, length `2`, encoded as `[version, flags]`. Bit `0` of `flags` enables debug logs.

## Running

Open the Xcode project:

```sh
open PicoRC.xcodeproj
```

Build and run the `PicoRC` target on an iPhone or iPad with Bluetooth access. The generated Info.plist includes the Bluetooth usage string: "PicoRC connects to nearby PicoRC devices over Bluetooth."

The app scans for peripherals advertising the PicoRC service UUID, falling back to the local name `PicoRC` when checking advertisement data.
