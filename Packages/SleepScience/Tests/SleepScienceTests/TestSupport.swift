import Foundation
@testable import SleepScience

/// Builds dates and sleep histories in a fixed time zone so tests never depend on the machine's settings.
struct TestClock {
    let calendar: Calendar

    init(timeZone: String = "America/New_York") {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: timeZone)!
        self.calendar = calendar
    }

    func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    func day(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.startOfDay(for: date(year, month, day, 12))
    }

    func adding(days: Int, to date: Date) -> Date {
        calendar.date(byAdding: .day, value: days, to: date)!
    }

    /// Nightly sleep from `onset` on the evening before each day to `onset + hours` the next morning, for
    /// `nights` consecutive nights ending on `firstWakeDay` onward. Skips night indices in `skipping`.
    func nightlyEpisodes(firstWakeDay: Date, nights: Int, onset: ClockTime = ClockTime(hour: 23, minute: 0),
                         hours: Double, skipping: Set<Int> = []) -> [SleepEpisode] {
        (0..<nights).compactMap { index in
            guard !skipping.contains(index) else { return nil }
            let wakeDay = adding(days: index, to: firstWakeDay)
            let eveningBefore = adding(days: -1, to: wakeDay)
            let start = onset.on(day: onset.hour >= 12 ? eveningBefore : wakeDay, in: calendar)!
            let end = start.addingTimeInterval(hours * 3600)
            return SleepEpisode(fragments: [DateInterval(start: start, end: end)], quality: .recorded,
                                source: .healthKit)
        }
    }
}

extension TimeInterval {
    static func hours(_ h: Double) -> TimeInterval { h * 3600 }
    static func minutes(_ m: Double) -> TimeInterval { m * 60 }
}
