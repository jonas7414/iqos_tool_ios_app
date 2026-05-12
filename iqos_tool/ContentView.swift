//
//  ContentView.swift
//  iqos_tool
//
//  Created by 陳阿頡 on 2026/5/11.
//

import Combine
import SwiftUI
import UniformTypeIdentifiers
#if canImport(UIKit)
import UIKit
#endif

private enum AppSection: String, CaseIterable {
    case control
    case settings

    var title: LocalizedStringKey {
        switch self {
        case .control: "Controls"
        case .settings: "Settings"
        }
    }

    var icon: String {
        switch self {
        case .control: "slider.horizontal.3"
        case .settings: "gearshape"
        }
    }
}

private enum ComplianceStatus: String {
    case pending
    case allowed
    case blockedRegion
    case blockedAge
}

struct ContentView: View {
    @StateObject private var viewModel = IQOSToolViewModel()
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedSection: AppSection = .control
    @State private var complianceStatus = ComplianceGateStore.status

    var body: some View {
        switch complianceStatus {
        case .allowed:
            mainContent
        case .blockedRegion, .blockedAge:
            ComplianceBlockedView(status: complianceStatus)
        case .pending:
            ComplianceGateView(
                onBlockedRegion: {
                    setComplianceStatus(.blockedRegion)
                },
                onBlockedAge: {
                    setComplianceStatus(.blockedAge)
                },
                onAllowed: {
                    setComplianceStatus(.allowed)
                }
            )
        }
    }

    private var mainContent: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    DeviceHeaderView(viewModel: viewModel)
                    if selectedSection == .control {
                        ScanPanelView(viewModel: viewModel)
                        ControlPanelView(viewModel: viewModel)
                        DiagnosticsPanelView(viewModel: viewModel)
                    } else {
                        SettingsPanelView(viewModel: viewModel)
                    }
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("IQ Tool")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    SectionMenuButton(selectedSection: $selectedSection)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        viewModel.refreshConnectedDevice()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(viewModel.connectedDevice == nil || viewModel.isBusy)
                    .accessibilityLabel(Text("Refresh"))
                }
            }
        }
        .alert("Operation Failed", isPresented: $viewModel.isShowingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage)
        }
        .onAppear {
            viewModel.refreshKnownDeviceUsageIfPossible()
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active, .background:
                viewModel.refreshKnownDeviceUsageIfPossible()
            case .inactive:
                break
            @unknown default:
                break
            }
        }
        .onOpenURL { url in
            viewModel.handleWidgetURL(url)
        }
    }

    private func setComplianceStatus(_ status: ComplianceStatus) {
        ComplianceGateStore.status = status
        complianceStatus = status
    }
}

private struct ComplianceGateView: View {
    enum Step {
        case region
        case age
    }

    @State private var step: Step = .region
    @State private var remainingReadSeconds = 5
    @State private var selectedBirthYear = Calendar.current.component(.year, from: Date()) - 20
    let onBlockedRegion: () -> Void
    let onBlockedAge: () -> Void
    let onAllowed: () -> Void

    private let birthYears = Array(stride(
        from: Calendar.current.component(.year, from: Date()) - 100,
        through: Calendar.current.component(.year, from: Date()),
        by: 1
    ).reversed())

