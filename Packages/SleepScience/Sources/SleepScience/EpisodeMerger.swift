import Foundation

/// Turns overlapping raw samples from several sources into sleep episodes (SCIENCE.md section 3, rules 1–5).
public enum EpisodeMerger {
    public static func episodes(from samples: [SleepSample],
                                joinGap: TimeInterval = DisplayConventions.fragmentJoinGap) -> [SleepEpisode] {
        let manual = IntervalMath.union(samples.filter(\.isManual).map(\.interval))
        let recordedSamples = samples.filter { !$0.isManual }
        let asleep = IntervalMath.union(recordedSamples.filter { $0.kind == .asleep }.map(\.interval))
        let awake = IntervalMath.union(recordedSamples.filter { $0.kind == .awake }.map(\.interval))
        let inBed = IntervalMath.union(recordedSamples.filter { $0.kind == .inBed }.map(\.interval))

        // Rule 2: union of asleep minus awake. Rule 5: manual entries replace recorded time they overlap.
        let recorded = IntervalMath.subtract(IntervalMath.subtract(asleep, awake), manual)

        // Rule 1: an in-bed session counts only if no asleep sample from any source falls inside it.
        // Rule 4: it then counts as sleep without correction, flagged as estimated.
        let inBedOnly = inBed.filter { !IntervalMath.overlapsAny($0, asleep) }
        let estimated = IntervalMath.subtract(inBedOnly, manual)

        var tagged: [(interval: DateInterval, quality: SleepEpisode.Quality)] =
            recorded.map { ($0, .recorded) } + estimated.map { ($0, .estimated) } + manual.map { ($0, .manual) }
        tagged.sort { $0.interval.start < $1.interval.start }

        // Rule 3: join fragments separated by less than `joinGap` of wake.
        var groups: [[(interval: DateInterval, quality: SleepEpisode.Quality)]] = []
        for fragment in tagged {
            if let lastEnd = groups.last?.last?.interval.end,
               fragment.interval.start.timeIntervalSince(lastEnd) < joinGap {
                groups[groups.count - 1].append(fragment)
            } else {
                groups.append([fragment])
            }
        }

        return groups.map { group in
            let qualities = Set(group.map(\.quality))
            let quality: SleepEpisode.Quality
            if qualities.contains(.estimated) {
                quality = .estimated
            } else if qualities == [.manual] {
                quality = .manual
            } else {
                quality = .recorded
            }
            let source: SleepEpisode.Source =
                qualities == [.manual] ? .manual : (qualities.contains(.manual) ? .mixed : .healthKit)
            return SleepEpisode(fragments: IntervalMath.union(group.map(\.interval)), quality: quality, source: source)
        }
    }
}

/// Assigns episodes to calendar days (SCIENCE.md section 3, rule 6).
public enum DayAssigner {
    /// The start of the calendar day on which `episode` ends, in `calendar`'s time zone.
    public static func day(of episode: SleepEpisode, in calendar: Calendar) -> Date {
        calendar.startOfDay(for: episode.end)
    }

    /// Episodes shorter than 3 h ending between 10:00 and 20:00 local time are naps.
    public static func isNap(_ episode: SleepEpisode, in calendar: Calendar) -> Bool {
        let hour = calendar.component(.hour, from: episode.end)
        return episode.span.duration < DisplayConventions.napMaximumDuration
            && DisplayConventions.napEndHours.contains(hour)
    }

    /// One `SleepDay` for every calendar day from `firstDay` through `lastDay` inclusive, including days
    /// with no data. Episodes ending outside that range are ignored.
    public static func days(from episodes: [SleepEpisode], firstDay: Date, lastDay: Date,
                            calendar: Calendar) -> [SleepDay] {
        var byDay: [Date: SleepDay] = [:]
        for episode in episodes {
            let day = day(of: episode, in: calendar)
            var entry = byDay[day] ?? SleepDay(day: day)
            if isNap(episode, in: calendar) {
                entry.naps.append(episode)
            } else {
                entry.mainSleep.append(episode)
            }
            byDay[day] = entry
        }

        var result: [SleepDay] = []
        var day = calendar.startOfDay(for: firstDay)
        let last = calendar.startOfDay(for: lastDay)
        while day <= last {
            result.append(byDay[day] ?? SleepDay(day: day))
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return result
    }
}
