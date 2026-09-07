import Foundation

public struct MetricPoint: Codable, Identifiable, Sendable {
    public var id: Date { date }
    public let date: Date
    public let value: Double
    public init(date: Date, value: Double) { self.date = date; self.value = value }
}
public struct TrendSummary: Sendable {
    public let points: [MetricPoint]
    public let firstMean: Double?
    public let recentMean: Double?
    public let firstDays: Int
    public let recentDays: Int
    public var absoluteChange: Double? {
        guard let firstMean, let recentMean, firstDays >= 3, recentDays >= 3 else { return nil }
        return recentMean - firstMean
    }
    public var percentChange: Double? {
        guard let change = absoluteChange, let firstMean, firstMean != 0 else { return nil }
        return change / abs(firstMean) * 100
    }
}
public enum Trends {
    /// Compare first and last seven calendar days in a 30/180-day window.
    /// Reduce to one daily mean so dense sampling does not dominate the comparison.
    public static func summarize(_ points: [MetricPoint], days: Int, ending now: Date = Date(), calendar: Calendar = .current) -> TrendSummary {
        let days = max(14, days)
        let today = calendar.startOfDay(for: now)
        let start = calendar.date(byAdding: .day, value: -(days - 1), to: today)!
        let firstEnd = calendar.date(byAdding: .day, value: 7, to: start)!
        let recentStart = calendar.date(byAdding: .day, value: -6, to: today)!
        let eligible = points.filter { $0.date >= start && $0.date <= now && $0.value.isFinite }
        let daily = Dictionary(grouping: eligible, by: { calendar.startOfDay(for: $0.date) }).compactMap { date, points -> MetricPoint? in
            guard let value = Analytics.mean(points.map(\.value)) else { return nil }
            return MetricPoint(date: date, value: value)
        }.sorted { $0.date < $1.date }
        let first = daily.filter { $0.date < firstEnd }
        let recent = daily.filter { $0.date >= recentStart }
        return .init(points: daily, firstMean: Analytics.mean(first.map(\.value)), recentMean: Analytics.mean(recent.map(\.value)), firstDays: first.count, recentDays: recent.count)
    }
}