    var body: some View {
        VStack(spacing: 18) {
            Spacer()

            Image(systemName: "exclamationmark.shield.fill")
                .font(.system(size: 48))
                .foregroundStyle(.orange)

            VStack(spacing: 8) {
                Text("Compliance Check")
                    .font(.title2.weight(.semibold))
                Text(promptText)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                Text("This app is for educational and research purposes only. All actual rights belong to Philip Morris International.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                if remainingReadSeconds > 0 {
                    Text(String(format: String(localized: "Please read for %d more seconds"), remainingReadSeconds))
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            VStack(spacing: 10) {
                if step == .region {
                    Button {
                        step = .age
                    } label: {
                        Text("No")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canContinue)

                    Button(role: .destructive) {
                        onBlockedRegion()
                    } label: {
                        Text("Yes, exit")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(!canContinue)
                } else {
                    birthYearSelection

                    Button {
                        if isSelectedBirthYearAllowed {
                            onAllowed()
                        } else {
                            onBlockedAge()
                        }
                    } label: {
                        Text("Continue")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canContinue)
                }
            }
            .padding(.horizontal, 28)

            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
        .task(id: step) {
            await runReadDelay()
        }
    }

    private var promptText: LocalizedStringKey {
        switch step {
        case .region:
            "Are you currently located within the territory of the Republic of China?"
        case .age:
            "Select your birth year to confirm you are 20 years of age or older."
        }
    }

    private var canContinue: Bool {
        remainingReadSeconds == 0
    }

    private var isSelectedBirthYearAllowed: Bool {
        let currentYear = Calendar.current.component(.year, from: Date())
        return selectedBirthYear <= currentYear - 20
    }

    private var birthYearSelection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Birth Year")
                .font(.subheadline.weight(.semibold))
            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(birthYears, id: \.self) { year in
                        Button {
                            selectedBirthYear = year
                        } label: {
                            HStack {
                                Text(String(year))
                                Spacer()
                                Image(systemName: selectedBirthYear == year ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(selectedBirthYear == year ? Color.accentColor : Color.secondary)
                            }
                            .padding(.horizontal, 12)
                            .frame(height: 40)
                            .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(maxHeight: 180)
            Text("Users born after the eligible year cannot continue.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func runReadDelay() async {
        remainingReadSeconds = 5
        while remainingReadSeconds > 0 {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            guard !Task.isCancelled else { return }
            remainingReadSeconds -= 1
        }
    }
}

private struct ComplianceBlockedView: View {
    let status: ComplianceStatus

    var body: some View {
        VStack(spacing: 18) {
            Spacer()

            Image(systemName: "nosign")
                .font(.system(size: 52))
                .foregroundStyle(.red)

            Text("Access Unavailable")
                .font(.title2.weight(.semibold))
            Text(messageText)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }

    private var messageText: LocalizedStringKey {
        switch status {
        case .blockedRegion:
            "This app is unavailable within the territory of the Republic of China."
        case .blockedAge:
            "This app is only available to users who are 20 years of age or older."
        case .pending, .allowed:
            ""
        }
    }
}

private struct SectionMenuButton: View {
    @Binding var selectedSection: AppSection

    var body: some View {
        Menu {
            ForEach(AppSection.allCases, id: \.self) { section in
                Button {
                    selectedSection = section
                } label: {
                    Label {
                        Text(section.title)
                    } icon: {
                        Image(systemName: selectedSection == section ? "checkmark" : section.icon)
                    }
                }
            }
        } label: {
            Image(systemName: "line.3.horizontal")
                .font(.headline)
                .frame(width: 36, height: 36)
        }
        .accessibilityLabel(Text("Menu"))
    }
}

private struct SelectedSectionHeader: View {
    let section: AppSection

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: section.icon)
                .font(.headline)
                .foregroundStyle(.teal)
            Text(section.title)
                .font(.headline)
            Spacer()
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
                    Text(viewModel.connectedDevice?.displayName ?? String(localized: "Not Connected"))
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
                MetricTile(title: "Battery", value: viewModel.batteryText, icon: "battery.100percent")
                MetricTile(title: "Model", value: viewModel.connectedDevice?.model.displayName ?? "--", icon: "iphone.gen3")
                MetricTile(title: "Signal", value: viewModel.connectedRSSIText, icon: "antenna.radiowaves.left.and.right")
            }
        }
        .padding(16)
        .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct MetricTile: View {
    let title: LocalizedStringKey
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
                Label("Nearby Devices", systemImage: "wave.3.right")
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
                .accessibilityLabel(Text("Scan"))
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
            Text(isScanning ? "Searching for IQOS devices" : "Tap search to start scanning")
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
            Label("Controls", systemImage: "slider.horizontal.3")
                .font(.headline)

            ControlSectionHeader(title: "Indicator Light", subtitle: "Choose the LED brightness level")
            Picker("Brightness", selection: $viewModel.selectedBrightness) {
                Text("High").tag(IQOSBrightnessLevel.high)
                Text("Low").tag(IQOSBrightnessLevel.low)
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
                    isEnabled: viewModel.supports(.flexPuff),
                    isBusy: viewModel.isBusy
                ) { value in
                    viewModel.setFlexPuff(value)
                }

                ToggleRow(
                    title: "Pause Mode",
                    subtitle: viewModel.flexBatteryMode == .eco ? "Eco battery mode" : "Performance battery mode",
                    icon: "pause.circle",
                    isOn: $viewModel.pauseModeEnabled,
                    isEnabled: viewModel.supports(.flexBattery),
                    isBusy: viewModel.isBusy
                ) { _ in
                    viewModel.setFlexBatterySettings()
                }

                ToggleRow(
                    title: "Auto Start",
                    subtitle: "Start automatically when inserted",
                    icon: "bolt.fill",
                    isOn: $viewModel.autoStartEnabled,
                    isEnabled: viewModel.supports(.autoStart),
                    isBusy: viewModel.isBusy
                ) { value in
                    viewModel.setAutoStart(value)
                }

                ToggleRow(
                    title: "Smart Gesture",
                    subtitle: "Enable gesture control on supported devices",
                    icon: "hand.tap",
                    isOn: $viewModel.smartGestureEnabled,
                    isEnabled: viewModel.supports(.smartGesture),
                    isBusy: viewModel.isBusy
                ) { value in
                    viewModel.setSmartGesture(value)
                }
            }

            ControlSectionHeader(title: "Battery Mode", subtitle: "Switch between performance and longer battery life")
            HStack(spacing: 10) {
                BatteryModeButton(
                    title: "Performance",
                    icon: "bolt.circle.fill",
                    tint: .indigo,
                    isSelected: viewModel.flexBatteryMode == .performance
                ) {
                    viewModel.setBatteryMode(.performance)
                }
                BatteryModeButton(
                    title: "Eco",
                    icon: "leaf.circle.fill",
                    tint: .green,
                    isSelected: viewModel.flexBatteryMode == .eco
                ) {
                    viewModel.setBatteryMode(.eco)
                }
            }
            .disabled(!viewModel.supports(.flexBattery) || viewModel.isBusy)

            VibrationPanelView(viewModel: viewModel)

            HStack(spacing: 10) {
                ActionButton(title: "Lock", icon: "lock.fill", tint: .red) {
                    viewModel.lockDevice()
                }
                ActionButton(title: "Unlock", icon: "lock.open.fill", tint: .green) {
                    viewModel.unlockDevice()
                }
            }
            .disabled(!viewModel.supports(.deviceLock) || viewModel.isBusy)

            ActionButton(title: "Find", icon: "location.fill", tint: .orange, minHeight: 54) {
                viewModel.pulseFindMyIQOS()
            }
            .disabled(viewModel.connectedDevice == nil || viewModel.isBusy)
        }
        .panelStyle()
    }
}

private struct ControlSectionHeader: View {
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct BatteryModeButton: View {
    let title: LocalizedStringKey
    let icon: String
    let tint: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.headline)
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .frame(maxWidth: .infinity, minHeight: 46)
            .foregroundStyle(isSelected ? .white : tint)
            .background(isSelected ? tint : tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct VibrationPanelView: View {
    @ObservedObject var viewModel: IQOSToolViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ControlSectionHeader(title: "Vibration", subtitle: "Choose when the device vibrates")
            ToggleRow(
                title: "Heating Start",
                subtitle: "Vibrate when heating starts",
                icon: "flame",
                isOn: $viewModel.vibrationSettings.whenHeatingStart,
                isEnabled: viewModel.supports(.vibration),
                isBusy: viewModel.isBusy
            ) { value in
                viewModel.setVibration(\.whenHeatingStart, enabled: value)
            }
            ToggleRow(
                title: "Session Start",
                subtitle: "Vibrate when usage starts",
                icon: "play.circle",
                isOn: $viewModel.vibrationSettings.whenStartingToUse,
                isEnabled: viewModel.supports(.vibration),
                isBusy: viewModel.isBusy
            ) { value in
                viewModel.setVibration(\.whenStartingToUse, enabled: value)
            }
            ToggleRow(
                title: "Puff End",
                subtitle: "Vibrate near puff end",
                icon: "timer",
                isOn: $viewModel.vibrationSettings.whenPuffEnd,
                isEnabled: viewModel.supports(.vibration),
                isBusy: viewModel.isBusy
            ) { value in
                viewModel.setVibration(\.whenPuffEnd, enabled: value)
            }
            ToggleRow(
                title: "Manual Stop",
                subtitle: "Vibrate after manual termination",
                icon: "stop.circle",
                isOn: $viewModel.vibrationSettings.whenManuallyTerminated,
                isEnabled: viewModel.supports(.vibration),
                isBusy: viewModel.isBusy
            ) { value in
                viewModel.setVibration(\.whenManuallyTerminated, enabled: value)
            }
            ToggleRow(
                title: "Charge Start",
                subtitle: "Vibrate when holder charging starts",
                icon: "battery.100percent.bolt",
                isOn: Binding(
                    get: { viewModel.vibrationSettings.whenChargingStart ?? false },
                    set: { viewModel.vibrationSettings.whenChargingStart = $0 }
                ),
                isEnabled: viewModel.supports(.chargeStartVibration),
                isBusy: viewModel.isBusy
            ) { value in
                viewModel.setChargeStartVibration(value)
            }
        }
    }
}

private struct ToggleRow: View {
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    let icon: String
    @Binding var isOn: Bool
    let isEnabled: Bool
    let isBusy: Bool
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
                Text(isEnabled ? subtitle : "This model is not supported")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Toggle(title, isOn: $isOn)
                .labelsHidden()
                .disabled(!isEnabled || isBusy)
                .onChange(of: isOn) { _, value in
                    guard isEnabled, !isBusy else { return }
                    onChange(value)
                }
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct ActionButton: View {
    let title: LocalizedStringKey
    let icon: String
    let tint: Color
    var minHeight: CGFloat = 62
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.headline)
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .frame(maxWidth: .infinity, minHeight: minHeight)
            .foregroundStyle(tint)
            .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct DiagnosticsPanelView: View {
    @ObservedObject var viewModel: IQOSToolViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Diagnostics", systemImage: "stethoscope")
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
                .accessibilityLabel(Text("Refresh Diagnostics"))
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                InfoCell(title: "Product Number", value: viewModel.status?.productNumber ?? "--")
                InfoCell(title: "Firmware", value: viewModel.status?.stickFirmware.description ?? "--")
                InfoCell(title: "Days Used", value: viewModel.diagnostics?.daysUsed.map(String.init) ?? "--")
                InfoCell(title: "Total Uses", value: viewModel.diagnostics?.totalSmokingCount.map(String.init) ?? "--")
                InfoCell(title: "Voltage", value: viewModel.voltageText)
                InfoCell(title: "Serial Number", value: viewModel.connectedDevice?.deviceInfo.serialNumber ?? "--")
            }
        }
        .panelStyle()
    }
}

private struct InfoCell: View {
    let title: LocalizedStringKey
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

private struct SettingsPanelView: View {
    @ObservedObject var viewModel: IQOSToolViewModel
    @State private var debugPackageDocument = DebugPackageDocument(data: Data())
    @State private var isExportingDebugPackage = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Settings", systemImage: "gearshape")
                .font(.headline)
                .onTapGesture(count: 10) {
                    viewModel.enableDebugMode()
                }

