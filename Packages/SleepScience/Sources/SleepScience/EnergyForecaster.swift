import Foundation

/// Everything the Today screen needs for one day, on the model's scale and as percentages.
public struct DayForecast: Sendable {
    public var day: Date
    /// Wake time that starts the waking day (recorded, or habitual when the night has no data).
    public var wake: Date
    /// Habitual bedtime that ends the waking day.
    public var bedtime: Date
    /// The waking day, every `DisplayConventions.sampleInterval`.
    public var curve: [AlertnessSample]
    public var events: [EnergyEvent]
    /// Peak of the rested reference simulation, on the model scale (SCIENCE.md section 6).
    public var referencePeak: Double
    /// "The most you are likely to reach today compared with a well-rested you." A display convention.
    public var todayPercent: Double
    /// The current point on the curve as a percentage, when `now` falls in the waking day.
    public var nowPercent: Double?
    public var schedule: HabitualSchedule
    /// Low if any part of the waking day rests on assumed sleep or the default schedule.
    public var confidence: Confidence
}

/// Runs a model over a sleep history to forecast one day.
public struct EnergyForecaster: Sendable {
    public var model: any AlertnessModel
    public var parameters: ThreeProcessParameters
    public var sleepNeedHours: Double
    public var calendar: Calendar

    public init(model: any AlertnessModel = ThreeProcessModel(), parameters: ThreeProcessParameters = .published,
                sleepNeedHours: Double = DisplayConventions.defaultSleepNeedHours, calendar: Calendar) {
        self.model = model
        self.parameters = parameters
        self.sleepNeedHours = sleepNeedHours
        self.calendar = calendar
    }

    public func forecast(episodes: [SleepEpisode], for day: Date, now: Date? = nil) -> DayForecast {
        let today = calendar.startOfDay(for: day)
        let simulationStart = calendar.date(byAdding: .day, value: -DisplayConventions.warmUpDays, to: today)!
        let earliest = episodes.map { calendar.startOfDay(for: $0.end) }.min().map { min($0, simulationStart) }
            ?? simulationStart
        let days = DayAssigner.days(from: episodes, firstDay: earliest, lastDay: today, calendar: calendar)
        let schedule = HabitualSchedule.from(days: days, through: today, calendar: calendar)
        let acrophase = schedule.acrophaseHours(parameters: parameters)
        let simulated = days.filter { $0.day >= simulationStart }
        let input = SleepHistory.modelInput(days: simulated, schedule: schedule, sleepNeedHours: sleepNeedHours,
                                            acrophaseHours: acrophase, calendar: calendar)

        let todayRecord = simulated.last!
        let wake = todayRecord.mainSleep.map(\.end).max()
            ?? SleepHistory.habitualNight(on: today, schedule: schedule, sleepNeedHours: sleepNeedHours,
                                          calendar: calendar)!.end
        let bedtime = schedule.onset.nextOccurrence(atOrAfter: wake.addingTimeInterval(60), in: calendar)!

        let step = DisplayConventions.sampleInterval
        let curve = model.predict(input, from: wake, to: bedtime, step: step)
        let events = EventDetector.events(waking: curve, bedtime: bedtime, calendar: calendar, parameters: parameters)
        let referencePeak = RestedPeak.referencePeak(model: model, schedule: schedule, sleepNeedHours: sleepNeedHours,
                                                     acrophaseHours: acrophase, endingOn: today, calendar: calendar)

        let todayPeak = curve.filter { !$0.isAsleep }.map(\.alertness).max() ?? parameters.scaleMinimum
        var nowPercent: Double?
        if let now, now >= wake, now <= bedtime, let sample = model.predict(input, from: now, to: now, step: step).first {
            nowPercent = RestedPeak.percent(sample.alertness, referencePeak: referencePeak, parameters: parameters)
        }
        let confidence = min(curve.map(\.confidence).min() ?? .low, schedule.confidence)
        return DayForecast(day: today, wake: wake, bedtime: bedtime, curve: curve, events: events,
                           referencePeak: referencePeak,
                           todayPercent: RestedPeak.percent(todayPeak, referencePeak: referencePeak, parameters: parameters),
                           nowPercent: nowPercent, schedule: schedule, confidence: confidence)
    }
}

/// "Percent of rested peak": a display **convention**, not a scientific quantity (SCIENCE.md section 6).
public enum RestedPeak {
    /// Peak waking alertness on the last day of a simulation in which the user follows their habitual schedule,
    /// sleeping exactly N hours, for `DisplayConventions.referenceSimulationDays` days ending on `endingOn`.
    public static func referencePeak(model: any AlertnessModel, schedule: HabitualSchedule, sleepNeedHours: Double,
                                     acrophaseHours: Double, endingOn day: Date, calendar: Calendar) -> Double {
        let lastDay = calendar.startOfDay(for: day)
        let nights = (0..<DisplayConventions.referenceSimulationDays).compactMap { offset -> DateInterval? in
            let night = calendar.date(byAdding: .day, value: -offset, to: lastDay)!
            return SleepHistory.habitualNight(on: night, schedule: schedule, sleepNeedHours: sleepNeedHours,
                                              calendar: calendar)
        }
        let input = AlertnessInput(sleep: nights, sleepNeedHours: sleepNeedHours, acrophaseHours: acrophaseHours,
                                   calendar: calendar)
        let wake = nights[0].end
        let nextOnset = wake.addingTimeInterval((24 - sleepNeedHours) * 3600)
        return model.predict(input, from: wake, to: nextOnset, step: DisplayConventions.sampleInterval)
            .map(\.alertness).max() ?? 0
    }

    /// clamp((A − 1) / (A_ref − 1), 0, 1.05), where 1 is the bottom of the model's scale.
    public static func percent(_ alertness: Double, referencePeak: Double,
                               parameters: ThreeProcessParameters = .published) -> Double {
        let floor = parameters.scaleMinimum
        guard referencePeak > floor else { return 0 }
        return min(max((alertness - floor) / (referencePeak - floor), 0), DisplayConventions.percentCeiling)
    }
}
