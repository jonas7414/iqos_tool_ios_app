//
//  ContentView.swift
//  iqos_tool
//
//  Created by 陳阿頡 on 2026/5/11.
//

import Combine
import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = IQOSToolViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    DeviceHeaderView(viewModel: viewModel)
                    ScanPanelView(viewModel: viewModel)
                    ControlPanelView(viewModel: viewModel)
                    DiagnosticsPanelView(viewModel: viewModel)
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("IQOS Tool")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        viewModel.refreshConnectedDevice()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(viewModel.connectedDevice == nil || viewModel.isBusy)
                    .accessibilityLabel("Refresh")
                }
            }
        }
        .alert("操作失敗", isPresented: $viewModel.isShowingError) {
            Button("好", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage)
        }
    }
}

private struct DeviceHeaderView: View {
    @ObservedObject var viewModel: IQOSToolViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(viewModel.connectedDevice == nil ? Color(.tertiarySystemFill) : Color.green.opacity(0.16))
                    Image(systemName: viewModel.connectedDevice == nil ? "dot.radiowaves.left.and.right" : "checkmark.seal.fill")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(viewModel.connectedDevice == nil ? Color.secondary : Color.green)
                }
                .frame(width: 56, height: 56)

                VStack(alignment: .leading, spacing: 6) {
                    Text(viewModel.connectedDevice?.displayName ?? "尚未連線")
                        .font(.title2.weight(.semibold))
                        .lineLimit(2)
                    Text(viewModel.statusText)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 0)
            }

            HStack(spacing: 10) {
                MetricTile(title: "電量", value: viewModel.batteryText, icon: "battery.100percent")
                MetricTile(title: "型號", value: viewModel.connectedDevice?.model.displayName ?? "--", icon: "iphone.gen3")
                MetricTile(title: "訊號", value: viewModel.connectedRSSIText, icon: "antenna.radiowaves.left.and.right")
            }
        }
        .padding(16)
        .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct MetricTile: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.teal)
            Text(value)
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct ScanPanelView: View {
    @ObservedObject var viewModel: IQOSToolViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("附近裝置", systemImage: "wave.3.right")
                    .font(.headline)
                Spacer()
                Button {
                    viewModel.startScan()
                } label: {
                    if viewModel.isScanning {
                        ProgressView()
                    } else {
                        Image(systemName: "magnifyingglass")
                    }
                }
                .frame(width: 36, height: 36)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .disabled(viewModel.isScanning || viewModel.isConnecting)
                .accessibilityLabel("Scan")
            }

            if viewModel.discoveredDevices.isEmpty {
                EmptyScanView(isScanning: viewModel.isScanning)
            } else {
                VStack(spacing: 8) {
                    ForEach(viewModel.discoveredDevices) { device in
                        Button {
                            viewModel.connect(to: device)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "circle.grid.cross.fill")
                                    .font(.title3)
                                    .foregroundStyle(.mint)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(device.displayName)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.primary)
                                    Text("\(device.model.displayName)  \(device.rssiText)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if viewModel.connectingDeviceID == device.id {
                                    ProgressView()
                                } else {
                                    Image(systemName: "chevron.right")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            .padding(12)
                            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                        .disabled(viewModel.isConnecting)
                    }
                }
            }
        }
        .panelStyle()
    }
}

