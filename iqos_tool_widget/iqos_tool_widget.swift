import Foundation
import SwiftUI
import WidgetKit

private enum WidgetUsageStore {
    static let appGroupIdentifier = "group.iqos-tool.iqos-tool"
    static let widgetKind = "iqos_today_usage_widget"
    static let controlWidgetKind = "iqos_control_widget"

    private static let fileName = "today-usage.json"

    private struct UsageRecord: Codable {
        let todayCount: Int
        let batteryLevel: UInt8?
        let lastUpdated: TimeInterval?
    }

    static func snapshot() -> TodayUsageEntry {
        guard let fileURL else {
            return TodayUsageEntry(date: Date(), count: 0, batteryLevel: nil, updatedAt: nil)
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let record = try JSONDecoder().decode(UsageRecord.self, from: data)
            let updatedAt = record.lastUpdated.map(Date.init(timeIntervalSince1970:)) ?? fileModificationDate(fileURL)
            return TodayUsageEntry(date: Date(), count: record.todayCount, batteryLevel: record.batteryLevel, updatedAt: updatedAt)
        } catch {
            return TodayUsageEntry(date: Date(), count: 0, batteryLevel: nil, updatedAt: nil)
        }
    }

    private static var fileURL: URL? {
        for identifier in candidateAppGroupIdentifiers {
            if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier) {
                return containerURL.appendingPathComponent(fileName, isDirectory: false)
            }
        }
        return nil
    }

    private static var candidateAppGroupIdentifiers: [String] {
        var identifiers = [appGroupIdentifier]
        if let bundleIdentifier = Bundle.main.bundleIdentifier {
            identifiers.append("group.\(bundleIdentifier)")
            if bundleIdentifier.hasSuffix(".widget") {
                identifiers.append("group.\(String(bundleIdentifier.dropLast(".widget".count)))")
            }
        }
        return Array(NSOrderedSet(array: identifiers)) as? [String] ?? identifiers
    }

    private static func fileModificationDate(_ fileURL: URL) -> Date? {
        try? FileManager.default
            .attributesOfItem(atPath: fileURL.path)[.modificationDate] as? Date
    }
}

struct TodayUsageEntry: TimelineEntry {
    let date: Date
    let count: Int
    let batteryLevel: UInt8?
    let updatedAt: Date?
}

struct TodayUsageProvider: TimelineProvider {
    func placeholder(in context: Context) -> TodayUsageEntry {
        TodayUsageEntry(date: Date(), count: 0, batteryLevel: nil, updatedAt: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (TodayUsageEntry) -> Void) {
        completion(WidgetUsageStore.snapshot())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TodayUsageEntry>) -> Void) {
        let entry = WidgetUsageStore.snapshot()
        let nextRefresh = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date().addingTimeInterval(1800)
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }
}

struct TodayUsageWidgetView: View {
    var entry: TodayUsageEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "flame")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange)
                Text("Today")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            Text("\(entry.count)")
                .font(.system(size: 52, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.7)
                .lineLimit(1)

            Text(entry.count == 1 ? String(localized: "stick") : String(localized: "sticks"))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)

            Spacer(minLength: 0)

            Text(updatedText)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .containerBackground(.background, for: .widget)
    }

    private var updatedText: String {
        guard let updatedAt = entry.updatedAt else {
            return String(localized: "Open app to update")
        }
        return String(format: String(localized: "Updated %@"), updatedAt.formatted(date: .omitted, time: .shortened))
    }

    private var batteryText: String {
        entry.batteryLevel.map { "\($0)%" } ?? "--"
    }
}

struct DeviceControlWidgetView: View {
    var entry: TodayUsageEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "battery.75percent")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.green)
                Text("Battery")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            Text(batteryText)
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.75)
                .lineLimit(1)

            Spacer(minLength: 0)

            HStack(spacing: 8) {
                Link(destination: URL(string: "iqostool://widget/lock")!) {
                    Label("Lock", systemImage: "lock.fill")
                        .labelStyle(.iconOnly)
                        .frame(maxWidth: .infinity, minHeight: 32)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .accessibilityLabel(Text("Lock"))

                Link(destination: URL(string: "iqostool://widget/unlock")!) {
                    Label("Unlock", systemImage: "lock.open.fill")
                        .labelStyle(.iconOnly)
                        .frame(maxWidth: .infinity, minHeight: 32)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .accessibilityLabel(Text("Unlock"))
            }

            Text(updatedText)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .containerBackground(.background, for: .widget)
    }

    private var batteryText: String {
        entry.batteryLevel.map { "\($0)%" } ?? "--"
    }

    private var updatedText: String {
        guard let updatedAt = entry.updatedAt else {
            return String(localized: "Open app to update")
        }
        return String(format: String(localized: "Updated %@"), updatedAt.formatted(date: .omitted, time: .shortened))
    }
}

struct IQOSTodayUsageWidget: Widget {
    let kind = WidgetUsageStore.widgetKind

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TodayUsageProvider()) { entry in
            TodayUsageWidgetView(entry: entry)
        }
        .configurationDisplayName(Text("IQ Tool Today"))
        .description(Text("Shows today's IQOS usage from the latest app sync."))
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct IQOSDeviceControlWidget: Widget {
    let kind = WidgetUsageStore.controlWidgetKind

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TodayUsageProvider()) { entry in
            DeviceControlWidgetView(entry: entry)
        }
        .configurationDisplayName(Text("IQ Tool Controls"))
        .description(Text("Shows battery level and quick lock controls."))
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct IQOSTodayUsageWidgetBundle: WidgetBundle {
    var body: some Widget {
        IQOSTodayUsageWidget()
        IQOSDeviceControlWidget()
    }
}
