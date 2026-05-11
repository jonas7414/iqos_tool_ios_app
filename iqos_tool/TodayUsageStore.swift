import Foundation
import WidgetKit

enum TodayUsageStore {
    static let appGroupIdentifier = "group.iqos-tool.iqos-tool"
    static let widgetKind = "iqos_today_usage_widget"

    private static let dayKey = "todayUsage.day"
    private static let baselineKey = "todayUsage.baseline"
    private static let lastTotalKey = "todayUsage.lastTotal"
    private static let todayCountKey = "todayUsage.count"
    private static let lastUpdatedKey = "todayUsage.lastUpdated"

    static var defaults: UserDefaults {
        guard FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) != nil else {
            return .standard
        }
        return UserDefaults(suiteName: appGroupIdentifier) ?? .standard
    }

    static func update(totalSmokingCount: UInt16, date: Date = Date()) {
        let defaults = defaults
        let day = dayIdentifier(for: date)
        let currentTotal = Int(totalSmokingCount)
        let storedDay = defaults.string(forKey: dayKey)
        var baseline = defaults.object(forKey: baselineKey) as? Int ?? currentTotal

        if storedDay != day {
            let previousTotal = defaults.object(forKey: lastTotalKey) as? Int
            baseline = previousTotal ?? currentTotal
            defaults.set(day, forKey: dayKey)
            defaults.set(baseline, forKey: baselineKey)
        }

        if currentTotal < baseline {
            baseline = currentTotal
            defaults.set(baseline, forKey: baselineKey)
        }

        defaults.set(currentTotal, forKey: lastTotalKey)
        defaults.set(max(currentTotal - baseline, 0), forKey: todayCountKey)
        defaults.set(date.timeIntervalSince1970, forKey: lastUpdatedKey)
        WidgetCenter.shared.reloadTimelines(ofKind: widgetKind)
    }

    private static func dayIdentifier(for date: Date) -> String {
        let components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return "\(components.year ?? 0)-\(components.month ?? 0)-\(components.day ?? 0)"
    }
}
