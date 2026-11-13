import Foundation

/// One raw sleep-analysis record as the data layer receives it, before merging (SCIENCE.md section 3).
/// HealthKit's asleepUnspecified/Core/Deep/REM all map to `.asleep`.
public struct SleepSample: Sendable, Hashable {
    public enum Kind: Sendable, Hashable { case asleep, inBed, awake }

    public var interval: DateInterval
    public var kind: Kind
    /// Identifier of the recording source (for example a HealthKit source bundle id).
    public var source: String
    /// A manual entry is the user's stated truth: it counts as sleep whatever its `kind`, and it overrides
    /// HealthKit for overlapping time.
    public var isManual: Bool

    public init(interval: DateInterval, kind: Kind, source: String, isManual: Bool = false) {
        self.interval = interval
        self.kind = kind
        self.source = source
        self.isManual = isManual
    }

    public init(start: Date, end: Date, kind: Kind, source: String, isManual: Bool = false) {
        self.init(interval: DateInterval(start: start, end: max(start, end)), kind: kind, source: source,
                  isManual: isManual)
    }
}

/// A merged sleep episode: asleep fragments joined across short wakes.
public struct SleepEpisode: Sendable, Hashable {
    public enum Quality: Sendable, Hashable {
        /// From asleep samples.
        case recorded
        /// From in-bed samples only, counted as sleep without correction. Must be flagged in the UI.
        case estimated
        /// Entered by the user.
        case manual
    }

    public enum Source: Sendable, Hashable { case healthKit, manual, mixed }

    /// Time asleep, sorted and non-overlapping. Gaps between fragments are wake shorter than
    /// `DisplayConventions.fragmentJoinGap`.
    public var fragments: [DateInterval]
    public var quality: Quality
    public var source: Source

    public init(fragments: [DateInterval], quality: Quality, source: Source) {
        precondition(!fragments.isEmpty, "an episode needs at least one fragment")
        self.fragments = fragments.sorted { $0.start < $1.start }
        self.quality = quality
        self.source = source
    }

    public var start: Date { fragments[0].start }
    public var end: Date { fragments[fragments.count - 1].end }
    /// Sum of asleep time, not the episode span.
    public var asleepDuration: TimeInterval { fragments.reduce(0) { $0 + $1.duration } }
    public var span: DateInterval { DateInterval(start: start, end: end) }
}

/// The sleep that belongs to one calendar day: every episode that **ends** on that day in the user's time zone.
public struct SleepDay: Sendable, Hashable {
    /// Start of the calendar day.
    public var day: Date
    public var mainSleep: [SleepEpisode]
    public var naps: [SleepEpisode]

    public init(day: Date, mainSleep: [SleepEpisode] = [], naps: [SleepEpisode] = []) {
        self.day = day
        self.mainSleep = mainSleep
        self.naps = naps
    }

    public var episodes: [SleepEpisode] { (mainSleep + naps).sorted { $0.start < $1.start } }
    public var hasData: Bool { !mainSleep.isEmpty || !naps.isEmpty }
    /// Total time asleep, naps included.
    public var totalSleep: TimeInterval { episodes.reduce(0) { $0 + $1.asleepDuration } }
    public var containsEstimatedSleep: Bool { episodes.contains { $0.quality == .estimated } }
}

/// Whether an output rests on real data or on assumptions (filled nights, default schedule, gaps).
public enum Confidence: Sendable, Hashable, Comparable {
    case low
    case normal
}
