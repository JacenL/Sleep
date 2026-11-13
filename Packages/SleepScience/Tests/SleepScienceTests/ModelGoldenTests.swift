import Foundation
import Testing
@testable import SleepScience

/// Golden tests 1, 3 and 7 (SCIENCE.md section 9) against the model alone, with explicit sleep histories.
struct ModelGoldenTests {
    let clock = TestClock()
    let model = ThreeProcessModel()
    let p = ThreeProcessParameters.published

    func input(_ episodes: [SleepEpisode], need: Double = 8) -> AlertnessInput {
        AlertnessInput(sleep: episodes.flatMap(\.fragments), sleepNeedHours: need,
                       acrophaseHours: p.defaultAcrophaseHours, calendar: clock.calendar)
    }

    /// Waking-day samples from `wake` to `bed` every 5 minutes.
    func curve(_ input: AlertnessInput, _ from: Date, _ to: Date) -> [AlertnessSample] {
        model.predict(input, from: from, to: to, step: DisplayConventions.sampleInterval)
    }

    // MARK: Golden test 1

    @Test func regularSleeperReachesSteadyStateWithOneLateAfternoonMaximum() throws {
        let first = clock.day(2026, 4, 1)
        let history = input(clock.nightlyEpisodes(firstWakeDay: first, nights: 20, hours: 8))
        let day15 = clock.adding(days: 15, to: first)
        let day16 = clock.adding(days: 16, to: first)
        let a = curve(history, clock.calendar.date(byAdding: .hour, value: 7, to: day15)!,
                      clock.calendar.date(byAdding: .hour, value: 23, to: day15)!)
        let b = curve(history, clock.calendar.date(byAdding: .hour, value: 7, to: day16)!,
                      clock.calendar.date(byAdding: .hour, value: 23, to: day16)!)
        #expect(a.count == b.count)
        let maxDifference = zip(a, b).map { abs($0.alertness - $1.alertness) }.max()!
        #expect(maxDifference < 0.05)

        let peak = try #require(a.max { $0.alertness < $1.alertness })
        let peakHour = ClockTime(of: peak.time, in: clock.calendar)
        #expect(peakHour >= ClockTime(hour: 15, minute: 30) && peakHour <= ClockTime(hour: 18, minute: 0))
        // Single maximum: the curve only rises before the peak and only falls after it.
        let index = a.firstIndex(of: peak)!
        #expect(zip(a[..<index], a[1...index]).allSatisfy { $0.alertness <= $1.alertness + 1e-9 })
        #expect(zip(a[index...], a[(index + 1)...]).allSatisfy { $0.alertness >= $1.alertness - 1e-9 })
    }

    // MARK: Golden test 3

    @Test func totalDeprivationNightTroughsInTheEarlyMorning() throws {
        let first = clock.day(2026, 4, 1)
        // Nights 0–15 regular; night 16 (ending on day 16) skipped; night 17 regular again.
        let history = input(clock.nightlyEpisodes(firstWakeDay: first, nights: 18, hours: 8, skipping: [16]))
        let baselineDay = clock.adding(days: 15, to: first)
        let deprivedEvening = clock.adding(days: 15, to: first)
        let nextDay = clock.adding(days: 16, to: first)

        func at(_ day: Date, _ hour: Int) -> Date { clock.calendar.date(byAdding: .hour, value: hour, to: day)! }

        let baseline = curve(history, at(baselineDay, 7), at(baselineDay, 23))
        let night = curve(history, at(deprivedEvening, 23), at(nextDay, 7))
        let following = curve(history, at(nextDay, 7), at(nextDay, 23))

        let trough = try #require(night.min { $0.alertness < $1.alertness })
        let troughTime = ClockTime(of: trough.time, in: clock.calendar)
        #expect(troughTime >= ClockTime(hour: 4, minute: 0) && troughTime <= ClockTime(hour: 6, minute: 0))
        #expect(trough.alertness < baseline.map(\.alertness).min()!)
        #expect(following.map(\.alertness).max()! < baseline.map(\.alertness).max()!)
    }

    // MARK: Golden test 7