            Toggle(isOn: $viewModel.backgroundUsageRefreshEnabled) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Background Update")
                        .font(.subheadline.weight(.semibold))
                    Text("Automatically update today usage widget when iOS allows background Bluetooth")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 12) {
                Toggle(isOn: $viewModel.debugModeEnabled) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Debug Mode")
                            .font(.subheadline.weight(.semibold))
                        Text("Collect logs for troubleshooting and export a debug ZIP")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Button {
                    debugPackageDocument = DebugPackageDocument(data: viewModel.makeDebugPackage())
                    isExportingDebugPackage = true
                } label: {
                    Label("Export Debug ZIP", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "info.circle")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                Text("This app is for educational and research purposes only. All actual rights belong to Philip Morris International.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            Link(destination: Self.issueReportURL) {
                HStack(spacing: 12) {
                    Image(systemName: "exclamationmark.bubble")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Report an Issue")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                        Text("Open GitHub Issues to report bugs")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "arrow.up.forward")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(14)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }

            if viewModel.debugModeEnabled {
                DebugLogPanelView(viewModel: viewModel)
            }
        }
        .panelStyle()
        .fileExporter(
            isPresented: $isExportingDebugPackage,
            document: debugPackageDocument,
            contentType: .zip,
            defaultFilename: "iqos-debug-\(Self.debugExportDateFormatter.string(from: Date()))"
        ) { result in
            if case let .failure(error) = result {
                viewModel.showExportError(error)
            }
        }
    }

    private static let debugExportDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter
    }()

    private static let issueReportURL = URL(string: "https://github.com/jonas7414/iqos_tool_ios_app/issues")!
}

private struct DebugLogPanelView: View {
    @ObservedObject var viewModel: IQOSToolViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Debug Log", systemImage: "ladybug")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Button {
                    viewModel.clearDebugLogs()
                } label: {
                    Image(systemName: "trash")
                }
                .accessibilityLabel(Text("Clear Debug Log"))
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    if viewModel.debugLogs.isEmpty {
                        Text("No debug logs")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(viewModel.debugLogs.indices, id: \.self) { index in
                            Text(viewModel.debugLogs[index])
                                .font(.caption.monospaced())
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(minHeight: 160, maxHeight: 260)
            .padding(10)
            .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct DebugPackageDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.zip] }

    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

private enum DebugZIPBuilder {
    struct FileEntry {
        let path: String
        let data: Data
    }

