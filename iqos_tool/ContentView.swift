//
//  ContentView.swift
//  iqos_tool
//
//  Created by 陳阿頡 on 2026/5/11.
//

import Combine
import Charts
import SwiftUI
import UniformTypeIdentifiers
#if canImport(UIKit)
import UIKit
#endif

private enum AppSection: String, CaseIterable {
    case home
    case history
    case control
    case settings

    var title: LocalizedStringKey {
        switch self {
        case .home: "Home"
        case .history: "History"
        case .control: "Controls"
        case .settings: "Settings"
        }
    }

    var icon: String {
        switch self {
        case .home: "house"
        case .history: "calendar"
        case .control: "slider.horizontal.3"
        case .settings: "gearshape"
        }
    }

    var subtitle: LocalizedStringKey {
        switch self {
        case .home: "Device status, usage, scan, and diagnostics"
        case .history: "Daily records and best usage"
        case .control: "Device behavior and feedback"
        case .settings: "Automation, appearance, and debug tools"
        }
    }

    var tint: Color {
        switch self {
        case .home: .teal
        case .history: .orange
        case .control: .indigo
        case .settings: Color(.systemGray)
        }
    }
}

enum BackgroundStyle: String, CaseIterable, Identifiable {
    case automatic
    case light
    case dark

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .automatic: "Automatic"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .automatic: nil
        case .light: .light
        case .dark: .dark
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
    @State private var selectedSection: AppSection = .home
    @State private var complianceStatus = ComplianceGateStore.status

    var body: some View {
        Group {
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
        .preferredColorScheme(viewModel.backgroundStyle.colorScheme)
    }

    private var mainContent: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    AppHeaderView(
                        selectedSection: selectedSection,
                        isBusy: viewModel.isBusy,
                        isConnected: viewModel.connectedDevice != nil
                    ) {
                        viewModel.refreshConnectedDevice()
                    }
                    DeviceHeaderView(viewModel: viewModel)
                    SectionTabBar(selectedSection: $selectedSection)
                    SelectedSectionHeader(section: selectedSection)
                    switch selectedSection {
                    case .home:
                        UsageSummaryPanelView(viewModel: viewModel)
                        UsageHistoryChartPanelView(entries: viewModel.usageSnapshot.entries)
                        ScanPanelView(viewModel: viewModel)
                        DiagnosticsPanelView(viewModel: viewModel)
                    case .history:
                        UsageHistoryCalendarPanelView(entries: viewModel.usageSnapshot.historyEntries)
                    case .control:
                        ControlPanelView(viewModel: viewModel)
                    case .settings:
                        SettingsPanelView(viewModel: viewModel)
                    }
                }
                .padding(16)
            }
            .background(AppBackgroundView())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
        }
        .alert("Operation Failed", isPresented: $viewModel.isShowingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage)
        }
        .onAppear {
            viewModel.touchWidgetCommunication()
            viewModel.refreshForegroundDeviceState()
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                viewModel.touchWidgetCommunication()
                viewModel.refreshForegroundDeviceState()
            case .background:
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

private struct AppBackgroundView: View {
    var body: some View {
        Color(.systemGroupedBackground)
            .ignoresSafeArea()
    }
}

private struct AppHeaderView: View {
    let selectedSection: AppSection
    let isBusy: Bool
    let isConnected: Bool
    let refreshAction: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("IQ Tool")
                    .font(.largeTitle.weight(.bold))
                    .lineLimit(1)
                Text(selectedSection.subtitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            Button(action: refreshAction) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(selectedSection.tint.opacity(0.14))
                    if isBusy {
                        ProgressView()
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(selectedSection.tint)
                    }
                }
                .frame(width: 42, height: 42)
            }
            .buttonStyle(.plain)
            .disabled(!isConnected || isBusy)
            .accessibilityLabel(Text("Refresh"))
        }
        .padding(.top, 4)
    }
}

private struct SectionTabBar: View {
    @Binding var selectedSection: AppSection

    var body: some View {
        HStack(spacing: 6) {
            ForEach(AppSection.allCases, id: \.self) { section in
                Button {
                    selectedSection = section
                } label: {
                    VStack(spacing: 5) {
                        Image(systemName: section.icon)
                            .font(.subheadline.weight(.semibold))
                        Text(section.title)
                            .font(.caption2.weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .foregroundStyle(selectedSection == section ? section.tint : Color.secondary)
                    .background(tabBackground(for: section), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(selectedSection == section ? section.tint.opacity(0.28) : Color.clear, lineWidth: 1)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(section.title))
            }
        }
        .padding(6)
        .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color(.separator).opacity(0.22), lineWidth: 1)
        }
    }

    private func tabBackground(for section: AppSection) -> Color {
        selectedSection == section ? section.tint.opacity(0.12) : .clear
    }
}

private struct SelectedSectionHeader: View {
    let section: AppSection

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(section.tint)
                .frame(width: 4, height: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(section.title)
                    .font(.headline)
                Text(section.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.top, 2)
    }
}

private struct DeviceHeaderView: View {
    @ObservedObject var viewModel: IQOSToolViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(connectionTint.opacity(viewModel.connectedDevice == nil ? 0.10 : 0.16))
                    Image(systemName: viewModel.connectedDevice == nil ? "dot.radiowaves.left.and.right" : "checkmark.seal.fill")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(connectionTint)
                }
                .frame(width: 54, height: 54)

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

