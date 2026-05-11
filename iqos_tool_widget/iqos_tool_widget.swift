import SwiftUI
import WidgetKit

private enum WidgetUsageStore {
    static let appGroupIdentifier = "group.iqos-tool.iqos-tool"
    static let widgetKind = "iqos_today_usage_widget"

    private static let todayCountKey = "todayUsage.count"
    private static let lastUpdatedKey = "todayUsage.lastUpdated"

    static func snapshot() -> TodayUsageEntry {
        let defaults: UserDefaults
        if FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) != nil {
            defaults = UserDefaults(suiteName: appGroupIdentifier) ?? .standard
        } else {
            defaults = .standard
        }

        let count = defaults.object(forKey: todayCountKey) as? Int ?? 0
        let updatedTimestamp = defaults.object(forKey: lastUpdatedKey) as? TimeInterval
        let updatedAt = updatedTimestamp.map(Date.init(timeIntervalSince1970:))
        return TodayUsageEntry(date: Date(), count: count, updatedAt: updatedAt)
    }
}

struct TodayUsageEntry: TimelineEntry {
    let date: Date
    let count: Int
    let updatedAt: Date?
}

struct TodayUsageProvider: TimelineProvider {
    func placeholder(in context: Context) -> TodayUsageEntry {
        TodayUsageEntry(date: Date(), count: 0, updatedAt: nil)
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
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "flame")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange)
                Text("Today")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            Text("\(entry.count)")
                .font(.system(size: 44, weight: .bold, design: .rounded))
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
}

struct IQOSTodayUsageWidget: Widget {
    let kind = WidgetUsageStore.widgetKind

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TodayUsageProvider()) { entry in
            TodayUsageWidgetView(entry: entry)
        }
        .configurationDisplayName(Text("IQOS Today"))
        .description(Text("Shows today's IQOS usage from the latest app sync."))
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct IQOSTodayUsageWidgetBundle: WidgetBundle {
    var body: some Widget {
        IQOSTodayUsageWidget()
    }
}