    static func archive(files: [FileEntry]) -> Data {
        var archive = Data()
        var centralDirectory = Data()
        var centralDirectoryRecords = 0

        for file in files {
            let nameData = Data(file.path.utf8)
            let crc = CRC32.checksum(file.data)
            let localHeaderOffset = UInt32(archive.count)
            let size = UInt32(file.data.count)

            archive.appendUInt32LE(0x04034b50)
            archive.appendUInt16LE(20)
            archive.appendUInt16LE(0)
            archive.appendUInt16LE(0)
            archive.appendUInt16LE(0)
            archive.appendUInt16LE(0)
            archive.appendUInt32LE(crc)
            archive.appendUInt32LE(size)
            archive.appendUInt32LE(size)
            archive.appendUInt16LE(UInt16(nameData.count))
            archive.appendUInt16LE(0)
            archive.append(nameData)
            archive.append(file.data)

            centralDirectory.appendUInt32LE(0x02014b50)
            centralDirectory.appendUInt16LE(20)
            centralDirectory.appendUInt16LE(20)
            centralDirectory.appendUInt16LE(0)
            centralDirectory.appendUInt16LE(0)
            centralDirectory.appendUInt16LE(0)
            centralDirectory.appendUInt16LE(0)
            centralDirectory.appendUInt32LE(crc)
            centralDirectory.appendUInt32LE(size)
            centralDirectory.appendUInt32LE(size)
            centralDirectory.appendUInt16LE(UInt16(nameData.count))
            centralDirectory.appendUInt16LE(0)
            centralDirectory.appendUInt16LE(0)
            centralDirectory.appendUInt16LE(0)
            centralDirectory.appendUInt16LE(0)
            centralDirectory.appendUInt32LE(0)
            centralDirectory.appendUInt32LE(localHeaderOffset)
            centralDirectory.append(nameData)
            centralDirectoryRecords += 1
        }

        let centralDirectoryOffset = UInt32(archive.count)
        archive.append(centralDirectory)
        archive.appendUInt32LE(0x06054b50)
        archive.appendUInt16LE(0)
        archive.appendUInt16LE(0)
        archive.appendUInt16LE(UInt16(centralDirectoryRecords))
        archive.appendUInt16LE(UInt16(centralDirectoryRecords))
        archive.appendUInt32LE(UInt32(centralDirectory.count))
        archive.appendUInt32LE(centralDirectoryOffset)
        archive.appendUInt16LE(0)
        return archive
    }
}

private enum CRC32 {
    private static let table: [UInt32] = (0..<256).map { value in
        var crc = UInt32(value)
        for _ in 0..<8 {
            crc = (crc & 1) == 1 ? (0xedb88320 ^ (crc >> 1)) : (crc >> 1)
        }
        return crc
    }

    static func checksum(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xffffffff
        for byte in data {
            let index = Int((crc ^ UInt32(byte)) & 0xff)
            crc = table[index] ^ (crc >> 8)
        }
        return crc ^ 0xffffffff
    }
}

private extension Data {
    mutating func appendUInt16LE(_ value: UInt16) {
        append(UInt8(value & 0xff))
        append(UInt8((value >> 8) & 0xff))
    }

    mutating func appendUInt32LE(_ value: UInt32) {
        append(UInt8(value & 0xff))
        append(UInt8((value >> 8) & 0xff))
        append(UInt8((value >> 16) & 0xff))
        append(UInt8((value >> 24) & 0xff))
    }
}

@MainActor
final class IQOSToolViewModel: ObservableObject {
    private enum WidgetDeviceAction {
        case lock
        case unlock
    }

