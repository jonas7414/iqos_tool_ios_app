# iqos_tool_ios_app

<div align="center">

**A SwiftUI iOS app for scanning, connecting to, and controlling IQOS ILUMA devices over Bluetooth Low Energy.**

[![Swift](https://img.shields.io/badge/swift-5-orange.svg?style=flat-square&logo=swift)](https://www.swift.org/)
[![Platform](https://img.shields.io/badge/platform-iOS-lightgrey.svg?style=flat-square&logo=apple)](https://developer.apple.com/ios/)
[![Bluetooth](https://img.shields.io/badge/BLE-CoreBluetooth-teal.svg?style=flat-square)](https://developer.apple.com/documentation/corebluetooth)

</div>

## GitHub 專案描述

一款以 SwiftUI 與 CoreBluetooth 開發的 iOS App，用於掃描、連線並控制
IQOS ILUMA 系列裝置。此 App 源自
[`hauntedfail/iqos_cli`](https://github.com/hauntedfail/iqos_cli) 的 IQOS BLE
控制概念，並重新實作為適合 iPhone 使用的圖形化介面。

## Overview

`iqos_tool_ios_app` is an iPhone-focused SwiftUI port of the device-control ideas
from [`hauntedfail/iqos_cli`](https://github.com/hauntedfail/iqos_cli). Instead
of a Rust command-line interface and terminal REPL, this project provides a
native iOS interface backed by CoreBluetooth and an async Swift device API.

The app is designed for IQOS ILUMA-family devices. It can scan nearby devices,
connect through BLE, show live device state, and expose supported controls in a
touch-friendly UI.

## Features

- BLE device discovery and connection through CoreBluetooth
- Live RSSI/signal updates for discovered and connected devices
- Battery level and device metadata display
- Brightness control for supported ILUMA devices
- FlexPuff enable/disable support
- FlexBattery mode and pause-mode controls
- Auto Start toggle for ILUMA i-family models
- Device lock and unlock actions
- Find My IQOS vibration trigger
- Diagnosis view for usage counters, battery voltage, firmware, and product data
- SwiftUI dashboard optimized for repeated device operations

## Device Compatibility

Feature availability depends on the detected IQOS model:

| Feature | ILUMA i | ILUMA i ONE | ILUMA i PRIME | ILUMA | ILUMA ONE | ILUMA PRIME |
| --- | :---: | :---: | :---: | :---: | :---: | :---: |
| Battery status | Yes | Yes | Yes | Yes | Yes | Yes |
| Device info | Yes | Yes | Yes | Yes | Yes | Yes |
| Diagnosis | Yes | Yes | Yes | Yes | Yes | Yes |
| Find My IQOS | Yes | Yes | Yes | Yes | Yes | Yes |
| Lock / unlock | Yes | Yes | Yes | Yes | Yes | Yes |
| Brightness | Yes | Yes | Yes | Yes | Yes | Yes |
| Auto Start | Yes | Yes | Yes | No | No | No |
| Smart Gesture protocol support | Yes | Yes | Yes | Yes | No | Yes |
| FlexPuff | Yes | No | Yes | No | No | No |
| FlexBattery | Yes | No | Yes | No | No | No |

## iOS Requirements

The app requires Bluetooth permission. The target includes:

```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>This app connects to nearby IQOS devices over Bluetooth.</string>
```

Runtime requirements:

- iPhone or iPad with Bluetooth enabled
- iOS target supported by the Xcode project
- IQOS device powered on and within BLE range

## Project Structure

```text
iqos_tool/
├── iqos_tool/
│   ├── ContentView.swift
│   ├── iqos_toolApp.swift
│   └── IQOSClient/
│       ├── CoreBluetoothIQOSClient.swift
│       ├── IQOSDeviceStore.swift
│       ├── IQOSError.swift
│       ├── IQOSProtocol.swift
│       ├── IQOSTransport.swift
│       └── Models.swift
├── iqos_toolTests/
│   └── IQOSProtocolTests.swift
└── iqos_tool.xcodeproj
```

## Development

Open the project in Xcode:

```bash
open iqos_tool.xcodeproj
```

Build from the command line:

```bash
xcodebuild build-for-testing \
  -project iqos_tool.xcodeproj \
  -scheme iqos_tool \
  -destination 'generic/platform=iOS Simulator'
```

Run protocol parser tests from Xcode or with an available simulator destination.

## Upstream Credit

This project is an iOS/Swift adaptation inspired by:

- [`hauntedfail/iqos_cli`](https://github.com/hauntedfail/iqos_cli) - Rust CLI for IQOS BLE control
- [`hauntedfail/iqos`](https://github.com/hauntedfail/iqos) - IQOS protocol and BLE logic used by the CLI ecosystem

The CLI shell, desktop BLE adapter, command parser, and terminal workflow were
not copied into this app. The device-facing behavior was rewritten for Swift,
CoreBluetooth, and SwiftUI.

## License Notice

The protocol behavior is based on GPL-3.0 upstream projects. Review the upstream
licenses before publishing binaries or distributing this app.
