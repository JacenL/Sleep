import Foundation

/// The three-process model of alertness (Åkerstedt & Folkard), v1 as specified in SCIENCE.md section 4:
/// S with the 2008 recovery brake, plus C and U, plus optional sleep inertia W. S is advanced in closed form
/// between state changes, so results do not depend on the sampling step.
public struct ThreeProcessModel: AlertnessModel {
    public var parameters: ThreeProcessParameters

    public init(parameters: ThreeProcessParameters = .published) {
        self.parameters = parameters
    }

    public func predict(_ input: AlertnessInput, from start: Date, to end: Date,
                        step: TimeInterval) -> [AlertnessSample] {
        precondition(step > 0, "step must be positive")
        let g = parameters.sleepRecoveryRate(sleepNeedHours: input.sleepNeedHours)
        let sleep = IntervalMath.union(input.sleep)
        let lowConfidence = IntervalMath.union(input.lowConfidence)

        // State at the first sleep onset: the steady state of a regular N-hour sleeper.
        var time = sleep.first.map { min($0.start, start) } ?? start
        var s = steadyState(sleepNeedHours: input.sleepNeedHours).atOnset
        var lastWake: Date?
        var nextSleepIndex = 0

        var samples: [AlertnessSample] = []
        var sampleTime = start
        while sampleTime <= end {
            // Advance S through every state change before this sample.
            while nextSleepIndex < sleep.count, sleep[nextSleepIndex].start <= sampleTime {
                let episode = sleep[nextSleepIndex]
                s = wake(from: s, hours: hours(time, episode.start))
                if episode.end <= sampleTime {
                    s = recover(from: s, hours: episode.duration / 3600, g: g)
                    time = episode.end
                    lastWake = episode.end
                    nextSleepIndex += 1
                } else {
                    time = episode.start
                    break
                }
            }

            let asleep = nextSleepIndex < sleep.count && sleep[nextSleepIndex].start <= sampleTime
            let homeostatic = asleep
                ? recover(from: s, hours: hours(time, sampleTime), g: g)
                : wake(from: s, hours: hours(time, sampleTime))
            let clockHours = localHours(sampleTime, calendar: input.calendar)
            let circadian = self.circadian(clockHours: clockHours, acrophase: input.acrophaseHours)
            let ultradian = self.ultradian(clockHours: clockHours, acrophase: input.acrophaseHours)
            var inertia = 0.0
            if parameters.includeSleepInertia, !asleep, let lastWake {
                inertia = self.inertia(hoursAwake: hours(lastWake, sampleTime))
            }
            let confidence: Confidence =
                lowConfidence.contains { $0.contains(sampleTime) } ? .low : .normal
            samples.append(AlertnessSample(time: sampleTime,
                                           alertness: homeostatic + circadian + ultradian + inertia,
                                           homeostatic: homeostatic, circadian: circadian, ultradian: ultradian,
                                           inertia: inertia, isAsleep: asleep, confidence: confidence))
            sampleTime = sampleTime.addingTimeInterval(step)
        }
        return samples
    }

    // MARK: Components (SCIENCE.md section 4)

    /// S after `hours` awake from `s`: decay toward the lower asymptote. 2004 p.A76; Ingre eq 1.1.
    public func wake(from s: Double, hours: Double) -> Double {
        let la = parameters.lowerAsymptote
        return la + (s - la) * exp(parameters.wakeDecayRate * hours)
    }

    /// S after `hours` asleep from `s`. Exponential recovery toward the upper asymptote (Ingre eq 1.2);
    /// with the brake, linear below the breakpoint at the exponential's slope there (Ingre eqs 1.3–1.5).
    public func recover(from s: Double, hours: Double, g: Double) -> Double {
        let ha = parameters.upperAsymptote
        let bl = parameters.brakePoint
        guard parameters.brakeEnabled, s < bl else {
            return ha - (ha - s) * exp(g * hours)
        }
        let slope = g * (bl - ha)
        let switchTime = (bl - s) / slope
        if hours <= switchTime { return s + hours * slope }
        return ha - (ha - bl) * exp(g * (hours - switchTime))
    }

    /// Hours of sleep from `s` until the brake hands over to exponential recovery (Ingre eq 1.5), or nil
    /// if recovery starts above the breakpoint or the brake is off.
    public func brakeSwitchHours(from s: Double, g: Double) -> Double? {
        let bl = parameters.brakePoint
        guard parameters.brakeEnabled, s < bl else { return nil }
        return (bl - s) / (g * (bl - parameters.upperAsymptote))
    }

    /// C at local clock time `clockHours`. Ingre eq 1.7.
    public func circadian(clockHours: Double, acrophase: Double) -> Double {
        parameters.circadianMesor + parameters.circadianAmplitude * cos(2 * .pi * (clockHours - acrophase) / 24)
    }

    /// U at local clock time `clockHours`. Ingre eq 1.8.
    public func ultradian(clockHours: Double, acrophase: Double) -> Double {
        parameters.ultradianMesor + parameters.ultradianAmplitude
            * cos(2 * .pi * (clockHours - acrophase - parameters.ultradianPhaseOffsetHours) / 12)
    }

    /// W after `hoursAwake`. Ingre eq 1.6.
    public func inertia(hoursAwake: Double) -> Double {
        parameters.inertiaMagnitude * exp(parameters.inertiaDecayRate * hoursAwake)
    }

    /// S at sleep onset and at waking for someone who has slept exactly N hours every 24 h for a long time.
    public func steadyState(sleepNeedHours: Double) -> (atOnset: Double, atWake: Double) {
        let g = parameters.sleepRecoveryRate(sleepNeedHours: sleepNeedHours)
        var onset = parameters.recoveryDefinitionStart
        var atWake = onset
        for _ in 0..<500 {
            atWake = recover(from: onset, hours: sleepNeedHours, g: g)
            let next = wake(from: atWake, hours: 24 - sleepNeedHours)
            if abs(next - onset) < 1e-12 { onset = next; break }
            onset = next
        }
        return (onset, atWake)
    }

    // MARK: Time

    private func hours(_ from: Date, _ to: Date) -> Double {
        to.timeIntervalSince(from) / 3600
    }

    /// Local wall-clock time as decimal hours, for the circadian phase maths.
    private func localHours(_ date: Date, calendar: Calendar) -> Double {
        let c = calendar.dateComponents([.hour, .minute, .second, .nanosecond], from: date)
        return Double(c.hour ?? 0) + Double(c.minute ?? 0) / 60 + Double(c.second ?? 0) / 3600
            + Double(c.nanosecond ?? 0) / 3.6e12
    }
}
