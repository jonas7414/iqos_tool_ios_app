# IQ Tool

[English](README.md) | 繁體中文

<div align="center">

[![Swift](https://img.shields.io/badge/Swift-5-orange?style=for-the-badge&logo=swift&logoColor=white)](https://www.swift.org/)
[![Platform](https://img.shields.io/badge/Platform-iOS-black?style=for-the-badge&logo=apple&logoColor=white)](https://developer.apple.com/ios/)
[![Bluetooth](https://img.shields.io/badge/Bluetooth-CoreBluetooth-0082FC?style=for-the-badge&logo=bluetooth&logoColor=white)](https://developer.apple.com/documentation/corebluetooth)
[![SideStore](https://img.shields.io/badge/SideStore-Source-7B2CBF?style=for-the-badge&logo=ios&logoColor=white)](https://raw.githubusercontent.com/jonas7414/iqos_tool_ios_app/main/apps.json)

</div>

IQ Tool 是一款以 SwiftUI 開發的 iOS 工具 App，僅供教育與研究用途。它可以透過 Bluetooth Low Energy 連線到支援的 IQOS 系列裝置，讀取裝置資訊、執行支援的控制功能，並提供桌面小工具快速查看狀態。

此 App 源自並參考 [`hauntedfail/iqos_cli`](https://github.com/hauntedfail/iqos_cli) 的裝置控制研究，再以 Swift、CoreBluetooth、SwiftUI、WidgetKit 重新實作成適合 iPhone 使用的介面。

> 本專案與 Philip Morris International 無關，未受其授權、背書或贊助。IQOS 與相關商標、名稱及權利歸 Philip Morris International 與其權利人所有。

## 功能

- 透過 CoreBluetooth 掃描與連線
- 顯示裝置狀態、電量、RSSI、韌體、產品編號與診斷資料
- 計算本日使用根數
- 桌面小工具顯示本日使用、剩餘電量與鎖定 / 解鎖捷徑
- 支援的控制功能：
    - 指示燈亮度
    - Battery Mode：Performance / Eco
    - Pause Mode
    - FlexPuff
    - Auto Start
    - Smart Gesture
    - 震動設定
    - 上鎖 / 解鎖
    - 尋找裝置
- 背景更新開關，可在 iOS 允許背景藍牙時更新已記憶裝置狀態
- Debug 模式、App 內 log、Debug ZIP 匯出
- GitHub 錯誤回報入口
- 英文與繁體中文 localization
- SideStore 相容的 unsigned IPA 自動 release workflow

## 安裝

### SideStore Source

在 SideStore 加入以下 source URL：

```text
https://raw.githubusercontent.com/jonas7414/iqos_tool_ios_app/main/apps.json
```

目前 release 版 IPA 指向：

```text
https://github.com/jonas7414/iqos_tool_ios_app/releases/download/v1.0.4/iqos_tool-v1.0.4.ipa
```

SideStore 會下載 unsigned IPA，並使用你設定的 Apple ID 重新簽名後安裝。

### 手動安裝 IPA

1. 打開 GitHub Release 頁面。
2. 下載 `.ipa` 檔案。
3. 打開 SideStore。
4. 匯入下載的 IPA。

## 相容性說明

功能是否可用取決於連線裝置型號與韌體版本。有些控制功能僅在較新的 ILUMA i 系列裝置上可用。

| 功能               | 可用性             |
| ------------------ | ------------------ |
| 電量與狀態         | 支援裝置           |
| 診斷資料與使用計數 | 支援裝置           |
| 指示燈亮度         | 支援裝置           |
| 尋找裝置           | 支援裝置           |
| 上鎖 / 解鎖        | 支援裝置           |
| FlexPuff           | 部分型號           |
| Battery Mode       | 部分型號           |
| Auto Start         | 部分型號           |
| Smart Gesture      | 部分型號           |
| 桌面小工具         | v1.0.4 暫時停用    |

## 支援版本

| 版本   | 最低 iOS 版本 | Build SDK | 狀態 |
| ------ | ------------- | --------- | ---- |
| v1.0.4 | iOS 26.4      | iOS 26.4  | 支援 |

## 已知問題

1. v1.0.4 暫時停用桌面小工具與 App Group 打包，降低 SideStore 安裝與重新簽名時的相容性問題。
2. 使用天數顯示數量目前可能不正確，後續版本會再修正診斷資料解析與顯示邏輯。

## 系統需求

- 已開啟藍牙的 iPhone
- SideStore，或用於本機開發的 Xcode
- 附近有支援的裝置
- iOS 26.4 或更新版本

此 App 使用以下能力：

- Bluetooth access
- Background Bluetooth mode
- App Groups，用於主 App 與 Widget 分享資料
- Widget extension

## 開發

打開專案：

```bash
open iqos_tool.xcodeproj
```

建立 simulator 測試 build：

```bash
xcodebuild build-for-testing \
  -project iqos_tool.xcodeproj \
  -scheme iqos_tool \
  -destination 'generic/platform=iOS Simulator'
```

建立 unsigned iPhoneOS app 以便包成 IPA：

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

## 專案結構

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

## 上游來源

本專案源自並參考以下專案的研究與 protocol 行為：

- [`hauntedfail/iqos_cli`](https://github.com/hauntedfail/iqos_cli)
- [`hauntedfail/iqos`](https://github.com/hauntedfail/iqos)

## 法律與安全聲明

IQ Tool 僅供教育與研究用途。

App 內包含首次啟動合規確認。本 App 不意圖提供給當地法律禁止的地區或情境使用。使用者需自行遵守所在地法律與裝置使用條款。

IQOS、裝置名稱、商標與相關智慧財產權均歸 Philip Morris International 與其權利人所有。

## 授權

散布 binary 或修改版本前，請先確認上游專案授權。本專案參考 GPL 授權上游專案的 protocol 行為，因此重新散布時可能有相應授權義務。