                Text(viewModel.connectedDevice == nil ? "Offline" : "Online")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(connectionTint)
                    .padding(.horizontal, 10)
                    .frame(height: 28)
                    .background(connectionTint.opacity(0.12), in: Capsule())
            }

            HStack(spacing: 10) {
                MetricTile(title: "Battery", value: viewModel.batteryText, icon: "battery.100percent", tint: .green)
                MetricTile(title: "Model", value: viewModel.connectedDevice?.model.displayName ?? "--", icon: "iphone.gen3", tint: .teal)
                MetricTile(title: "Signal", value: viewModel.connectedRSSIText, icon: "antenna.radiowaves.left.and.right", tint: .orange)
            }
        }
        .panelStyle()
    }

    private var connectionTint: Color {
        viewModel.connectedDevice == nil ? .secondary : .green
    }
}

private struct UsageSummaryPanelView: View {
    @ObservedObject var viewModel: IQOSToolViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Label("Today Usage", systemImage: "flame.fill")
                        .font(.headline)
                    Text("Current day consumption")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                comparisonBadge
            }

            HStack(alignment: .bottom, spacing: 12) {
                Text("\(viewModel.usageSnapshot.todayCount)")
                    .font(.system(size: 54, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                VStack(alignment: .leading, spacing: 7) {
                    Text("Sticks")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.secondary)
                    HStack(spacing: 6) {
                        Image(systemName: comparisonIcon)
                            .font(.caption.weight(.bold))
                        Text(viewModel.usageComparisonText)
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                    .foregroundStyle(comparisonColor)
                }
                Spacer(minLength: 0)
            }

            HStack {
                Text(String(format: String(localized: "Yesterday %d"), viewModel.usageSnapshot.yesterdayCount))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(String(format: String(localized: "Total %d sticks this week"), weekTotal))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .panelStyle()
    }

    private var comparisonBadge: some View {
        Text(viewModel.usageDifferenceSignedText)
            .font(.caption.weight(.bold))
            .monospacedDigit()
            .padding(.horizontal, 10)
            .frame(minHeight: 28)
            .foregroundStyle(comparisonColor)
            .background(comparisonColor.opacity(0.14), in: Capsule())
    }

    private var comparisonColor: Color {
        if viewModel.usageDifference > 0 { return .green }
        if viewModel.usageDifference < 0 { return .red }
        return .secondary
    }

    private var comparisonIcon: String {
        if viewModel.usageDifference > 0 { return "arrow.up.right" }
        if viewModel.usageDifference < 0 { return "arrow.down.right" }
        return "minus"
    }

    private var weekTotal: Int {
        viewModel.usageSnapshot.entries.reduce(0) { $0 + $1.count }
    }
}

private struct UsageHistoryChartPanelView: View {
    let entries: [DailyUsageEntry]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Weekly Usage Trend", systemImage: "chart.xyaxis.line")
                .font(.headline)

            Chart(entries) { entry in
                LineMark(
                    x: .value(String(localized: "Day"), entry.date, unit: .day),
                    y: .value(String(localized: "Count"), entry.count)
                )
                .foregroundStyle(.teal)
                .interpolationMethod(.catmullRom)

                PointMark(
                    x: .value(String(localized: "Day"), entry.date, unit: .day),
                    y: .value(String(localized: "Count"), entry.count)
                )
                .foregroundStyle(.teal)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { _ in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel(format: .dateTime.weekday(.narrow))
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .frame(height: 180)
        }
        .panelStyle()
    }
}

private struct UsageHistoryCalendarPanelView: View {
    let entries: [DailyUsageEntry]
    @State private var displayedMonth = Calendar.current.startOfMonth(for: Date())
    @State private var selectedDayIdentifier: String?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Usage History", systemImage: "calendar")
                    .font(.headline)
                Spacer()
                monthControls
            }

            bestRecordCard
            historySummary

            VStack(spacing: 8) {
                weekdayHeader
                LazyVGrid(columns: columns, spacing: 6) {
                    ForEach(calendarDays) { day in
                        HistoryCalendarDayCell(
                            day: day,
                            entry: day.dayIdentifier.flatMap { entriesByDay[$0] },
                            isSelected: day.dayIdentifier == selectedDayIdentifier
                        ) {
                            guard day.isInDisplayedMonth, let dayIdentifier = day.dayIdentifier else { return }
                            selectedDayIdentifier = dayIdentifier
                        }
                    }
                }
            }

            selectedDaySummary
        }
        .panelStyle()
        .onAppear {
            if selectedDayIdentifier == nil {
                selectedDayIdentifier = entries.last(where: { Calendar.current.isDate($0.date, equalTo: displayedMonth, toGranularity: .month) })?.dayIdentifier
            }
        }
    }

    private var monthControls: some View {
        HStack(spacing: 6) {
            Button {
                moveMonth(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Previous Month"))

            Text(Self.monthFormatter.string(from: displayedMonth))
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .frame(minWidth: 104)

            Button {
                moveMonth(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Next Month"))
            .disabled(!canMoveToNextMonth)
        }
    }

    private var bestRecordCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "crown.fill")
                .font(.title3)
                .foregroundStyle(.yellow)
                .frame(width: 34, height: 34)
                .background(Color.yellow.opacity(0.14), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text("Best Record")
                    .font(.subheadline.weight(.semibold))
                Text(bestRecordText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var historySummary: some View {
        HStack(spacing: 10) {
            HistorySummaryTile(title: "Month Total", value: String(format: String(localized: "%d sticks"), monthTotal), icon: "sum")
            HistorySummaryTile(title: "Active Days", value: String(format: String(localized: "%d days"), activeDayCount), icon: "calendar.badge.checkmark")
            HistorySummaryTile(title: "Daily Average", value: averageText, icon: "chart.bar")
        }
    }

    private var weekdayHeader: some View {
        LazyVGrid(columns: columns, spacing: 6) {
            ForEach(Self.weekdaySymbols, id: \.self) { weekday in
                Text(weekday)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    @ViewBuilder
    private var selectedDaySummary: some View {
        if let selectedDayIdentifier,
           let selectedDay = calendarDays.first(where: { $0.dayIdentifier == selectedDayIdentifier }),
           let date = selectedDay.date {
            let count = entriesByDay[selectedDayIdentifier]?.count ?? 0
            HStack(spacing: 12) {
                Image(systemName: count > 0 ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(count > 0 ? .teal : .secondary)
                VStack(alignment: .leading, spacing: 3) {
                    Text(String(format: String(localized: "Usage on %@"), Self.dayFormatter.string(from: date)))
                        .font(.subheadline.weight(.semibold))
                    Text(count > 0
                         ? String(format: String(localized: "%d sticks recorded"), count)
                         : String(localized: "No usage recorded for this day"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(12)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        } else {
            HStack(spacing: 12) {
                Image(systemName: "info.circle")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                Text("Tap a day with a cigarette mark to see the count.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(12)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    private var entriesByDay: [String: DailyUsageEntry] {
        Dictionary(uniqueKeysWithValues: entries.map { ($0.dayIdentifier, $0) })
    }

    private var monthEntries: [DailyUsageEntry] {
        entries.filter { Calendar.current.isDate($0.date, equalTo: displayedMonth, toGranularity: .month) }
    }

    private var monthTotal: Int {
        monthEntries.reduce(0) { $0 + $1.count }
    }

    private var activeDayCount: Int {
        monthEntries.filter { $0.count > 0 }.count
    }

    private var averageText: String {
        guard activeDayCount > 0 else { return String(format: String(localized: "%d sticks"), 0) }
        let average = Double(monthTotal) / Double(activeDayCount)
        return String(format: String(localized: "%.1f sticks"), average)
    }

    private var bestRecordText: String {
        guard let bestEntry else {
            return String(localized: "No records yet")
        }
        return String(
            format: String(localized: "%@ · %d sticks"),
            Self.dayFormatter.string(from: bestEntry.date),
            bestEntry.count
        )
    }

    private var bestEntry: DailyUsageEntry? {
        entries
            .filter { $0.count > 0 }
            .max {
                if $0.count == $1.count {
                    return $0.date < $1.date
                }
                return $0.count < $1.count
            }
    }

    private var calendarDays: [HistoryCalendarDay] {
        let calendar = Calendar.current
        let startOfMonth = calendar.startOfMonth(for: displayedMonth)
        guard let range = calendar.range(of: .day, in: .month, for: startOfMonth),
              let firstWeekday = calendar.dateComponents([.weekday], from: startOfMonth).weekday else {
            return []
        }

        let leadingBlankCount = (firstWeekday - calendar.firstWeekday + 7) % 7
        var days = (0..<leadingBlankCount).map { _ in HistoryCalendarDay(date: nil, isInDisplayedMonth: false) }
        days += range.compactMap { day -> HistoryCalendarDay? in
            guard let date = calendar.date(byAdding: .day, value: day - 1, to: startOfMonth) else { return nil }
            return HistoryCalendarDay(date: date, isInDisplayedMonth: true)
        }

        let trailingBlankCount = (7 - days.count % 7) % 7
        days += (0..<trailingBlankCount).map { _ in HistoryCalendarDay(date: nil, isInDisplayedMonth: false) }
        return days
    }

    private var canMoveToNextMonth: Bool {
        let nextMonth = Calendar.current.date(byAdding: .month, value: 1, to: displayedMonth) ?? displayedMonth
        return nextMonth <= Calendar.current.startOfMonth(for: Date())
    }

    private func moveMonth(by value: Int) {
        guard let nextMonth = Calendar.current.date(byAdding: .month, value: value, to: displayedMonth) else { return }
        displayedMonth = min(nextMonth, Calendar.current.startOfMonth(for: Date()))
        selectedDayIdentifier = entries.last(where: { Calendar.current.isDate($0.date, equalTo: displayedMonth, toGranularity: .month) })?.dayIdentifier
    }

    private static let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = DateFormatter.dateFormat(fromTemplate: "yMMMM", options: 0, locale: .current)
        return formatter
    }()

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    private static var weekdaySymbols: [String] {
        let formatter = DateFormatter()
        let symbols = formatter.shortStandaloneWeekdaySymbols ?? []
        let firstWeekdayIndex = Calendar.current.firstWeekday - 1
        return Array(symbols[firstWeekdayIndex...]) + Array(symbols[..<firstWeekdayIndex])
    }
}

private struct HistoryCalendarDay: Identifiable {
    let date: Date?
    let isInDisplayedMonth: Bool
    let id = UUID()

    var dayIdentifier: String? {
        date.map { Calendar.current.dayIdentifier(for: $0) }
    }

    var dayNumberText: String {
        guard let date else { return "" }
        return String(Calendar.current.component(.day, from: date))
    }
}

private struct HistoryCalendarDayCell: View {
    let day: HistoryCalendarDay
    let entry: DailyUsageEntry?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Text(day.dayNumberText)
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(day.isInDisplayedMonth ? Color.primary : Color.clear)
                Text(hasUsage ? "🚬" : "")
                    .font(.caption)
                    .frame(height: 14)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 46)
            .background(backgroundStyle, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(isSelected ? Color.teal : Color.clear, lineWidth: 2)
            }
        }
        .buttonStyle(.plain)
        .disabled(!day.isInDisplayedMonth)
        .accessibilityLabel(accessibilityText)
    }

    private var hasUsage: Bool {
        (entry?.count ?? 0) > 0
    }

    private var backgroundStyle: Color {
        if !day.isInDisplayedMonth { return .clear }
        return hasUsage ? Color.teal.opacity(0.14) : Color(.secondarySystemGroupedBackground)
    }

    private var accessibilityText: Text {
        guard let date = day.date else { return Text("") }
        let dateText = DateFormatter.localizedString(from: date, dateStyle: .medium, timeStyle: .none)
        if let entry, entry.count > 0 {
            return Text(String(format: String(localized: "%@, %d sticks"), dateText, entry.count))
        }
        return Text(String(format: String(localized: "%@, no usage"), dateText))
    }
}

private struct HistorySummaryTile: View {
    let title: LocalizedStringKey
    let value: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.teal)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .minimumScaleFactor(0.82)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct MetricTile: View {
    let title: LocalizedStringKey
    let value: String
    let icon: String
    var tint: Color = .teal

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 26, height: 26)
                .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
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
                .foregroundStyle(.teal)
                .background(Color.teal.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
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
                                    .frame(width: 34, height: 34)
                                    .background(Color.mint.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
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
                            .overlay {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke(Color(.separator).opacity(0.18), lineWidth: 1)
                            }
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

            ControlSectionHeader(title: "Automation", subtitle: "Connection and data refresh behavior")

            Toggle(isOn: $viewModel.backgroundUsageRefreshEnabled) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Background Update")
                        .font(.subheadline.weight(.semibold))
                    Text("Automatically refresh today usage data when iOS allows background Bluetooth")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Data Refresh Interval")
                            .font(.subheadline.weight(.semibold))
                        Text("Set how often IQ Tool reads battery, usage count, diagnostics, and status data.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(String(format: String(localized: "Every %d seconds"), viewModel.dataRefreshIntervalSeconds))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                Stepper(
                    String(format: String(localized: "Every %d seconds"), viewModel.dataRefreshIntervalSeconds),
                    value: $viewModel.dataRefreshIntervalSeconds,
                    in: IQOSToolViewModel.minimumDataRefreshIntervalSeconds...IQOSToolViewModel.maximumDataRefreshIntervalSeconds,
                    step: IQOSToolViewModel.dataRefreshIntervalStepSeconds
                )
                .labelsHidden()
            }
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            Toggle(isOn: $viewModel.autoSearchEnabled) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Auto Search")
                        .font(.subheadline.weight(.semibold))
                    Text("Automatically search for nearby devices when the app opens. If a known device is found, IQ Tool connects and refreshes its data. This may increase battery usage.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            Toggle(isOn: $viewModel.backgroundScanEnabled) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Background Scan")
                        .font(.subheadline.weight(.semibold))
                    Text("After connecting, periodically scan briefly to update signal strength. This is optional and may increase battery usage.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            ControlSectionHeader(title: "Appearance", subtitle: "Choose how IQ Tool follows the system")

            VStack(alignment: .leading, spacing: 10) {
                Text("Background Style")
                    .font(.subheadline.weight(.semibold))

                Picker("Background Style", selection: $viewModel.backgroundStyle) {
                    ForEach(BackgroundStyle.allCases) { style in
                        Text(style.title).tag(style)
                    }
                }
                .pickerStyle(.segmented)
            }
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            ControlSectionHeader(title: "Debug Tools", subtitle: "Collect logs when troubleshooting")

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
                    viewModel.copyDebugLogToPasteboard()
                } label: {
                    Image(systemName: "doc.on.doc")
                }
                .disabled(viewModel.debugLogs.isEmpty)
                .accessibilityLabel(Text("Copy Debug Log"))

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

struct DailyUsageEntry: Identifiable, Codable {
    let dayIdentifier: String
    let date: Date
    var count: Int

    var id: String { dayIdentifier }
}

struct UsageSnapshot {
    var todayCount: Int
    var yesterdayCount: Int
    var entries: [DailyUsageEntry]
    var historyEntries: [DailyUsageEntry]

    static let empty = UsageSnapshot(
        todayCount: 0,
        yesterdayCount: 0,
        entries: LocalUsageHistoryStore.weekEntries(from: []),
        historyEntries: []
    )
}

private enum LocalUsageHistoryStore {
    private struct State: Codable {
        var day: String?
        var baseline: Int?
        var lastTotal: Int?
        var entries: [DailyUsageEntry]
    }

    private static let key = "usage.history.v1"
    private static let historyRetentionDays = 365

    static func loadSnapshot(date: Date = Date()) -> UsageSnapshot {
        snapshot(from: loadState(), date: date)
    }

    static func update(totalSmokingCount: UInt16, date: Date = Date()) -> UsageSnapshot {
        var state = loadState()
        let day = dayIdentifier(for: date)
        let currentTotal = Int(totalSmokingCount)
        var baseline = state.baseline ?? currentTotal

        if state.day != day {
            baseline = state.lastTotal ?? currentTotal
            state.day = day
            state.baseline = baseline
        }

        if currentTotal < baseline {
            baseline = currentTotal
            state.baseline = baseline
        }

        let todayCount = max(currentTotal - baseline, 0)
        state.lastTotal = currentTotal
        upsert(day: day, date: startOfDay(for: date), count: todayCount, in: &state.entries)
        state.entries = prunedEntries(state.entries, date: date)
        saveState(state)
        return snapshot(from: state, date: date)
    }

    static func weekEntries(from entries: [DailyUsageEntry], date: Date = Date()) -> [DailyUsageEntry] {
        let existing = Dictionary(uniqueKeysWithValues: entries.map { ($0.dayIdentifier, $0) })
        return (0..<7).reversed().map { offset in
            let dayDate = Calendar.current.date(byAdding: .day, value: -offset, to: startOfDay(for: date)) ?? date
            let day = dayIdentifier(for: dayDate)
            return existing[day] ?? DailyUsageEntry(dayIdentifier: day, date: dayDate, count: 0)
        }
    }

    private static func snapshot(from state: State, date: Date) -> UsageSnapshot {
        let today = dayIdentifier(for: date)
        let yesterdayDate = Calendar.current.date(byAdding: .day, value: -1, to: startOfDay(for: date)) ?? date
        let yesterday = dayIdentifier(for: yesterdayDate)
        let entries = weekEntries(from: state.entries, date: date)
        return UsageSnapshot(
            todayCount: entries.first(where: { $0.dayIdentifier == today })?.count ?? 0,
            yesterdayCount: entries.first(where: { $0.dayIdentifier == yesterday })?.count ?? 0,
            entries: entries,
            historyEntries: state.entries
        )
    }

    private static func loadState() -> State {
        guard let data = UserDefaults.standard.data(forKey: key),
              let state = try? JSONDecoder().decode(State.self, from: data) else {
            return State(day: nil, baseline: nil, lastTotal: nil, entries: [])
        }
        return state
    }

    private static func saveState(_ state: State) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    private static func upsert(day: String, date: Date, count: Int, in entries: inout [DailyUsageEntry]) {
        if let index = entries.firstIndex(where: { $0.dayIdentifier == day }) {
            entries[index].count = count
        } else {
            entries.append(DailyUsageEntry(dayIdentifier: day, date: date, count: count))
        }
    }

    private static func prunedEntries(_ entries: [DailyUsageEntry], date: Date) -> [DailyUsageEntry] {
        let minimumDate = Calendar.current.date(byAdding: .day, value: -historyRetentionDays, to: startOfDay(for: date)) ?? date
        return entries
            .filter { $0.date >= minimumDate }
            .sorted { $0.date < $1.date }
    }

    private static func startOfDay(for date: Date) -> Date {
        Calendar.current.startOfDay(for: date)
    }

    private static func dayIdentifier(for date: Date) -> String {
        let components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return "\(components.year ?? 0)-\(components.month ?? 0)-\(components.day ?? 0)"
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
    @Published var usageSnapshot = UsageSnapshot.empty
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
    @Published var autoSearchEnabled = AppSettingsStore.autoSearchEnabled {
        didSet {
            AppSettingsStore.autoSearchEnabled = autoSearchEnabled
            log("Auto search \(autoSearchEnabled ? "enabled" : "disabled")")
            if autoSearchEnabled {
                startAutoSearchIfNeeded()
            }
        }
    }
    @Published var backgroundScanEnabled = AppSettingsStore.backgroundScanEnabled {
        didSet {
            AppSettingsStore.backgroundScanEnabled = backgroundScanEnabled
            log("Background scan \(backgroundScanEnabled ? "enabled" : "disabled")")
            if backgroundScanEnabled {
                startRSSIMonitoring()
            } else {
                rssiMonitorTask?.cancel()
                rssiMonitorTask = nil
            }
        }
    }
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
    @Published var dataRefreshIntervalSeconds = AppSettingsStore.dataRefreshIntervalSeconds {
        didSet {
            let clampedIntervalSeconds = Self.clampedDataRefreshInterval(dataRefreshIntervalSeconds)
            AppSettingsStore.dataRefreshIntervalSeconds = clampedIntervalSeconds
            log("Data refresh interval changed: \(clampedIntervalSeconds) seconds")
            if backgroundUsageRefreshEnabled {
                restartAutomaticUsageRefresh()
            }
        }
    }
    @Published var backgroundStyle = AppSettingsStore.backgroundStyle {
        didSet {
            AppSettingsStore.backgroundStyle = backgroundStyle
        }
    }

    private let client = CoreBluetoothIQOSClient()
    private var device: IQOSDevice?
    private var scanTask: Task<Void, Never>?
    private var rssiMonitorTask: Task<Void, Never>?
    private var foregroundRefreshTask: Task<Void, Never>?
    private var knownDeviceRefreshTask: Task<Void, Never>?
    private var automaticUsageRefreshTask: Task<Void, Never>?
    private var pendingWidgetAction: WidgetDeviceAction?
    private var isUsageRefreshInProgress = false
    private var lastUsageRefreshAttemptDate: Date?
    private var lastUsageRefreshFailureDate: Date?
#if canImport(UIKit)
    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
#endif

    init() {
        dataRefreshIntervalSeconds = Self.clampedDataRefreshInterval(dataRefreshIntervalSeconds)
        AppSettingsStore.dataRefreshIntervalSeconds = dataRefreshIntervalSeconds
        usageSnapshot = LocalUsageHistoryStore.loadSnapshot()
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

    var usageDifference: Int {
        usageSnapshot.todayCount - usageSnapshot.yesterdayCount
    }

    var usageDifferenceSignedText: String {
        if usageDifference > 0 { return "+\(usageDifference)" }
        return String(usageDifference)
    }

    var usageComparisonText: String {
        if usageDifference > 0 {
            return String(format: String(localized: "Today +%d compared with yesterday"), usageDifference)
        }
        if usageDifference < 0 {
            return String(format: String(localized: "Today %d compared with yesterday"), usageDifference)
        }
        return String(localized: "Today matches yesterday")
    }

    func supports(_ capability: IQOSDeviceCapability) -> Bool {
        connectedDevice?.model.supports(capability) ?? false
    }

    func startAutoSearchIfNeeded() {
        guard autoSearchEnabled else { return }
        guard connectedDevice == nil, !isScanning, !isConnecting, !isBusy, !isUsageRefreshInProgress else { return }
        log("Auto search requested")
        startScan()
    }

    func refreshForegroundDeviceState() {
        guard foregroundRefreshTask == nil else {
            log("Foreground refresh skipped: already running")
            return
        }
        guard !isScanning, !isConnecting, !isBusy, !isUsageRefreshInProgress else {
            log("Foreground refresh skipped: isScanning=\(isScanning), isConnecting=\(isConnecting), isBusy=\(isBusy), isUsageRefreshInProgress=\(isUsageRefreshInProgress)")
            return
        }

        foregroundRefreshTask = Task { [weak self] in
            guard let self else { return }
            defer { foregroundRefreshTask = nil }

            if device != nil {
                log("Foreground full refresh requested")
                do {
                    try await refreshAll()
                    return
                } catch {
                    log("Foreground full refresh failed: \(error)")
                    markKnownDeviceDisconnected()
                }
            }

            guard let knownDevice = KnownIQOSDeviceStore.load() else {
                log("Foreground known device reconnect skipped: no known device saved")
                return
            }

            log("Foreground known device reconnect requested")
            do {
                try await reconnectKnownDeviceAndRefresh(knownDevice)
                lastUsageRefreshFailureDate = nil
            } catch {
                lastUsageRefreshFailureDate = Date()
                log("Foreground known device reconnect failed: \(error)")
                statusText = String(localized: "Search for and connect to a nearby IQOS device")
            }
        }
    }

    func startScan() {
        guard !isScanning, !isConnecting else { return }
        log("Scan requested")
        rssiMonitorTask?.cancel()
        scanTask?.cancel()
        discoveredDevices = []
        isScanning = true
        statusText = String(localized: "Searching for nearby devices")

        scanTask = Task { [weak self] in
            guard let self else { return }
            defer {
                isScanning = false
                if connectedDevice == nil {
                    if !isConnecting {
                        statusText = discoveredDevices.isEmpty ? String(localized: "No IQOS devices found") : String(localized: "Select a device to connect")
                    }
                } else {
                    startRSSIMonitoring()
                }
            }

            for await discovered in client.scan(timeout: 8) {
                guard !Task.isCancelled else { break }
                log("Discovered \(discovered.displayName), RSSI \(discovered.rssiText)")
                upsert(discovered)
                if shouldAutoConnect(to: discovered) {
                    log("Known device discovered; auto-connect started")
                    client.stopScan()
                    connect(to: discovered)
                    break
                }
            }
            log("Scan finished with \(discoveredDevices.count) device(s)")
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
                KnownIQOSDeviceStore.save(summary)
                if backgroundUsageRefreshEnabled {
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
        guard !isUsageRefreshInProgress else {
            log("Refresh connected device skipped: background usage refresh is running")
            return
        }
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
        guard !isScanning, !isConnecting, !isBusy else {
            consoleLog("Automatic usage refresh skipped: isScanning=\(isScanning), isConnecting=\(isConnecting), isBusy=\(isBusy)")
            return
        }
        guard !isUsageRefreshInProgress else {
            consoleLog("Automatic usage refresh skipped: refresh already in progress")
            log("Known device background refresh skipped: refresh already in progress")
            return
        }
        if let lastUsageRefreshFailureDate,
           Date().timeIntervalSince(lastUsageRefreshFailureDate) < Self.usageRefreshFailureBackoff {
            consoleLog("Automatic usage refresh skipped: recent failure backoff is active")
            log("Known device background refresh skipped: recent failure backoff is active")
            return
        }
        if let lastUsageRefreshAttemptDate,
           Date().timeIntervalSince(lastUsageRefreshAttemptDate) < TimeInterval(dataRefreshIntervalSeconds) {
            consoleLog("Automatic usage refresh skipped: refresh cooldown is active")
            log("Known device background refresh skipped: refresh cooldown is active")
            return
        }
        lastUsageRefreshAttemptDate = Date()
        consoleLog("Automatic usage refresh requested")
        log("Known device background refresh requested")

        if let device {
            isUsageRefreshInProgress = true
            knownDeviceRefreshTask = Task { [weak self] in
                guard let self else { return }
                beginBackgroundRefresh()
                defer {
                    isUsageRefreshInProgress = false
                    endBackgroundRefresh()
                }

                do {
                    diagnostics = try await device.readDiagnosis()
                    batteryLevel = try? await device.readBatteryLevel()
                    updateTodayUsageWidget()
                    lastUsageRefreshFailureDate = nil
                    consoleLog("Automatic usage refresh succeeded on connected device")
                    log("Known connected device usage refreshed")
                    statusText = String(localized: "Today usage updated")
                } catch {
                    consoleLog("Automatic usage refresh failed on connected device: \(error)")
                    log("Known connected device refresh failed: \(error)")
                    markKnownDeviceDisconnected()

                    if let knownDevice = KnownIQOSDeviceStore.load() {
                        do {
                            try await reconnectKnownDeviceAndRefresh(knownDevice)
                            lastUsageRefreshFailureDate = nil
                            consoleLog("Automatic usage refresh succeeded after reconnect")
                            log("Known device reconnected and usage refreshed")
                            statusText = String(localized: "Today usage updated")
                        } catch {
                            lastUsageRefreshFailureDate = Date()
                            consoleLog("Automatic usage refresh failed after connected-device recovery: \(error)")
                            log("Known device recovery refresh failed: \(error)")
                            statusText = String(localized: "Search for and connect to a nearby IQOS device")
                        }
                    } else {
                        lastUsageRefreshFailureDate = Date()
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
        isUsageRefreshInProgress = true
        consoleLog("Automatic usage refresh will reconnect known device: \(knownDevice.identifier.uuidString)")
        log("Loaded known device \(knownDevice.identifier.uuidString)")

        knownDeviceRefreshTask = Task { [weak self] in
            guard let self else { return }
            beginBackgroundRefresh()
            defer {
                isUsageRefreshInProgress = false
                endBackgroundRefresh()
            }

            do {
                try await reconnectKnownDeviceAndRefresh(knownDevice)
                lastUsageRefreshFailureDate = nil
                consoleLog("Automatic usage refresh succeeded after reconnect")
                log("Known device reconnected and usage refreshed")
                statusText = String(localized: "Today usage updated")
            } catch {
                lastUsageRefreshFailureDate = Date()
                consoleLog("Automatic usage refresh failed after reconnect: \(error)")
                log("Known device refresh failed: \(error)")
                statusText = connectedDevice == nil
                    ? String(localized: "Search for and connect to a nearby IQOS device")
                    : String(localized: "Background update failed")
            }
        }
    }

    private func reconnectKnownDeviceAndRefresh(_ knownDevice: (identifier: UUID, localName: String?)) async throws {
        isConnecting = true
        statusText = String(format: String(localized: "Connecting to %@"), knownDevice.localName ?? knownDevice.identifier.uuidString)
        defer { isConnecting = false }

        let connected = try await client.connectToKnownDevice(
            identifier: knownDevice.identifier,
            localName: knownDevice.localName,
            timeout: 10
        )
        guard !Task.isCancelled else { return }

        device = connected
        connectedDevice = connected.connectedDevice
        connectedRSSI = nil
        KnownIQOSDeviceStore.save(connected.connectedDevice)
        if backgroundUsageRefreshEnabled {
            startAutomaticUsageRefresh()
        }

        consoleLog("Known device attached to UI: \(connected.connectedDevice.displayName)")
        log("Known device attached to UI: \(connected.connectedDevice.displayName)")
        statusText = String(localized: "Connected")
        startRSSIMonitoring()
        try await refreshAll()
        performPendingWidgetActionIfNeeded()
    }

    private func markKnownDeviceDisconnected() {
        rssiMonitorTask?.cancel()
        rssiMonitorTask = nil
        device = nil
        connectedDevice = nil
        connectedRSSI = nil
    }

    private func shouldAutoConnect(to discovered: IQOSDiscoveredDevice) -> Bool {
        guard connectedDevice == nil, !isConnecting, !isBusy else { return false }
        guard let knownDevice = KnownIQOSDeviceStore.load() else { return false }
        return isKnownDevice(discovered, matching: knownDevice)
    }

    private func isKnownDevice(
        _ discovered: IQOSDiscoveredDevice,
        matching knownDevice: (identifier: UUID, localName: String?)
    ) -> Bool {
        if discovered.id == knownDevice.identifier {
            return true
        }

        guard let discoveredName = normalizedDeviceName(discovered.name),
              let knownName = normalizedDeviceName(knownDevice.localName) else {
            return false
        }
        return discoveredName == knownName
    }

    private func normalizedDeviceName(_ name: String?) -> String? {
        let normalized = name?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        return normalized.isEmpty ? nil : normalized
    }

    func refreshDiagnostics() {
        guard let device else { return }
        guard !isUsageRefreshInProgress else {
            log("Diagnostics refresh skipped: background usage refresh is running")
            return
        }
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
        // Widget actions are disabled for this release because the widget target
        // is not embedded in the app. Keep the URL handler in place so it can be
        // restored with the widget without changing the public URL scheme.
        guard TodayUsageStore.isWidgetSupportEnabled else { return }
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
        statusText = dataUpdatedStatusText()
    }

    private func updateTodayUsageWidget() {
        guard let totalSmokingCount = diagnostics?.totalSmokingCount else {
            consoleLog("Usage update skipped: diagnostics totalSmokingCount is nil")
            if TodayUsageStore.isWidgetSupportEnabled && !TodayUsageStore.touch(batteryLevel: batteryLevel) {
                consoleLog("Widget usage heartbeat failed: App Group container unavailable")
            }
            return
        }
        usageSnapshot = LocalUsageHistoryStore.update(totalSmokingCount: totalSmokingCount)
        // Widget support is disabled for this release; local history remains active.
        guard TodayUsageStore.isWidgetSupportEnabled else { return }
        if TodayUsageStore.update(totalSmokingCount: totalSmokingCount, batteryLevel: batteryLevel) {
            consoleLog("Widget usage updated with total=\(totalSmokingCount)")
            log("Widget usage updated with total=\(totalSmokingCount)")
        } else {
            consoleLog("Widget usage update failed: App Group container unavailable")
            log("Widget usage update failed: App Group container unavailable")
        }
    }

    private func dataUpdatedStatusText(date: Date = Date()) -> String {
        String(format: String(localized: "Data updated at %@"), Self.statusTimeFormatter.string(from: date))
    }

    func touchWidgetCommunication() {
        // Widget support is disabled for this release; leave this no-op for the
        // existing foreground/background refresh call sites.
        guard TodayUsageStore.isWidgetSupportEnabled else { return }
        if TodayUsageStore.touch(batteryLevel: batteryLevel) {
            consoleLog("Widget communication heartbeat written")
            log("Widget communication heartbeat written")
        } else {
            consoleLog("Widget communication heartbeat failed: App Group container unavailable")
            log("Widget communication heartbeat failed: App Group container unavailable")
        }
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
                try? await Task.sleep(nanoseconds: UInt64(TimeInterval(dataRefreshIntervalSeconds) * 1_000_000_000))
                guard !Task.isCancelled else { break }
                guard backgroundUsageRefreshEnabled else { continue }
                consoleLog("Automatic usage refresh loop tick")
                refreshKnownDeviceUsageIfPossible()
            }
        }
    }

    private func restartAutomaticUsageRefresh() {
        automaticUsageRefreshTask?.cancel()
        automaticUsageRefreshTask = nil
        startAutomaticUsageRefresh()
    }

    private func stopAutomaticUsageRefresh() {
        consoleLog("Automatic usage refresh loop stopped")
        log("Automatic usage refresh stopped")
        automaticUsageRefreshTask?.cancel()
        automaticUsageRefreshTask = nil
        knownDeviceRefreshTask?.cancel()
        knownDeviceRefreshTask = nil
        isUsageRefreshInProgress = false
        endBackgroundRefresh()
    }

    private func startRSSIMonitoring() {
        rssiMonitorTask?.cancel()
        rssiMonitorTask = nil
        guard backgroundScanEnabled, let connectedID = connectedDevice?.identifier else { return }

        rssiMonitorTask = Task { [weak self] in
            guard let self else { return }

            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 10_000_000_000)
                guard !Task.isCancelled,
                      !isScanning,
                      !isConnecting,
                      !isBusy,
                      !isUsageRefreshInProgress else { continue }

                for await discovered in client.scan(timeout: 2) {
                    guard !Task.isCancelled else { break }
                    if discovered.id == connectedID {
                        upsert(discovered)
                        break
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
        guard !isUsageRefreshInProgress else {
            log("Command skipped: background usage refresh is running")
            return
        }
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

    func copyDebugLogToPasteboard() {
        guard !debugLogs.isEmpty else { return }
#if canImport(UIKit)
        UIPasteboard.general.string = debugLogs.joined(separator: "\n")
        log("Debug log copied")
#endif
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
        lines.append("autoSearchEnabled: \(autoSearchEnabled)")
        lines.append("backgroundScanEnabled: \(backgroundScanEnabled)")
        lines.append("backgroundUsageRefreshEnabled: \(backgroundUsageRefreshEnabled)")
        lines.append("dataRefreshIntervalSeconds: \(dataRefreshIntervalSeconds)")
        lines.append("widgetAppGroupCandidates:")
        lines.append(TodayUsageStore.diagnosticSummary)
        lines.append("isUsageRefreshInProgress: \(isUsageRefreshInProgress)")
        lines.append("lastUsageRefreshAttemptAt: \(lastUsageRefreshAttemptDate.map(Self.debugDateFormatter.string(from:)) ?? "nil")")
        lines.append("lastUsageRefreshFailureAt: \(lastUsageRefreshFailureDate.map(Self.debugDateFormatter.string(from:)) ?? "nil")")
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

    static let minimumDataRefreshIntervalSeconds = 60
    static let maximumDataRefreshIntervalSeconds = 3_600
    static let dataRefreshIntervalStepSeconds = 30
    private static let usageRefreshFailureBackoff: TimeInterval = 3 * 60
    private static let statusTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()

    private static func clampedDataRefreshInterval(_ value: Int) -> Int {
        min(max(value, minimumDataRefreshIntervalSeconds), maximumDataRefreshIntervalSeconds)
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
    private static let autoSearchKey = "settings.autoSearchEnabled"
    private static let backgroundScanKey = "settings.backgroundScanEnabled"
    private static let backgroundUsageRefreshKey = "settings.backgroundUsageRefreshEnabled"
    private static let dataRefreshIntervalKey = "settings.dataRefreshIntervalSeconds"
    private static let backgroundStyleKey = "settings.backgroundStyle"
    private static let debugModeKey = "settings.debugModeEnabled"
    private static let defaultDataRefreshIntervalSeconds = 300

    static var autoSearchEnabled: Bool {
        get {
            UserDefaults.standard.bool(forKey: autoSearchKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: autoSearchKey)
        }
    }

    static var backgroundScanEnabled: Bool {
        get {
            UserDefaults.standard.bool(forKey: backgroundScanKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: backgroundScanKey)
        }
    }

    static var backgroundUsageRefreshEnabled: Bool {
        get {
            UserDefaults.standard.bool(forKey: backgroundUsageRefreshKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: backgroundUsageRefreshKey)
        }
    }

    static var dataRefreshIntervalSeconds: Int {
        get {
            let value = UserDefaults.standard.integer(forKey: dataRefreshIntervalKey)
            return value == 0 ? defaultDataRefreshIntervalSeconds : value
        }
        set {
            UserDefaults.standard.set(newValue, forKey: dataRefreshIntervalKey)
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

    static var backgroundStyle: BackgroundStyle {
        get {
            guard let rawValue = UserDefaults.standard.string(forKey: backgroundStyleKey),
                  let style = BackgroundStyle(rawValue: rawValue) else {
                return .automatic
            }
            return style
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: backgroundStyleKey)
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
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color(.separator).opacity(0.18), lineWidth: 1)
            }
            .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 4)
    }
}

private extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        let components = dateComponents([.year, .month], from: date)
        return self.date(from: components) ?? startOfDay(for: date)
    }

    func dayIdentifier(for date: Date) -> String {
        let components = dateComponents([.year, .month, .day], from: date)
        return "\(components.year ?? 0)-\(components.month ?? 0)-\(components.day ?? 0)"
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