private struct EmptyScanView: View {
    let isScanning: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isScanning ? "dot.radiowaves.left.and.right" : "tray")
                .font(.title3)
                .foregroundStyle(.secondary)
            Text(isScanning ? "正在搜尋 IQOS 裝置" : "點擊搜尋開始掃描")
                .font(.callout)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct ControlPanelView: View {
    @ObservedObject var viewModel: IQOSToolViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("控制", systemImage: "slider.horizontal.3")
                .font(.headline)

            Picker("亮度", selection: $viewModel.selectedBrightness) {
                Text("高").tag(IQOSBrightnessLevel.high)
                Text("低").tag(IQOSBrightnessLevel.low)
            }
            .pickerStyle(.segmented)
            .disabled(!viewModel.supports(.brightness) || viewModel.isBusy)
            .onChange(of: viewModel.selectedBrightness) { _, level in
                viewModel.setBrightness(level)
            }

            VStack(spacing: 10) {
                ToggleRow(
                    title: "FlexPuff",
                    subtitle: "ILUMA i / i PRIME",
                    icon: "wind",
                    isOn: $viewModel.flexPuffEnabled,
                    isEnabled: viewModel.supports(.flexPuff)
                ) { value in
                    viewModel.setFlexPuff(value)
                }

                ToggleRow(
                    title: "Pause Mode",
                    subtitle: viewModel.flexBatteryMode == .eco ? "Eco 電池模式" : "Performance 電池模式",
                    icon: "pause.circle",
                    isOn: $viewModel.pauseModeEnabled,
                    isEnabled: viewModel.supports(.flexBattery)
                ) { _ in
                    viewModel.setFlexBatterySettings()
                }

                ToggleRow(
                    title: "Auto Start",
                    subtitle: "插入時自動啟動",
                    icon: "bolt.fill",
                    isOn: $viewModel.autoStartEnabled,
                    isEnabled: viewModel.supports(.autoStart)
                ) { value in
                    viewModel.setAutoStart(value)
                }
            }

            Picker("電池模式", selection: $viewModel.flexBatteryMode) {
                Text("效能").tag(IQOSFlexBatteryMode.performance)
                Text("節能").tag(IQOSFlexBatteryMode.eco)
            }
            .pickerStyle(.segmented)
            .disabled(!viewModel.supports(.flexBattery) || viewModel.isBusy)
            .onChange(of: viewModel.flexBatteryMode) { _, _ in
                viewModel.setFlexBatterySettings()
            }

            HStack(spacing: 10) {
                ActionButton(title: "鎖定", icon: "lock.fill", tint: .red) {
                    viewModel.lockDevice()
                }
                ActionButton(title: "解鎖", icon: "lock.open.fill", tint: .green) {
                    viewModel.unlockDevice()
                }
                ActionButton(title: "尋找", icon: "location.fill", tint: .orange) {
                    viewModel.pulseFindMyIQOS()
                }
            }
            .disabled(viewModel.connectedDevice == nil || viewModel.isBusy)
        }
        .panelStyle()
    }
}

private struct ToggleRow: View {
    let title: String
    let subtitle: String
    let icon: String
    @Binding var isOn: Bool
    let isEnabled: Bool
    let onChange: (Bool) -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundStyle(isEnabled ? .teal : .secondary)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(isEnabled ? subtitle : "此型號不支援")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Toggle(title, isOn: $isOn)
                .labelsHidden()
                .disabled(!isEnabled)
                .onChange(of: isOn) { _, value in
                    guard isEnabled else { return }
                    onChange(value)
                }
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct ActionButton: View {
    let title: String
    let icon: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.headline)
                Text(title)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .frame(maxWidth: .infinity, minHeight: 62)
            .foregroundStyle(tint)
            .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }
}

private struct DiagnosticsPanelView: View {
    @ObservedObject var viewModel: IQOSToolViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("診斷", systemImage: "stethoscope")
                    .font(.headline)
                Spacer()
                Button {
                    viewModel.refreshDiagnostics()
                } label: {
                    Image(systemName: "arrow.triangle.2.circlepath")
                }
                .frame(width: 36, height: 36)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .disabled(viewModel.connectedDevice == nil || viewModel.isBusy)
                .accessibilityLabel("Refresh Diagnostics")
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                InfoCell(title: "產品序號", value: viewModel.status?.productNumber ?? "--")
                InfoCell(title: "韌體", value: viewModel.status?.stickFirmware.description ?? "--")
                InfoCell(title: "使用天數", value: viewModel.diagnostics?.daysUsed.map(String.init) ?? "--")
                InfoCell(title: "總次數", value: viewModel.diagnostics?.totalSmokingCount.map(String.init) ?? "--")
                InfoCell(title: "電壓", value: viewModel.voltageText)
                InfoCell(title: "序號", value: viewModel.connectedDevice?.deviceInfo.serialNumber ?? "--")
            }
        }
        .panelStyle()
    }
}

private struct InfoCell: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .frame(minHeight: 66)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