    @Published var discoveredDevices: [IQOSDiscoveredDevice] = []
    @Published var connectedDevice: IQOSConnectedDevice?
    @Published var batteryLevel: UInt8?
    @Published var selectedBrightness: IQOSBrightnessLevel = .high
    @Published var flexPuffEnabled = false
    @Published var flexBatteryMode: IQOSFlexBatteryMode = .performance
    @Published var pauseModeEnabled = false
    @Published var autoStartEnabled = false
    @Published var smartGestureEnabled = false
    @Published var vibrationSettings = IQOSVibrationSettings(
        whenHeatingStart: false,
        whenStartingToUse: false,
        whenPuffEnd: false,
        whenManuallyTerminated: false
    )
    @Published var diagnostics: IQOSDiagnosticData?
    @Published var status: IQOSDeviceStatus?
    @Published var connectedRSSI: Int?
    @Published var statusText = String(localized: "Search for and connect to a nearby IQOS device")
    @Published var isScanning = false
    @Published var isConnecting = false
    @Published var isBusy = false
    @Published var connectingDeviceID: UUID?
    @Published var isShowingError = false
    @Published var errorMessage = ""
    @Published var debugModeEnabled = AppSettingsStore.debugModeEnabled {
        didSet {
            AppSettingsStore.debugModeEnabled = debugModeEnabled
            if debugModeEnabled {
                log("Debug mode enabled")
            } else {
                consoleLog("Debug mode disabled")
            }
        }
    }
    @Published var debugLogs: [String] = []
    @Published var backgroundUsageRefreshEnabled = AppSettingsStore.backgroundUsageRefreshEnabled {
        didSet {
            AppSettingsStore.backgroundUsageRefreshEnabled = backgroundUsageRefreshEnabled
            consoleLog("Background update setting changed: \(backgroundUsageRefreshEnabled)")
            log("Background update \(backgroundUsageRefreshEnabled ? "enabled" : "disabled")")
            if backgroundUsageRefreshEnabled {
                if let connectedDevice {
                    KnownIQOSDeviceStore.save(connectedDevice)
                }
                startAutomaticUsageRefresh()
                refreshKnownDeviceUsageIfPossible()
            } else {
                stopAutomaticUsageRefresh()
            }
        }
    }

    private let client = CoreBluetoothIQOSClient()
    private var device: IQOSDevice?
    private var scanTask: Task<Void, Never>?
    private var rssiMonitorTask: Task<Void, Never>?
    private var knownDeviceRefreshTask: Task<Void, Never>?
    private var automaticUsageRefreshTask: Task<Void, Never>?
    private var pendingWidgetAction: WidgetDeviceAction?
#if canImport(UIKit)
    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
#endif

    init() {
        if backgroundUsageRefreshEnabled {
            startAutomaticUsageRefresh()
        }
    }

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
        log("Scan requested")
        rssiMonitorTask?.cancel()
        scanTask?.cancel()
        discoveredDevices = []
        isScanning = true
        statusText = String(localized: "Searching for nearby devices")

        scanTask = Task { [weak self] in
            guard let self else { return }
            for await discovered in client.scan(timeout: 8) {
                guard !Task.isCancelled else { break }
                log("Discovered \(discovered.displayName), RSSI \(discovered.rssiText)")
                upsert(discovered)
            }
            log("Scan finished with \(discoveredDevices.count) device(s)")
            isScanning = false
            if connectedDevice == nil {
                statusText = discoveredDevices.isEmpty ? String(localized: "No IQOS devices found") : String(localized: "Select a device to connect")
            } else {
                startRSSIMonitoring()
            }
        }
    }

    func connect(to discoveredDevice: IQOSDiscoveredDevice) {
        log("Connect requested for \(discoveredDevice.displayName)")
        connectingDeviceID = discoveredDevice.id
        isConnecting = true
        statusText = String(format: String(localized: "Connecting to %@"), discoveredDevice.displayName)

        Task { [weak self] in
            guard let self else { return }
            do {
                let connected = try await client.connect(to: discoveredDevice)
                let summary = connected.connectedDevice
                device = connected
                connectedDevice = summary
                connectedRSSI = discoveredDevice.rssi
                if backgroundUsageRefreshEnabled {
                    KnownIQOSDeviceStore.save(summary)
                    startAutomaticUsageRefresh()
                }
                log("Connected to \(summary.displayName), model \(summary.model.displayName)")
                statusText = String(localized: "Connected")
                try await refreshAll()
                performPendingWidgetActionIfNeeded()
                startRSSIMonitoring()
            } catch {
                log("Connect failed: \(error)")
                show(error)
                statusText = String(localized: "Connection failed")
            }
            isConnecting = false
            connectingDeviceID = nil
        }
    }

    func refreshConnectedDevice() {
        guard device != nil else { return }
        log("Refresh connected device requested")
        Task {
            do {
                try await refreshAll()
            } catch {
                log("Refresh connected device failed: \(error)")
                show(error)
            }
        }
    }

