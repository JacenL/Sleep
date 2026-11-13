import Foundation

/// What every alertness model receives: plain sleep intervals and settings, no app types.
public struct AlertnessInput: Sendable {
    /// Time asleep, in any order. Everything else is wake.
    public var sleep: [DateInterval]
    /// The user's sleep need N, in hours.
    public var sleepNeedHours: Double
    /// Circadian acrophase in local clock hours (default or from `HabitualSchedule.acrophaseHours`).
    public var acrophaseHours: Double
    /// Supplies the local clock time for the time-of-day components.
    public var calendar: Calendar
    /// Stretches whose prediction rests on assumed rather than recorded sleep.
    public var lowConfidence: [DateInterval]

    public init(sleep: [DateInterval], sleepNeedHours: Double, acrophaseHours: Double, calendar: Calendar,
                lowConfidence: [DateInterval] = []) {
        self.sleep = sleep
        self.sleepNeedHours = sleepNeedHours
        self.acrophaseHours = acrophaseHours
        self.calendar = calendar
        self.lowConfidence = lowConfidence
    }
}

/// One point of a predicted alertness curve, on the model's own scale.
public struct AlertnessSample: Sendable, Hashable {
    public var time: Date
    /// Predicted alertness A(t).
    public var alertness: Double
    public var homeostatic: Double
    public var circadian: Double
    public var ultradian: Double
    /// Sleep inertia; zero when the model leaves it out.
    public var inertia: Double
    public var isAsleep: Bool
    public var confidence: Confidence

    public init(time: Date, alertness: Double, homeostatic: Double, circadian: Double, ultradian: Double,
                inertia: Double, isAsleep: Bool, confidence: Confidence) {
        self.time = time
        self.alertness = alertness
        self.homeostatic = homeostatic
        self.circadian = circadian
        self.ultradian = ultradian
        self.inertia = inertia
        self.isAsleep = isAsleep
        self.confidence = confidence
    }
}

/// A replaceable alertness model (CLAUDE.md rule 3). The UI depends only on this protocol.
public protocol AlertnessModel: Sendable {
    /// Samples at `start`, `start + step`, … up to and including `end`. The simulation runs from the first
    /// sleep interval, so callers supply a warm-up history (SCIENCE.md section 4, "Initial condition").
    func predict(_ input: AlertnessInput, from start: Date, to end: Date, step: TimeInterval) -> [AlertnessSample]
}
