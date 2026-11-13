import Foundation

/// A predicted moment worth telling the user about (SCIENCE.md section 7).
public struct EnergyEvent: Sendable, Hashable {
    public enum Kind: Sendable, Hashable, CaseIterable {
        /// Highest point of the waking day.
        case dailyPeak
        /// First time predicted alertness reaches the published sleepiness threshold (7).
        case lowEnergy
        /// Conditional on prominence: usually absent with v1 on a regular schedule.
        case morningPeak, afternoonDip, eveningPeak
        /// A habit prompt before habitual sleep onset, not a model output.
        case windDown
    }

    public var kind: Kind
    public var time: Date
    /// Predicted alertness at `time`; nil for wind-down.
    public var alertness: Double?
    public var confidence: Confidence
}

/// Finds events on one waking day's curve (wake to habitual bedtime).
public enum EventDetector {
    public static func events(waking curve: [AlertnessSample], bedtime: Date, calendar: Calendar,
                              parameters: ThreeProcessParameters = .published) -> [EnergyEvent] {
        var events: [EnergyEvent] = []
        let awake = curve.filter { !$0.isAsleep }

        if let peak = awake.max(by: { $0.alertness < $1.alertness }) {
            events.append(event(.dailyPeak, peak))
        }
        if let low = awake.first(where: { $0.alertness <= parameters.sleepinessThreshold }) {
            events.append(event(.lowEnergy, low))
        }

        events.append(contentsOf: conditionalPeaks(awake, calendar: calendar))
        // The daily peak is not repeated when a qualifying peak marks the same moment.
        let conditionalTimes = Set(events.filter { $0.kind == .morningPeak || $0.kind == .eveningPeak }.map(\.time))
        events.removeAll { $0.kind == .dailyPeak && conditionalTimes.contains($0.time) }

        let windDown = bedtime.addingTimeInterval(-DisplayConventions.windDownLead)
        if let first = awake.first, windDown > first.time {
            events.append(EnergyEvent(kind: .windDown, time: windDown, alertness: nil, confidence: first.confidence))
        }
        return events.sorted { $0.time < $1.time }
    }

    private static func event(_ kind: EnergyEvent.Kind, _ sample: AlertnessSample) -> EnergyEvent {
        EnergyEvent(kind: kind, time: sample.time, alertness: sample.alertness, confidence: sample.confidence)
    }

    /// Morning peak, afternoon dip and evening peak, each only if its prominence reaches
    /// `DisplayConventions.eventProminence`. Without a qualifying morning peak, dip and evening peak, none is emitted.
    static func conditionalPeaks(_ curve: [AlertnessSample], calendar: Calendar) -> [EnergyEvent] {
        let values = curve.map(\.alertness)
        let threshold = DisplayConventions.eventProminence
        let maxima = localExtrema(values, maxima: true).filter { prominence(values, $0, maxima: true) >= threshold }
        let minima = localExtrema(values, maxima: false).filter { prominence(values, $0, maxima: false) >= threshold }

        let morning = maxima
            .filter { calendar.component(.hour, from: curve[$0].time) < DisplayConventions.morningPeakBeforeHour }
            .max { values[$0] < values[$1] }
        guard let morning else { return [] }

        // The lowest qualifying dip after the morning peak that is followed by a qualifying peak.
        let dip = minima
            .filter { candidate in candidate > morning && maxima.contains { $0 > candidate } }
            .min { values[$0] < values[$1] }
        guard let dip else { return [event(.morningPeak, curve[morning])] }
        let evening = maxima.filter { $0 > dip }.max { values[$0] < values[$1] }!
        return [event(.morningPeak, curve[morning]), event(.afternoonDip, curve[dip]),
                event(.eveningPeak, curve[evening])]
    }

    /// Interior local maxima (or minima). On a plateau the first index is used.
    static func localExtrema(_ values: [Double], maxima: Bool) -> [Int] {
        guard values.count >= 3 else { return [] }
        var result: [Int] = []
        var i = 1
        while i < values.count - 1 {
            var j = i
            while j + 1 < values.count, values[j + 1] == values[i] { j += 1 }
            if j < values.count - 1 {
                let before = values[i - 1], after = values[j + 1], v = values[i]
                if maxima ? (v > before && v > after) : (v < before && v < after) { result.append(i) }
            }
            i = j + 1
        }
        return result
    }

    /// Topographic prominence: how far the extremum stands out from the higher of the two bases on either side,
    /// each base being the most extreme opposite value before the curve passes the extremum again or ends.
    static func prominence(_ values: [Double], _ index: Int, maxima: Bool) -> Double {
        let sign = maxima ? 1.0 : -1.0
        let v = sign * values[index]
        func base(_ range: StrideTo<Int>) -> Double {
            var lowest = v
            for k in range {
                let x = sign * values[k]
                if x > v { break }
                lowest = min(lowest, x)
            }
            return lowest
        }
        let left = base(stride(from: index - 1, to: -1, by: -1))
        let right = base(stride(from: index + 1, to: values.count, by: 1))
        return v - max(left, right)
    }
}