    func refreshKnownDeviceUsageIfPossible() {
        guard backgroundUsageRefreshEnabled else {
            consoleLog("Automatic usage refresh skipped: background update is disabled")
            return
        }
        guard !isConnecting, !isBusy else {
            consoleLog("Automatic usage refresh skipped: isConnecting=\(isConnecting), isBusy=\(isBusy)")
            return
        }
        consoleLog("Automatic usage refresh requested")
        log("Known device background refresh requested")

        if let device {
            knownDeviceRefreshTask?.cancel()
            knownDeviceRefreshTask = Task { [weak self] in
                guard let self else { return }
                beginBackgroundRefresh()
                defer { endBackgroundRefresh() }

                do {
                    diagnostics = try await device.readDiagnosis()
                    batteryLevel = try? await device.readBatteryLevel()
                    updateTodayUsageWidget()
                    consoleLog("Automatic usage refresh succeeded on connected device")
                    log("Known connected device usage refreshed")
                    statusText = String(localized: "Today usage updated")
                } catch {
                    consoleLog("Automatic usage refresh failed on connected device: \(error)")
                    log("Known connected device refresh failed: \(error)")
                    if connectedDevice == nil {
                        statusText = String(localized: "Search for and connect to a nearby IQOS device")
                    }
                }
            }
            return
        }

        guard let knownDevice = KnownIQOSDeviceStore.load() else {
            consoleLog("Automatic usage refresh skipped: no known device saved")
            return
        }
        consoleLog("Automatic usage refresh will reconnect known device: \(knownDevice.identifier.uuidString)")
        log("Loaded known device \(knownDevice.identifier.uuidString)")

        knownDeviceRefreshTask?.cancel()
        knownDeviceRefreshTask = Task { [weak self] in
            guard let self else { return }
            beginBackgroundRefresh()
            isConnecting = true
            statusText = String(format: String(localized: "Connecting to %@"), knownDevice.localName ?? knownDevice.identifier.uuidString)
            defer {
                isConnecting = false
                endBackgroundRefresh()
            }

            do {
                let connected = try await client.connectToKnownDevice(
                    identifier: knownDevice.identifier,
                    localName: knownDevice.localName,
                    timeout: 10
                )
                guard !Task.isCancelled else { return }

                device = connected
                connectedDevice = connected.connectedDevice
                connectedRSSI = nil
                if backgroundUsageRefreshEnabled {
                    KnownIQOSDeviceStore.save(connected.connectedDevice)
                    startAutomaticUsageRefresh()
                }

                consoleLog("Known device attached to UI: \(connected.connectedDevice.displayName)")
                log("Known device attached to UI: \(connected.connectedDevice.displayName)")
                statusText = String(localized: "Connected")
                startRSSIMonitoring()
                try await refreshAll()
                performPendingWidgetActionIfNeeded()
                consoleLog("Automatic usage refresh succeeded after reconnect")
                log("Known device reconnected and usage refreshed")
                statusText = String(localized: "Today usage updated")
            } catch {
                consoleLog("Automatic usage refresh failed after reconnect: \(error)")
                log("Known device refresh failed: \(error)")
                if connectedDevice == nil {
                    statusText = String(localized: "Search for and connect to a nearby IQOS device")
                }
            }
        }
    }

    func refreshDiagnostics() {
        guard let device else { return }
        log("Diagnostics refresh requested")
        isBusy = true
        Task {
            do {
                diagnostics = try await device.readDiagnosis()
                updateTodayUsageWidget()
                status = try? await device.readDeviceStatus()
                log("Diagnostics refreshed: total=\(diagnostics?.totalSmokingCount.map(String.init) ?? "nil"), days=\(diagnostics?.daysUsed.map(String.init) ?? "nil")")
                statusText = String(localized: "Diagnostics updated")
            } catch {
                log("Diagnostics refresh failed: \(error)")
                show(error)
            }
            isBusy = false
        }
    }

    func setBrightness(_ level: IQOSBrightnessLevel) {
        guard let device, supports(.brightness), !isBusy else { return }
        log("Set brightness requested: \(level.rawValue)")
        runCommand(String(localized: "Applying LED brightness"), successMessage: String(localized: "Brightness updated")) {
            try await device.setBrightness(level)
        }
    }

    func setFlexPuff(_ enabled: Bool) {
        guard let device, supports(.flexPuff), !isBusy else { return }
        log("Set FlexPuff requested: \(enabled)")
        runCommand(String(localized: "Updating FlexPuff"), successMessage: String(localized: "FlexPuff updated")) {
            try await device.setFlexPuffEnabled(enabled)
        }
    }

    func setFlexBatterySettings() {
        guard let device, supports(.flexBattery), !isBusy else { return }
        let settings = IQOSFlexBatterySettings(mode: flexBatteryMode, pauseMode: pauseModeEnabled)
        log("Set battery settings requested: mode=\(settings.mode.rawValue), pause=\(settings.pauseMode.map(String.init) ?? "nil")")
        runCommand(String(localized: "Updating battery mode"), successMessage: String(localized: "Battery settings updated")) {
            try await device.setFlexBatterySettings(settings)
        }
    }

    func setBatteryMode(_ mode: IQOSFlexBatteryMode) {
        guard flexBatteryMode != mode else { return }
        flexBatteryMode = mode
        setFlexBatterySettings()
    }

    func setAutoStart(_ enabled: Bool) {
        guard let device, supports(.autoStart), !isBusy else { return }
        log("Set Auto Start requested: \(enabled)")
        runCommand(String(localized: "Updating Auto Start"), successMessage: String(localized: "Auto Start updated")) {
            try await device.setAutoStartEnabled(enabled)
        }
    }

    func setSmartGesture(_ enabled: Bool) {
        guard let device, supports(.smartGesture), !isBusy else { return }
        log("Set Smart Gesture requested: \(enabled)")
        runCommand(String(localized: "Updating Smart Gesture"), successMessage: String(localized: "Smart Gesture updated")) {
            try await device.setSmartGestureEnabled(enabled)
        }
    }

    func setVibration(_ keyPath: WritableKeyPath<IQOSVibrationSettings, Bool>, enabled: Bool) {
        guard let device, supports(.vibration), !isBusy else { return }
        vibrationSettings[keyPath: keyPath] = enabled
        let settings = vibrationSettings
        log("Set vibration requested: \(settings)")
        runCommand(String(localized: "Updating vibration"), successMessage: String(localized: "Vibration updated")) {
            try await device.setVibrationSettings(settings)
        }
    }

