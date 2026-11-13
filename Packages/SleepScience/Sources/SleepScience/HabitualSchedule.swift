import Foundation

/// The user's typical sleep timing: 14-day medians of main-sleep onset, wake and mid-sleep
/// (SCIENCE.md section 2), and the phase heuristic built on it (section 4).
public struct HabitualSchedule: Sendable, Hashable {
    public var onset: ClockTime
    public var wake: ClockTime
    public var midSleep: ClockTime
    /// Number of days the medians were taken over. Zero when defaults are used.
    public var daysUsed: Int

    public var isDefault: Bool { daysUsed == 0 }
    public var confidence: Confidence { isDefault ? .low : .normal }

    public init(onset: ClockTime, wake: ClockTime, midSleep: ClockTime, daysUsed: Int) {
        self.onset = onset
        self.wake = wake
        self.midSleep = midSleep
        self.daysUsed = daysUsed
    }

    public static let `default`: HabitualSchedule = {
        let onset = DisplayConventions.defaultHabitualOnset
        let wake = DisplayConventions.defaultHabitualWake
        let length = (wake.minutesSinceMidnight - onset.minutesSinceMidnight + 1440) % 1440
        return HabitualSchedule(onset: onset, wake: wake,
                                midSleep: ClockTime(minutesSinceMidnight: onset.minutesSinceMidnight + length / 2),
                                daysUsed: 0)
    }()

    /// Medians over the most recent `DisplayConventions.habitualWindowDays` days with main sleep, among `days`
    /// up to and including `through`. Falls back to the default with fewer than the minimum.
    public static func from(days: [SleepDay], through: Date, calendar: Calendar) -> HabitualSchedule {
        let lastDay = calendar.startOfDay(for: through)
        let mains = days
            .filter { $0.day <= lastDay && !$0.mainSleep.isEmpty }
            .sorted { $0.day > $1.day }
            .prefix(DisplayConventions.habitualWindowDays)
            .compactMap { $0.mainSleep.max { $0.asleepDuration < $1.asleepDuration } }
        guard mains.count >= DisplayConventions.habitualMinimumDays else { return .default }

        let onsets = mains.map { ClockTime(of: $0.start, in: calendar) }
        let wakes = mains.map { ClockTime(of: $0.end, in: calendar) }
        let mids = mains.map {
            ClockTime(of: $0.start.addingTimeInterval($0.span.duration / 2), in: calendar)
        }
        return HabitualSchedule(onset: median(onsets, anchor: Self.eveningAnchor),
                                wake: median(wakes, anchor: Self.wakeAnchor),
                                midSleep: median(mids, anchor: Self.eveningAnchor),
                                daysUsed: mains.count)
    }

    /// Circadian acrophase for this schedule. **Heuristic**, not a measured phase: the default acrophase shifted
    /// by habitual mid-sleep relative to 03:00, clamped to ±4 h (SCIENCE.md section 4, "Personalising phase").
    public func acrophaseHours(parameters: ThreeProcessParameters = .published) -> Double {
        let reference = Self.frameMinutes(DisplayConventions.phaseReferenceMidSleep, anchor: Self.eveningAnchor)
        let shift = Double(Self.frameMinutes(midSleep, anchor: Self.eveningAnchor) - reference) / 60
        let limit = DisplayConventions.phaseShiftLimitHours
        return parameters.defaultAcrophaseHours + min(max(shift, -limit), limit)
    }

    // Medians are taken on a clock that wraps away from where the values cluster, so bedtimes either
    // side of midnight sort correctly: noon for onset and mid-sleep, 18:00 for wake.
    static let eveningAnchor = ClockTime(hour: 12, minute: 0)
    static let wakeAnchor = ClockTime(hour: 18, minute: 0)

    static func frameMinutes(_ time: ClockTime, anchor: ClockTime) -> Int {
        (time.minutesSinceMidnight - anchor.minutesSinceMidnight + 1440) % 1440
    }

    static func median(_ times: [ClockTime], anchor: ClockTime) -> ClockTime {
        let sorted = times.map { frameMinutes($0, anchor: anchor) }.sorted()
        let middle = sorted.count / 2
        let frame = sorted.count % 2 == 1
            ? sorted[middle]
            : Int((Double(sorted[middle - 1] + sorted[middle]) / 2).rounded())
        return ClockTime(minutesSinceMidnight: frame + anchor.minutesSinceMidnight)
    }
}
