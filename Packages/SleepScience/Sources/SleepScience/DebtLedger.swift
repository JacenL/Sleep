import Foundation

/// The sleep-debt ledger: a transparent **convention**, not a published formula (SCIENCE.md section 5).
///
///     debt_0 = 0                                   (14 days before today)
///     debt_d = clamp(debt_{d−1} + (N − sleep_d), 0, 14·N/2)
///
/// Days with no data are skipped (debt unchanged). Filled nights are never counted.
public struct DebtLedger: Sendable, Hashable {
    public struct Entry: Sendable, Hashable {
        public var day: Date
        /// Total time asleep on episodes ending that day, in hours; nil when the day has no data.
        public var sleepHours: Double?
        /// Change applied to the balance that day, in hours, after clamping.
        public var change: Double
        /// Balance at the end of the day, in hours.
        public var balanceHours: Double
        public var containsEstimatedSleep: Bool
    }

    /// Oldest first, ending with today.
    public var entries: [Entry]
    public var sleepNeedHours: Double

    public var balanceHours: Double { entries.last?.balanceHours ?? 0 }
    public var daysWithoutData: Int { entries.filter { $0.sleepHours == nil }.count }
    /// Low when any day in the window has no data.
    public var confidence: Confidence { daysWithoutData > 0 ? .low : .normal }

    /// The ledger for the window ending on `today`. `days` may cover any range; days outside the window are ignored.
    public static func compute(days: [SleepDay], today: Date, sleepNeedHours: Double,
                               calendar: Calendar) -> DebtLedger {
        let window = DisplayConventions.debtWindowDays
        let lastDay = calendar.startOfDay(for: today)
        let firstDay = calendar.date(byAdding: .day, value: -(window - 1), to: lastDay)!
        let byDay = Dictionary(days.map { ($0.day, $0) }, uniquingKeysWith: { first, _ in first })
        let cap = DisplayConventions.debtCapHours(sleepNeedHours: sleepNeedHours)

        var entries: [Entry] = []
        var balance = 0.0
        var day = firstDay
        while day <= lastDay {
            let record = byDay[day]
            if let record, record.hasData {
                let sleep = record.totalSleep / 3600
                let next = min(max(balance + (sleepNeedHours - sleep), 0), cap)
                entries.append(Entry(day: day, sleepHours: sleep, change: next - balance, balanceHours: next,
                                     containsEstimatedSleep: record.containsEstimatedSleep))
                balance = next
            } else {
                entries.append(Entry(day: day, sleepHours: nil, change: 0, balanceHours: balance,
                                     containsEstimatedSleep: false))
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return DebtLedger(entries: entries, sleepNeedHours: sleepNeedHours)
    }
}
