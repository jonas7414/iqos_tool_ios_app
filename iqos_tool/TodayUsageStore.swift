import Foundation
import WidgetKit

enum TodayUsageStore {
    static let appGroupIdentifier = "group.iqos-tool.iqos-tool"
    static let widgetKind = "iqos_today_usage_widget"
    private static let controlWidgetKind = "iqos_control_widget"

    private static let fileName = "today-usage.json"

    private struct UsageRecord: Codable {
        var day: String?
        var baseline: Int?
        var lastTotal: Int?
        var todayCount: Int
        var batteryLevel: UInt8?
        var lastUpdated: TimeInterval?

        static let empty = UsageRecord(
            day: nil,
            baseline: nil,
            lastTotal: nil,
            todayCount: 0,
            batteryLevel: nil,
            lastUpdated: nil
        )
    }

    static func update(totalSmokingCount: UInt16, batteryLevel: UInt8?, date: Date = Date()) {
        var record = loadRecord()
        let day = dayIdentifier(for: date)
        let currentTotal = Int(totalSmokingCount)
        var baseline = record.baseline ?? currentTotal

        if record.day != day {
            baseline = record.lastTotal ?? currentTotal
            record.day = day
            record.baseline = baseline
        }

        if currentTotal < baseline {
            baseline = currentTotal
            record.baseline = baseline
        }

        record.lastTotal = currentTotal
        record.todayCount = max(currentTotal - baseline, 0)
        record.batteryLevel = batteryLevel
        record.lastUpdated = date.timeIntervalSince1970
        saveRecord(record)
        WidgetCenter.shared.reloadTimelines(ofKind: widgetKind)
        WidgetCenter.shared.reloadTimelines(ofKind: controlWidgetKind)
    }

    static func touch(batteryLevel: UInt8? = nil, date: Date = Date()) {
        var record = loadRecord()
        if let batteryLevel {
            record.batteryLevel = batteryLevel
        }
        record.lastUpdated = date.timeIntervalSince1970
        saveRecord(record)
        WidgetCenter.shared.reloadTimelines(ofKind: widgetKind)
        WidgetCenter.shared.reloadTimelines(ofKind: controlWidgetKind)
    }

    static var diagnosticSummary: String {
        candidateAppGroupIdentifiers.map { identifier in
            let available = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier) != nil
            return "\(identifier): \(available ? "available" : "unavailable")"
        }
        .joined(separator: "\n")
    }

    private static func loadRecord() -> UsageRecord {
        guard let fileURL else { return .empty }
        do {
            let data = try Data(contentsOf: fileURL)
            return try JSONDecoder().decode(UsageRecord.self, from: data)
        } catch {
            return .empty
        }
    }

    private static func saveRecord(_ record: UsageRecord) {
        guard let fileURL else {
            print("[IQOS AUTO REFRESH] Widget usage file write skipped: App Group container unavailable. Tried: \(candidateAppGroupIdentifiers)")
            return
        }
        do {
            let data = try JSONEncoder().encode(record)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            print("[IQOS AUTO REFRESH] Widget usage file write failed: \(error)")
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
            if bundleIdentifier.hasSuffix(".widget") {
                identifiers.append("group.\(String(bundleIdentifier.dropLast(".widget".count)))")
            }
            identifiers.append("group.\(bundleIdentifier)")
        }
        return Array(NSOrderedSet(array: identifiers)) as? [String] ?? identifiers
    }

    private static func dayIdentifier(for date: Date) -> String {
        let components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return "\(components.year ?? 0)-\(components.month ?? 0)-\(components.day ?? 0)"
    }
}