    func setChargeStartVibration(_ enabled: Bool) {
        guard let device, supports(.chargeStartVibration), !isBusy else { return }
        vibrationSettings.whenChargingStart = enabled
        let settings = vibrationSettings
        log("Set charge start vibration requested: \(enabled)")
        runCommand(String(localized: "Updating vibration"), successMessage: String(localized: "Vibration updated")) {
            try await device.setVibrationSettings(settings)
        }
    }

    func lockDevice() {
        guard let device, supports(.deviceLock), !isBusy else { return }
        log("Lock requested")
        runCommand(String(localized: "Locking device"), successMessage: String(localized: "Device locked")) {
            try await device.lock()
        }
    }

    func unlockDevice() {
        guard let device, supports(.deviceLock), !isBusy else { return }
        log("Unlock requested")
        runCommand(String(localized: "Unlocking device"), successMessage: String(localized: "Device unlocked")) {
            try await device.unlock()
        }
    }

    func pulseFindMyIQOS() {
        guard let device, !isBusy else { return }
        log("Find requested")
        runCommand(String(localized: "Finding device"), successMessage: String(localized: "Find device command sent")) {
            try await device.startFindMyIQOS()
            try await Task.sleep(nanoseconds: 2_000_000_000)
            try await device.stopFindMyIQOS()
        }
    }

    func handleWidgetURL(_ url: URL) {
        guard url.scheme == "iqostool", url.host == "widget" else { return }
        let action: WidgetDeviceAction?
        switch url.path {
        case "/lock":
            action = .lock
        case "/unlock":
            action = .unlock
        default:
            action = nil
        }

        guard let action else { return }
        consoleLog("Widget action requested: \(url.path)")
        if device != nil {
            performWidgetAction(action)
        } else {
            pendingWidgetAction = action
            refreshKnownDeviceUsageIfPossible()
        }
    }

    private func refreshAll() async throws {
        guard let device else { return }
        log("Full refresh started")
        isBusy = true
        defer { isBusy = false }

        batteryLevel = try? await device.readBatteryLevel()
        log("Battery level: \(batteryLevel.map(String.init) ?? "nil")")
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

        if supports(.vibration) {
            vibrationSettings = (try? await device.readVibrationSettings()) ?? vibrationSettings
        }

        diagnostics = try? await device.readDiagnosis()
        updateTodayUsageWidget()
        status = try? await device.readDeviceStatus()
        log("Full refresh finished")
        statusText = String(localized: "Data updated")
    }

    private func updateTodayUsageWidget() {
        guard let totalSmokingCount = diagnostics?.totalSmokingCount else {
            consoleLog("Widget usage update skipped: diagnostics totalSmokingCount is nil")
            return
        }
        TodayUsageStore.update(totalSmokingCount: totalSmokingCount, batteryLevel: batteryLevel)
        consoleLog("Widget usage updated with total=\(totalSmokingCount)")
        log("Widget usage updated with total=\(totalSmokingCount)")
    }

    private func performPendingWidgetActionIfNeeded() {
        guard let action = pendingWidgetAction else { return }
        pendingWidgetAction = nil
        performWidgetAction(action)
    }

    private func performWidgetAction(_ action: WidgetDeviceAction) {
        switch action {
        case .lock:
            lockDevice()
        case .unlock:
            unlockDevice()
        }
    }

