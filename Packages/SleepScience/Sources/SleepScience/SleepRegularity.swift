import Foundation

/// Sleep Regularity Index (Phillips et al. 2017, Methods): the probability that two minutes 24 h apart are in the
/// same sleep/wake state, rescaled as SRI = 200·(P − ½). Range −100 to 100: 100 is perfectly periodic, 0 random.
public enum SleepRegularity {
    public struct Result: Sendable, Hashable {
        public var index: Double
        public var daysUsed: Int
    }

    /// SRI over the last `DisplayConventions.regularityWindowDays` days ending on `through` (inclusive), or nil
    /// with fewer than `regularityMinimumDays` days of data in the window (a display convention). `through` should
    /// be the last complete day, since every minute of it is compared. Only minute pairs whose two calendar days
    /// both have data are compared, so gaps do not count as wake. Sleep state comes from all of `days`, so the
    /// evening of a day sees the night that starts in it.
    public static func index(days: [SleepDay], through: Date, calendar: Calendar) -> Result? {
        let lastDay = calendar.startOfDay(for: through)
        let firstDay = calendar.date(byAdding: .day, value: -(DisplayConventions.regularityWindowDays - 1), to: lastDay)!
        let window = days.filter { $0.day >= firstDay && $0.day <= lastDay }
        let withData = Set(window.filter(\.hasData).map(\.day))
        guard withData.count >= DisplayConventions.regularityMinimumDays else { return nil }

        let asleep = IntervalMath.union(days.flatMap { $0.episodes.flatMap(\.fragments) })
        // A minute belongs to the calendar day it falls in; each day's minutes run from its local midnight.
        var same = 0
        var total = 0
        var day = firstDay
        while let next = calendar.date(byAdding: .day, value: 1, to: day), next <= lastDay {
            defer { day = next }
            guard withData.contains(day), withData.contains(next) else { continue }
            let minutes = Int(next.timeIntervalSince(day) / 60)
            for minute in 0..<minutes {
                let t = day.addingTimeInterval(Double(minute) * 60)
                let a = isAsleep(t, asleep)
                let b = isAsleep(t.addingTimeInterval(24 * 3600), asleep)
                same += a == b ? 1 : 0
                total += 1
            }
        }
        guard total > 0 else { return nil }
        return Result(index: 200 * (Double(same) / Double(total) - 0.5), daysUsed: withData.count)
    }

    private static func isAsleep(_ t: Date, _ asleep: [DateInterval]) -> Bool {
        asleep.contains { $0.start <= t && t < $0.end }
    }
}
