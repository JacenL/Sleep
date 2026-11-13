import Foundation

/// Set operations on time intervals. Results are sorted, non-overlapping and free of zero-length pieces.
enum IntervalMath {
    /// Union, merging intervals that overlap or touch.
    static func union(_ intervals: [DateInterval]) -> [DateInterval] {
        let sorted = intervals.filter { $0.duration > 0 }.sorted { $0.start < $1.start }
        var result: [DateInterval] = []
        for interval in sorted {
            if let last = result.last, interval.start <= last.end {
                result[result.count - 1] = DateInterval(start: last.start, end: max(last.end, interval.end))
            } else {
                result.append(interval)
            }
        }
        return result
    }

    /// `base` minus every interval in `removing`.
    static func subtract(_ base: [DateInterval], _ removing: [DateInterval]) -> [DateInterval] {
        let cuts = union(removing)
        var result: [DateInterval] = []
        for piece in union(base) {
            var remainder = [piece]
            for cut in cuts where cut.end > piece.start && cut.start < piece.end {
                remainder = remainder.flatMap { part -> [DateInterval] in
                    guard cut.end > part.start, cut.start < part.end else { return [part] }
                    var kept: [DateInterval] = []
                    if cut.start > part.start { kept.append(DateInterval(start: part.start, end: cut.start)) }
                    if cut.end < part.end { kept.append(DateInterval(start: cut.end, end: part.end)) }
                    return kept
                }
            }
            result.append(contentsOf: remainder)
        }
        return result.filter { $0.duration > 0 }
    }

    /// Whether `interval` overlaps any member of `set` by a positive duration.
    static func overlapsAny(_ interval: DateInterval, _ set: [DateInterval]) -> Bool {
        set.contains { $0.start < interval.end && interval.start < $0.end }
    }

    /// Total overlap between `interval` and the members of `set` (which must not overlap each other).
    static func overlapDuration(_ interval: DateInterval, _ set: [DateInterval]) -> TimeInterval {
        set.reduce(0) { total, other in
            let start = max(interval.start, other.start)
            let end = min(interval.end, other.end)
            return total + max(0, end.timeIntervalSince(start))
        }
    }
}