    private func startAutomaticUsageRefresh() {
        guard automaticUsageRefreshTask == nil else { return }
        consoleLog("Automatic usage refresh loop started")
        log("Automatic usage refresh started")

        automaticUsageRefreshTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 60_000_000_000)
                guard !Task.isCancelled else { break }
                guard backgroundUsageRefreshEnabled else { continue }
                consoleLog("Automatic usage refresh loop tick")
                refreshKnownDeviceUsageIfPossible()
            }
        }
    }

    private func stopAutomaticUsageRefresh() {
        consoleLog("Automatic usage refresh loop stopped")
        log("Automatic usage refresh stopped")
        automaticUsageRefreshTask?.cancel()
        automaticUsageRefreshTask = nil
        knownDeviceRefreshTask?.cancel()
        knownDeviceRefreshTask = nil
        endBackgroundRefresh()
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

    private func runCommand(_ workingMessage: String, successMessage: String, operation: @escaping () async throws -> Void) {
        isBusy = true
        statusText = workingMessage
        log("Command started: \(workingMessage)")
        Task {
            do {
                try await operation()
                statusText = successMessage
                log("Command succeeded: \(successMessage)")
            } catch {
                log("Command failed: \(error)")
                show(error)
            }
            isBusy = false
        }
    }

    private func show(_ error: Error) {
        log("Error shown: \(error)")
        errorMessage = String(describing: error)
        isShowingError = true
    }

    func enableDebugMode() {
        guard !debugModeEnabled else {
            log("Debug mode already enabled")
            return
        }
        debugModeEnabled = true
    }

    func clearDebugLogs() {
        debugLogs.removeAll()
        log("Debug log cleared")
    }

    func showExportError(_ error: Error) {
        show(error)
    }

    func makeDebugPackage() -> Data {
        log("Debug package export requested")
        let logText = debugLogs.isEmpty ? "No debug logs\n" : debugLogs.joined(separator: "\n") + "\n"
        let stateText = debugStateText()
        return DebugZIPBuilder.archive(files: [
            DebugZIPBuilder.FileEntry(path: "debug-log.txt", data: Data(logText.utf8)),
            DebugZIPBuilder.FileEntry(path: "app-state.txt", data: Data(stateText.utf8))
        ])
    }

    private func debugStateText() -> String {
        var lines: [String] = []
        lines.append("generatedAt: \(Self.debugDateFormatter.string(from: Date()))")
        lines.append("statusText: \(statusText)")
        lines.append("debugModeEnabled: \(debugModeEnabled)")
        lines.append("backgroundUsageRefreshEnabled: \(backgroundUsageRefreshEnabled)")
        lines.append("isScanning: \(isScanning)")
        lines.append("isConnecting: \(isConnecting)")
        lines.append("isBusy: \(isBusy)")
        lines.append("connectedDevice:")
        if let connectedDevice {
            lines.append("  name: \(connectedDevice.displayName)")
            lines.append("  id: \(connectedDevice.identifier.uuidString)")
            lines.append("  model: \(connectedDevice.model.displayName)")
        } else {
            lines.append("  nil")
        }
        if let batteryLevel {
            lines.append("batteryLevel: \(batteryLevel)")
        } else {
            lines.append("batteryLevel: nil")
        }
        if let connectedRSSI {
            lines.append("connectedRSSI: \(connectedRSSI)")
        } else {
            lines.append("connectedRSSI: nil")
        }
        if let totalSmokingCount = diagnostics?.totalSmokingCount {
            lines.append("diagnostics.totalSmokingCount: \(totalSmokingCount)")
        } else {
            lines.append("diagnostics.totalSmokingCount: nil")
        }
        if let daysUsed = diagnostics?.daysUsed {
            lines.append("diagnostics.daysUsed: \(daysUsed)")
        } else {
            lines.append("diagnostics.daysUsed: nil")
        }
        if let batteryVoltage = diagnostics?.batteryVoltage {
            lines.append("diagnostics.batteryVoltage: \(batteryVoltage)")
        } else {
            lines.append("diagnostics.batteryVoltage: nil")
        }
        lines.append("flexBatteryMode: \(flexBatteryMode.rawValue)")
        lines.append("pauseModeEnabled: \(pauseModeEnabled)")
        lines.append("autoStartEnabled: \(autoStartEnabled)")
        lines.append("smartGestureEnabled: \(smartGestureEnabled)")
        lines.append("discoveredDeviceCount: \(discoveredDevices.count)")
        lines.append("discoveredDevices:")
        for device in discoveredDevices {
            lines.append("  - \(device.displayName) \(device.id.uuidString) RSSI=\(device.rssiText)")
        }
        return lines.joined(separator: "\n") + "\n"
    }

    private func log(_ message: String) {
        guard debugModeEnabled else { return }
        let timestamp = Self.debugDateFormatter.string(from: Date())
        let line = "[\(timestamp)] \(message)"
        debugLogs.append(line)
        if debugLogs.count > 250 {
            debugLogs.removeFirst(debugLogs.count - 250)
        }
        print("[IQOS DEBUG] \(line)")
    }

    private func consoleLog(_ message: String) {
        print("[IQOS AUTO REFRESH] \(message)")
    }

    private static let debugDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()

    private func beginBackgroundRefresh() {
#if canImport(UIKit)
        guard backgroundTaskID == .invalid else { return }
        backgroundTaskID = UIApplication.shared.beginBackgroundTask(withName: "Known IQOS Usage Refresh") { [weak self] in
            guard let self else { return }
            knownDeviceRefreshTask?.cancel()
            endBackgroundRefresh()
        }
#endif
    }

    private func endBackgroundRefresh() {
#if canImport(UIKit)
        guard backgroundTaskID != .invalid else { return }
        UIApplication.shared.endBackgroundTask(backgroundTaskID)
        backgroundTaskID = .invalid
#endif
    }
}

private enum KnownIQOSDeviceStore {
    private static let identifierKey = "knownIQOSDevice.identifier"
    private static let localNameKey = "knownIQOSDevice.localName"

    static func save(_ device: IQOSConnectedDevice) {
        UserDefaults.standard.set(device.identifier.uuidString, forKey: identifierKey)
        UserDefaults.standard.set(device.localName, forKey: localNameKey)
    }

    static func load() -> (identifier: UUID, localName: String?)? {
        guard let rawIdentifier = UserDefaults.standard.string(forKey: identifierKey),
              let identifier = UUID(uuidString: rawIdentifier) else {
            return nil
        }
        return (identifier, UserDefaults.standard.string(forKey: localNameKey))
    }
}

private enum AppSettingsStore {
    private static let backgroundUsageRefreshKey = "settings.backgroundUsageRefreshEnabled"
    private static let debugModeKey = "settings.debugModeEnabled"

    static var backgroundUsageRefreshEnabled: Bool {
        get {
            UserDefaults.standard.bool(forKey: backgroundUsageRefreshKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: backgroundUsageRefreshKey)
        }
    }

    static var debugModeEnabled: Bool {
        get {
            UserDefaults.standard.bool(forKey: debugModeKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: debugModeKey)
        }
    }
}

private enum ComplianceGateStore {
    private static let statusKey = "compliance.status"

    static var status: ComplianceStatus {
        get {
            guard let rawValue = UserDefaults.standard.string(forKey: statusKey),
                  let status = ComplianceStatus(rawValue: rawValue) else {
                return .pending
            }
            return status
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: statusKey)
        }
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