@MainActor
final class IQOSToolViewModel: ObservableObject {
    @Published var discoveredDevices: [IQOSDiscoveredDevice] = []
    @Published var connectedDevice: IQOSConnectedDevice?
    @Published var batteryLevel: UInt8?
    @Published var selectedBrightness: IQOSBrightnessLevel = .high
    @Published var flexPuffEnabled = false
    @Published var flexBatteryMode: IQOSFlexBatteryMode = .performance
    @Published var pauseModeEnabled = false
    @Published var autoStartEnabled = false
    @Published var diagnostics: IQOSDiagnosticData?
    @Published var status: IQOSDeviceStatus?
    @Published var connectedRSSI: Int?
    @Published var statusText = "請先搜尋並連線附近的 IQOS 裝置"
    @Published var isScanning = false
    @Published var isConnecting = false
    @Published var isBusy = false
    @Published var connectingDeviceID: UUID?
    @Published var isShowingError = false
    @Published var errorMessage = ""

    private let client = CoreBluetoothIQOSClient()
    private var device: IQOSDevice?
    private var scanTask: Task<Void, Never>?
    private var rssiMonitorTask: Task<Void, Never>?

    var batteryText: String {
        batteryLevel.map { "\($0)%" } ?? "--"
    }

    var connectedRSSIText: String {
        connectedRSSI.map { "\($0) dBm" } ?? "--"
    }

    var voltageText: String {
        if let statusVoltage = status?.batteryVoltage {
            return String(format: "%.2f V", statusVoltage)
        }
        if let diagnosticVoltage = diagnostics?.batteryVoltage {
            return String(format: "%.2f V", diagnosticVoltage)
        }
        return "--"
    }

    func supports(_ capability: IQOSDeviceCapability) -> Bool {
        connectedDevice?.model.supports(capability) ?? false
    }

    func startScan() {
        rssiMonitorTask?.cancel()
        scanTask?.cancel()
        discoveredDevices = []
        isScanning = true
        statusText = "正在搜尋附近裝置"

        scanTask = Task { [weak self] in
            guard let self else { return }
            for await discovered in client.scan(timeout: 8) {
                guard !Task.isCancelled else { break }
                upsert(discovered)
            }
            isScanning = false
            if connectedDevice == nil {
                statusText = discoveredDevices.isEmpty ? "沒有找到 IQOS 裝置" : "選擇裝置進行連線"
            } else {
                startRSSIMonitoring()
            }
        }
    }

    func connect(to discoveredDevice: IQOSDiscoveredDevice) {
        connectingDeviceID = discoveredDevice.id
        isConnecting = true
        statusText = "正在連線到 \(discoveredDevice.displayName)"

        Task { [weak self] in
            guard let self else { return }
            do {
                let connected = try await client.connect(to: discoveredDevice)
                let summary = connected.connectedDevice
                device = connected
                connectedDevice = summary
                connectedRSSI = discoveredDevice.rssi
                statusText = "已連線"
                try await refreshAll()
                startRSSIMonitoring()
            } catch {
                show(error)
                statusText = "連線失敗"
            }
            isConnecting = false
            connectingDeviceID = nil
        }
    }

    func refreshConnectedDevice() {
        guard device != nil else { return }
        Task {
            do {
                try await refreshAll()
            } catch {
                show(error)
            }
        }
    }

    func refreshDiagnostics() {
        guard let device else { return }
        isBusy = true
        Task {
            do {
                diagnostics = try await device.readDiagnosis()
                status = try? await device.readDeviceStatus()
                statusText = "診斷資料已更新"
            } catch {
                show(error)
            }
            isBusy = false
        }
    }

    func setBrightness(_ level: IQOSBrightnessLevel) {
        guard let device, supports(.brightness) else { return }
        runCommand("亮度已更新") {
            try await device.setBrightness(level)
        }
    }

    func setFlexPuff(_ enabled: Bool) {
        guard let device, supports(.flexPuff) else { return }
        runCommand("FlexPuff 已更新") {
            try await device.setFlexPuffEnabled(enabled)
        }
    }

    func setFlexBatterySettings() {
        guard let device, supports(.flexBattery) else { return }
        let settings = IQOSFlexBatterySettings(mode: flexBatteryMode, pauseMode: pauseModeEnabled)
        runCommand("電池設定已更新") {
            try await device.setFlexBatterySettings(settings)
        }
    }