    @Test func eightHoursFromSevenNinetySixReachesFourteenWithoutBrake() {
        var parameters = ThreeProcessParameters.published
        parameters.brakeEnabled = false
        let unbraked = ThreeProcessModel(parameters: parameters)
        let g = parameters.sleepRecoveryRate(sleepNeedHours: 8)
        #expect(abs(g - (-0.3813)) < 0.0001)
        #expect(abs(unbraked.recover(from: 7.96, hours: 8, g: g) - 14.000) < 0.001)
    }

    @Test func eightHoursFromSevenNinetySixWithBrake() throws {
        let g = p.sleepRecoveryRate(sleepNeedHours: 8)
        let switchHours = try #require(model.brakeSwitchHours(from: 7.96, g: g))
        #expect(abs(switchHours - 5.294) < 0.001)
        #expect(abs(g * (p.brakePoint - p.upperAsymptote) - 0.8008) < 0.0001)
        #expect(abs(model.recover(from: 7.96, hours: 8, g: g) - 13.552) < 0.001)
    }

    @Test func wakeDecayIsAboutThreeAndAHalfPercentPerHour() {
        let s0 = 14.0
        let s1 = model.wake(from: s0, hours: 1)
        let fraction = (s1 - p.lowerAsymptote) / (s0 - p.lowerAsymptote)
        #expect(abs((1 - fraction) - 0.0347) < 0.0001)
    }

    // MARK: Brake and inertia details

    @Test func brakeIsContinuousAtTheBreakpoint() throws {
        let g = p.sleepRecoveryRate(sleepNeedHours: 8)
        let switchHours = try #require(model.brakeSwitchHours(from: 6, g: g))
        let before = model.recover(from: 6, hours: switchHours - 1e-6, g: g)
        let after = model.recover(from: 6, hours: switchHours + 1e-6, g: g)
        #expect(abs(before - p.brakePoint) < 1e-5 && abs(after - p.brakePoint) < 1e-5)
        #expect(model.brakeSwitchHours(from: 12.5, g: g) == nil)
    }

    @Test func sleepNeedScalesRecoveryToReachFullRecoveryInNHours() {
        var parameters = ThreeProcessParameters.published
        parameters.brakeEnabled = false
        let unbraked = ThreeProcessModel(parameters: parameters)
        for need in [6.0, 7.0, 9.0, 10.0] {
            let g = parameters.sleepRecoveryRate(sleepNeedHours: need)
            #expect(abs(unbraked.recover(from: 7.96, hours: need, g: g) - 14.0) < 1e-9)
        }
    }

    @Test func inertiaIsOffByDefaultAndMatchesIngreWhenOn() {
        #expect(!ThreeProcessParameters.published.includeSleepInertia)
        var parameters = ThreeProcessParameters.published
        parameters.includeSleepInertia = true
        let withInertia = ThreeProcessModel(parameters: parameters)
        #expect(withInertia.inertia(hoursAwake: 0) == -5.72)
        #expect(abs(withInertia.inertia(hoursAwake: 1) - (-5.72 * exp(-1.51))) < 1e-12)

        let first = clock.day(2026, 4, 1)
        let history = input(clock.nightlyEpisodes(firstWakeDay: first, nights: 16, hours: 8))
        let wake = clock.calendar.date(byAdding: .hour, value: 7, to: clock.adding(days: 15, to: first))!
        let on = withInertia.predict(history, from: wake.addingTimeInterval(300), to: wake.addingTimeInterval(300),
                                     step: 300)[0]
        let off = model.predict(history, from: wake.addingTimeInterval(300), to: wake.addingTimeInterval(300),
                                step: 300)[0]
        #expect(off.inertia == 0)
        #expect(abs(on.alertness - off.alertness - withInertia.inertia(hoursAwake: 300.0 / 3600)) < 1e-9)
    }

    @Test func resultsDoNotDependOnSampleStep() {
        let first = clock.day(2026, 4, 1)
        let history = input(clock.nightlyEpisodes(firstWakeDay: first, nights: 16, hours: 8))
        let t = clock.calendar.date(byAdding: .hour, value: 15, to: clock.adding(days: 15, to: first))!
        let coarse = model.predict(history, from: t, to: t, step: 3600)[0]
        let fine = model.predict(history, from: t.addingTimeInterval(-3600), to: t, step: 60).last!
        #expect(abs(coarse.alertness - fine.alertness) < 1e-9)
    }
}
