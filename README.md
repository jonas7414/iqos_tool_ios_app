# IQ Tool

English | [繁體中文](README.zh-Hant.md)

<div align="center">

[![Swift](https://img.shields.io/badge/Swift-5-orange?style=for-the-badge&logo=swift&logoColor=white)](https://www.swift.org/)
[![Platform](https://img.shields.io/badge/Platform-iOS-black?style=for-the-badge&logo=apple&logoColor=white)](https://developer.apple.com/ios/)
[![Bluetooth](https://img.shields.io/badge/Bluetooth-CoreBluetooth-0082FC?style=for-the-badge&logo=bluetooth&logoColor=white)](https://developer.apple.com/documentation/corebluetooth)
[![SideStore](https://img.shields.io/badge/SideStore-Source-7B2CBF?style=for-the-badge&logo=ios&logoColor=white)](https://raw.githubusercontent.com/jonas7414/iqos_tool_ios_app/main/apps.json)

</div>

IQ Tool is an iOS utility for educational and research use. It connects to supported IQOS-family devices over Bluetooth, shows device information, tracks usage history, and exposes supported device controls.

This app is inspired by and derived from the device-control research in [`hauntedfail/iqos_cli`](https://github.com/hauntedfail/iqos_cli). The iOS app reimplements the workflow with a touch-first interface.

> This project is not affiliated with, endorsed by, or sponsored by Philip Morris International. IQOS and related marks belong to Philip Morris International and their respective owners.

## Features

- Scan nearby devices and connect to known devices.
- View device name, model, connection status, battery level, and signal strength.
- Read firmware version, product number, total usage count, days used, voltage, and diagnostics.
- Track today usage, weekly trend, and historical daily records.
- Use the History page to view daily counts, month total, daily average, and best record.
- Automatically search for known devices when the app opens, then refresh data after connecting.
- Configure data refresh interval, background refresh, background scan, and auto search.
- Supported device controls:
  - Indicator light brightness
  - Battery mode: Performance / Eco
  - Pause mode
  - FlexPuff
  - Auto Start
  - Smart Gesture
  - Vibration settings
  - Lock / unlock
  - Find device
- Switch between light, dark, or system appearance.
- Use Debug mode to view logs, copy logs, and export a Debug ZIP.
- Built-in English and Traditional Chinese interface.

## Installation

### SideStore Source

Add this source URL in SideStore:

```text
https://raw.githubusercontent.com/jonas7414/iqos_tool_ios_app/main/apps.json
```

The current release points to:

```text
https://github.com/jonas7414/iqos_tool_ios_app/releases/download/v1.0.4/iqos_tool-v1.0.4.ipa
```

SideStore will download the unsigned IPA and sign it with your configured Apple ID.

### Manual IPA Install

1. Open the GitHub release page.
2. Download the `.ipa` asset.
3. Open SideStore.
4. Import the downloaded IPA.

## Compatibility Notes

Feature support depends on the connected device model and firmware. Some controls are only available on newer ILUMA i-family devices.

| Feature                        | Availability                |
| ------------------------------ | --------------------------- |
| Battery and status             | Supported devices           |
| Diagnostics and usage counters | Supported devices           |
| Indicator light brightness     | Supported devices           |
| Find device                    | Supported devices           |
| Lock / unlock                  | Supported devices           |
| FlexPuff                       | Selected models             |
| Battery mode                   | Selected models             |
| Auto Start                     | Selected models             |
| Smart Gesture                  | Selected models             |
| Widgets                        | Temporarily disabled in v1.0.4 |

## Support Matrix

| Version | Minimum iOS | Build SDK | Status |
| ------- | ----------- | --------- | ------ |
| v1.0.4  | iOS 26.4    | iOS 26.4  | Supported |

## Known Issues

1. Widgets and App Group packaging are temporarily disabled in v1.0.4 to improve SideStore installation and resigning compatibility.
2. The displayed days-used count may be incorrect. A future release will revisit the diagnostics parsing and display logic.

## Requirements

- iPhone with Bluetooth enabled
- SideStore for sideload installation, or Xcode for local development
- A supported nearby device
- iOS 26.4 or later

The app uses these system capabilities:

- Bluetooth access
- Background Bluetooth mode

## Development

Open the project:

```bash
open iqos_tool.xcodeproj
```

Build for simulator:

```bash
xcodebuild build-for-testing \
  -project iqos_tool.xcodeproj \
  -scheme iqos_tool \
  -destination 'generic/platform=iOS Simulator'
```

Build an unsigned iPhoneOS app for IPA packaging:

```bash
xcodebuild \
  -project iqos_tool.xcodeproj \
  -scheme iqos_tool \
  -configuration Release \
  -sdk iphoneos \
  -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO \
  build
```

## Project Structure

```text
.
├── apps.json
├── iqos_tool.xcodeproj
├── iqos_tool/
│   ├── ContentView.swift
│   ├── TodayUsageStore.swift
│   ├── iqos_toolApp.swift
│   ├── IQOSClient/
│   ├── en.lproj/
│   └── zh-Hant.lproj/
├── iqos_tool_widget/
│   ├── iqos_tool_widget.swift
│   ├── en.lproj/
│   └── zh-Hant.lproj/
├── iqos_toolTests/
└── iqos_toolUITests/
```

## Upstream Credit

This project originates from research and protocol behavior in:

- [`hauntedfail/iqos_cli`](https://github.com/hauntedfail/iqos_cli)
- [`hauntedfail/iqos`](https://github.com/hauntedfail/iqos)

## Legal and Safety Notice

IQ Tool is provided for educational and research purposes only.

The app includes a first-run compliance gate. It is not intended for use where prohibited by local law. Users are responsible for following applicable laws and device terms in their region.

All actual rights related to IQOS, device names, trademarks, and related intellectual property belong to Philip Morris International and their respective owners.

## License

Review the upstream licenses before distributing binaries or modified versions. This repository references behavior from GPL-licensed upstream projects, so redistribution may have license obligations.