    func setAutoStart(_ enabled: Bool) {
        guard let device, supports(.autoStart) else { return }
        runCommand("Auto Start 已更新") {
            try await device.setAutoStartEnabled(enabled)
        }
    }

    func lockDevice() {
        guard let device, supports(.deviceLock) else { return }
        runCommand("裝置已鎖定") {
            try await device.lock()
        }
    }

    func unlockDevice() {
        guard let device, supports(.deviceLock) else { return }
        runCommand("裝置已解鎖") {
            try await device.unlock()
        }
    }

    func pulseFindMyIQOS() {
        guard let device else { return }
        runCommand("已送出尋找裝置指令") {
            try await device.startFindMyIQOS()
            try await Task.sleep(nanoseconds: 2_000_000_000)
            try await device.stopFindMyIQOS()
        }
    }

    private func refreshAll() async throws {
        guard let device else { return }
        isBusy = true
        defer { isBusy = false }

        batteryLevel = try? await device.readBatteryLevel()
        selectedBrightness = (try? await device.readBrightness()) ?? selectedBrightness

        if supports(.flexPuff) {
            flexPuffEnabled = (try? await device.readFlexPuffEnabled()) ?? flexPuffEnabled
        }

        if supports(.flexBattery), let settings = try? await device.readFlexBatterySettings() {
            flexBatteryMode = settings.mode
            pauseModeEnabled = settings.pauseMode ?? false
        }

        if supports(.autoStart) {
            autoStartEnabled = (try? await device.readAutoStartEnabled()) ?? autoStartEnabled
        }

        diagnostics = try? await device.readDiagnosis()
        status = try? await device.readDeviceStatus()
        statusText = "資料已更新"
    }

    private func startRSSIMonitoring() {
        rssiMonitorTask?.cancel()
        guard let connectedID = connectedDevice?.identifier else { return }

        rssiMonitorTask = Task { [weak self] in
            guard let self else { return }

            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                guard !Task.isCancelled, !isScanning else { continue }

                for await discovered in client.scan(timeout: 3) {
                    guard !Task.isCancelled else { break }
                    upsert(discovered)
                    if discovered.id == connectedID {
                        connectedRSSI = discovered.rssi
                    }
                }
            }
        }
    }

    private func upsert(_ discovered: IQOSDiscoveredDevice) {
        if let index = discoveredDevices.firstIndex(where: { $0.id == discovered.id }) {
            discoveredDevices[index] = discovered
        } else {
            discoveredDevices.append(discovered)
        }

        if connectedDevice?.identifier == discovered.id {
            connectedRSSI = discovered.rssi
        }
    }

    private func runCommand(_ successMessage: String, operation: @escaping () async throws -> Void) {
        isBusy = true
        Task {
            do {
                try await operation()
                statusText = successMessage
            } catch {
                show(error)
            }
            isBusy = false
        }
    }

    private func show(_ error: Error) {
        errorMessage = String(describing: error)
        isShowingError = true
    }
}

private extension View {
    func panelStyle() -> some View {
        padding(16)
            .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private extension IQOSDiscoveredDevice {
    var displayName: String {
        name?.isEmpty == false ? name! : "IQOS \(id.uuidString.prefix(4))"
    }

    var rssiText: String {
        rssi.map { "\($0) dBm" } ?? "--"
    }
}

private extension IQOSConnectedDevice {
    var displayName: String {
        localName?.isEmpty == false ? localName! : "IQOS \(identifier.uuidString.prefix(4))"
    }

    var rssiText: String {
        "--"
    }
}

private extension IQOSDeviceModel {
    var displayName: String {
        switch self {
        case .ilumaOne: "ILUMA ONE"
        case .iluma: "ILUMA"
        case .ilumaPrime: "ILUMA PRIME"
        case .ilumaIOne: "ILUMA i ONE"
        case .ilumaI: "ILUMA i"
        case .ilumaIPrime: "ILUMA i PRIME"
        case .unknown: "Unknown"
        }
    }
}

#Preview {
    ContentView()
}
