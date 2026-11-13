import Foundation

/// Turns recorded sleep days into model input, filling nights with no data (SCIENCE.md section 4,
/// "Initial condition" and "Nights with no data").
public enum SleepHistory {
    /// A night of exactly `sleepNeedHours` ending at the habitual wake time on `day`. Used for days with no data
    /// and for the rested reference simulation.
    public static func habitualNight(on day: Date, schedule: HabitualSchedule, sleepNeedHours: Double,
                                     calendar: Calendar) -> DateInterval? {
        guard let wake = schedule.wake.on(day: day, in: calendar) else { return nil }
        return DateInterval(start: wake.addingTimeInterval(-sleepNeedHours * 3600), end: wake)
    }

    /// Model input for `days`, which must cover the whole simulated range. Days with no data get a habitual
    /// night, and output from that night until the next recorded sleep is marked low-confidence.
    public static func modelInput(days: [SleepDay], schedule: HabitualSchedule, sleepNeedHours: Double,
                                  acrophaseHours: Double, calendar: Calendar) -> AlertnessInput {
        let recorded = IntervalMath.union(days.flatMap { $0.episodes.flatMap(\.fragments) })
        let filled = days.filter { !$0.hasData }.compactMap {
            habitualNight(on: $0.day, schedule: schedule, sleepNeedHours: sleepNeedHours, calendar: calendar)
        }
        let rangeEnd = days.last.flatMap { calendar.date(byAdding: .day, value: 2, to: $0.day) } ?? .distantFuture
        let lowConfidence = filled.map { night -> DateInterval in
            let nextRecorded = recorded.first { $0.start >= night.end }?.start ?? rangeEnd
            return DateInterval(start: night.start, end: max(night.end, nextRecorded))
        }
        return AlertnessInput(sleep: IntervalMath.union(recorded + filled), sleepNeedHours: sleepNeedHours,
                              acrophaseHours: acrophaseHours, calendar: calendar, lowConfidence: lowConfidence)
    }
}
