import Foundation

/// Conventions and heuristics the app needs that are **not** published science.
/// Each is defined in docs/SCIENCE.md and must be described as a convention in
/// the in-app "How this is calculated" screen. Published model values live in
/// `ThreeProcessParameters`.
public enum DisplayConventions {
    // MARK: Inputs (SCIENCE.md section 2)

    /// Default sleep need in hours, and the range the user may choose. Convention informed by
    /// Watson 2015 and Hirshkowitz 2015; individual need cannot be measured.
    public static let defaultSleepNeedHours: Double = 8
    public static let sleepNeedRangeHours: ClosedRange<Double> = 6...10

    /// Window and minimum number of days with data for the habitual schedule.
    public static let habitualWindowDays = 14
    public static let habitualMinimumDays = 5
    /// Habitual schedule assumed with fewer than `habitualMinimumDays` (local clock, hour and minute).
    public static let defaultHabitualOnset = ClockTime(hour: 23, minute: 0)
    public static let defaultHabitualWake = ClockTime(hour: 7, minute: 0)

    // MARK: Sleep data handling (section 3)

    /// Fragments separated by less wake than this are joined into one episode.
    public static let fragmentJoinGap: TimeInterval = 30 * 60
    /// Naps: episodes shorter than this that end within `napEndHours` (local clock).
    public static let napMaximumDuration: TimeInterval = 3 * 3600
    public static let napEndHours: Range<Int> = 10..<20

    // MARK: Model running (section 4)

    /// The simulation starts this many days before the first day displayed.
    public static let warmUpDays = 14

    /// Phase personalisation **heuristic**, not a measured circadian phase (in the spirit of Roenneberg 2003):
    /// p_user = p + (habitual mid-sleep − 03:00), clamped to ±4 h.
    public static let phaseReferenceMidSleep = ClockTime(hour: 3, minute: 0)
    public static let phaseShiftLimitHours: Double = 4

    // MARK: Debt ledger (section 5)

    public static let debtWindowDays = 14
    /// The ledger is capped at half of the window's total need: 14·N/2.
    public static func debtCapHours(sleepNeedHours: Double) -> Double {
        Double(debtWindowDays) * sleepNeedHours / 2
    }

    // MARK: Percent of rested peak (section 6)

    /// Upper clamp for now% and today%.
    public static let percentCeiling: Double = 1.05
    /// Length of the rested reference simulation, in days.
    public static let referenceSimulationDays = 14

    // MARK: Events (section 7)

    /// Curve sampling interval for events and display.
    public static let sampleInterval: TimeInterval = 5 * 60
    /// Minimum prominence, in scale units, for a local extremum to count as an event.
    public static let eventProminence: Double = 0.3
    /// A morning peak must occur before this local hour.
    public static let morningPeakBeforeHour = 14
    /// Wind-down prompt lead time before habitual sleep onset (a habit prompt, not a model output).
    public static let windDownLead: TimeInterval = 90 * 60

    // MARK: Other metrics (section 8)

    public static let regularityWindowDays = 14
    public static let regularityMinimumDays = 7
}

/// A local wall-clock time of day. Converted to `Date` only through `Calendar`.
public struct ClockTime: Sendable, Hashable, Comparable, CustomStringConvertible {
    public var hour: Int
    public var minute: Int

    public init(hour: Int, minute: Int) {
        self.hour = hour
        self.minute = minute
    }

    public var minutesSinceMidnight: Int { hour * 60 + minute }

    /// Hours since midnight as a fraction, for the circadian phase maths only.
    public var decimalHours: Double { Double(minutesSinceMidnight) / 60 }

    public init(minutesSinceMidnight minutes: Int) {
        let m = ((minutes % 1440) + 1440) % 1440
        self.init(hour: m / 60, minute: m % 60)
    }

    /// The local clock time of `date` in `calendar`'s time zone.
    public init(of date: Date, in calendar: Calendar) {
        let c = calendar.dateComponents([.hour, .minute], from: date)
        self.init(hour: c.hour ?? 0, minute: c.minute ?? 0)
    }

    /// The first instant at or after `date` showing this clock time in `calendar`. Across a DST gap the
    /// next valid time is used.
    public func nextOccurrence(atOrAfter date: Date, in calendar: Calendar) -> Date? {
        if ClockTime(of: date, in: calendar) == self,
           calendar.component(.second, from: date) == 0 { return date }
        return calendar.nextDate(after: date,
                                 matching: DateComponents(hour: hour, minute: minute, second: 0),
                                 matchingPolicy: .nextTime)
    }

    /// The occurrence of this clock time on the calendar day containing `day`.
    public func on(day: Date, in calendar: Calendar) -> Date? {
        calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day,
                      matchingPolicy: .nextTime, repeatedTimePolicy: .first, direction: .forward)
    }

    public static func < (lhs: ClockTime, rhs: ClockTime) -> Bool {
        lhs.minutesSinceMidnight < rhs.minutesSinceMidnight
    }

    public var description: String { String(format: "%02d:%02d", hour, minute) }
}
