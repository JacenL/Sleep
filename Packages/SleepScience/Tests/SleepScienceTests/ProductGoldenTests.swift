import Foundation
import Testing
@testable import SleepScience

/// Golden tests 1 (events), 4, 5, 6, 9 and 10 (SCIENCE.md section 9), plus the habitual schedule,
/// gap filling and regularity index.
struct ProductGoldenTests {
    let clock = TestClock()
    let model = ThreeProcessModel()
    let p = ThreeProcessParameters.published
    let first = TestClock().day(2026, 4, 1)

    func at(_ day: Date, _ hour: Int, _ minute: Int = 0) -> Date {
        ClockTime(hour: hour, minute: minute).on(day: day, in: clock.calendar)!
    }

    func day(_ offset: Int) -> Date { clock.adding(days: offset, to: first) }

    /// Waking-day curve 07:00–23:00 with a fixed default acrophase, to isolate the effect of sleep.
    func wakingCurve(_ episodes: [SleepEpisode], on day: Date) -> [AlertnessSample] {
        let input = AlertnessInput(sleep: episodes.flatMap(\.fragments), sleepNeedHours: 8,
                                   acrophaseHours: p.defaultAcrophaseHours, calendar: clock.calendar)
        return model.predict(input, from: at(day, 7), to: at(day, 23), step: DisplayConventions.sampleInterval)
    }

    func peak(_ curve: [AlertnessSample]) -> Double { curve.map(\.alertness).max()! }

    func days(_ episodes: [SleepEpisode], through last: Date) -> [SleepDay] {
        DayAssigner.days(from: episodes, firstDay: first, lastDay: last, calendar: clock.calendar)
    }

    // MARK: Golden test 1 (events)

    @Test func regularScheduleEmitsDailyPeakAndWindDownOnly() {
        let episodes = clock.nightlyEpisodes(firstWakeDay: first, nights: 20, hours: 8)
        let forecast = EnergyForecaster(calendar: clock.calendar).forecast(episodes: episodes, for: day(19))
        #expect(Set(forecast.events.map(\.kind)) == [.dailyPeak, .windDown])
        #expect(forecast.wake == at(day(19), 7))
        #expect(forecast.bedtime == at(day(19), 23))
        #expect(forecast.events.first { $0.kind == .windDown }!.time == at(day(19), 21, 30))
        #expect(forecast.confidence == .normal)
    }

    // MARK: Golden tests 4 and 5

    /// 14 nights of 8 h, then 14 nights of 6 h in bed (01:00–07:00) or a control arm of 8 h.
    func restrictionArms() -> (control: [SleepEpisode], restricted: [SleepEpisode]) {
        let baseline = clock.nightlyEpisodes(firstWakeDay: first, nights: 14, hours: 8)
        let control = baseline + clock.nightlyEpisodes(firstWakeDay: day(14), nights: 14, hours: 8)
        let restricted = baseline + clock.nightlyEpisodes(firstWakeDay: day(14), nights: 14,
                                                          onset: ClockTime(hour: 1, minute: 0), hours: 6)
        return (control, restricted)
    }

    @Test func sixHoursForFourteenDaysLowersEveryPeakAndAddsTwoHoursOfDebtPerDay() {
        let (control, restricted) = restrictionArms()
        for offset in 14..<28 {
            #expect(peak(wakingCurve(restricted, on: day(offset))) < peak(wakingCurve(control, on: day(offset))))
        }
        let ledger = DebtLedger.compute(days: days(restricted, through: day(27)), today: day(27), sleepNeedHours: 8,
                                        calendar: clock.calendar)
        #expect(ledger.entries.count == 14)
        #expect(ledger.entries.allSatisfy { abs($0.change - 2) < 1e-9 })
        #expect(abs(ledger.balanceHours - 28) < 1e-9)
        #expect(ledger.confidence == .normal)
    }

    @Test func threeNineHourNightsPayDownThreeHoursAndRaiseThePeak() {
        let restricted = restrictionArms().restricted
        let recovery = restricted + clock.nightlyEpisodes(firstWakeDay: day(28), nights: 3,
                                                          onset: ClockTime(hour: 22, minute: 0), hours: 9)
        // The ledger's 14-day window slides, so the reduction is read within one ledger: the balance on the
        // day before recovery minus the balance after the third recovery night.
        let ledger = DebtLedger.compute(days: days(recovery, through: day(30)), today: day(30), sleepNeedHours: 8,
                                        calendar: clock.calendar)
        let beforeRecovery = ledger.entries.first { $0.day == day(27) }!.balanceHours
        #expect(abs((beforeRecovery - ledger.balanceHours) - 3) < 1e-9)
        #expect(ledger.entries.suffix(3).allSatisfy { abs($0.change + 1) < 1e-9 })
        #expect(peak(wakingCurve(recovery, on: day(30))) > peak(wakingCurve(restricted, on: day(27))))
    }

    @Test func debtLedgerSkipsDaysWithoutDataAndNeverGoesNegative() {
        let episodes = clock.nightlyEpisodes(firstWakeDay: first, nights: 14, hours: 7, skipping: [5, 6, 7])
            + clock.nightlyEpisodes(firstWakeDay: day(14), nights: 1, hours: 12)
        let ledger = DebtLedger.compute(days: days(episodes, through: day(14)), today: day(14), sleepNeedHours: 8,
                                        calendar: clock.calendar)
        #expect(ledger.daysWithoutData == 3)
        #expect(ledger.confidence == .low)
        // Days 1–13 in the window: 10 nights of 7 h → 10 h; then 12 h pays down 4 h.
        #expect(abs(ledger.entries[12].balanceHours - 10) < 1e-9)
        #expect(abs(ledger.balanceHours - 6) < 1e-9)

        let surplus = clock.nightlyEpisodes(firstWakeDay: first, nights: 14, hours: 9)
        let rested = DebtLedger.compute(days: days(surplus, through: day(13)), today: day(13), sleepNeedHours: 8,
                                        calendar: clock.calendar)
        #expect(rested.balanceHours == 0)
    }

    @Test func debtLedgerIsCappedAtHalfTheWindowsNeed() {
        let none = clock.nightlyEpisodes(firstWakeDay: first, nights: 14, hours: 0.5)
        let ledger = DebtLedger.compute(days: days(none, through: day(13)), today: day(13), sleepNeedHours: 8,
                                        calendar: clock.calendar)
        #expect(ledger.balanceHours == 56)
    }

    // MARK: Golden test 6

    @Test func shiftingTheScheduleTwoHoursLaterShiftsEventsTwoHours() throws {
        let early = clock.nightlyEpisodes(firstWakeDay: first, nights: 20, hours: 8)
        let late = clock.nightlyEpisodes(firstWakeDay: day(20), nights: 20, onset: ClockTime(hour: 1, minute: 0),
                                         hours: 8)
        let forecaster = EnergyForecaster(calendar: clock.calendar)
        let before = forecaster.forecast(episodes: early + late, for: day(19))
        let after = forecaster.forecast(episodes: early + late, for: day(39))
        #expect(after.schedule.midSleep == ClockTime(hour: 5, minute: 0))

        for kind in [EnergyEvent.Kind.dailyPeak, .windDown] {
            let a = try #require(before.events.first { $0.kind == kind })
            let b = try #require(after.events.first { $0.kind == kind })
            let shift = ClockTime(of: b.time, in: clock.calendar).minutesSinceMidnight
                - ClockTime(of: a.time, in: clock.calendar).minutesSinceMidnight
            #expect(abs(shift - 120) <= 10, "\(kind) moved \(shift) min")
        }
    }

    // MARK: Golden test 9

    @Test func restedUserIsAtTheirRestedPeak() throws {
        let schedule = HabitualSchedule.default
        let reference = RestedPeak.referencePeak(model: model, schedule: schedule, sleepNeedHours: 8,
                                                 acrophaseHours: 16.8, endingOn: day(20), calendar: clock.calendar)
        #expect(abs(RestedPeak.percent(reference, referencePeak: reference) - 1) <= 0.02)

        // A user whose real history is exactly the reference schedule scores ~100 % at their peak.
        let episodes = clock.nightlyEpisodes(firstWakeDay: first, nights: 21, hours: 8)
        let forecast = EnergyForecaster(calendar: clock.calendar).forecast(episodes: episodes, for: day(20))
        let peakTime = try #require(forecast.events.first { $0.kind == .dailyPeak }).time
        let now = EnergyForecaster(calendar: clock.calendar).forecast(episodes: episodes, for: day(20), now: peakTime)
        #expect(abs(forecast.todayPercent - 1) <= 0.02)
        #expect(abs(try #require(now.nowPercent) - 1) <= 0.02)
    }

    @Test func percentIsClampedAndUsesTheScaleFloor() {
        #expect(RestedPeak.percent(1, referencePeak: 13) == 0)
        #expect(RestedPeak.percent(-3, referencePeak: 13) == 0)
        #expect(RestedPeak.percent(7, referencePeak: 13) == 0.5)
        #expect(RestedPeak.percent(20, referencePeak: 13) == 1.05)
    }

    // MARK: Golden test 10

    @Test func lowEnergyFiresOnlyAfterLostSleep() {
        let regular = clock.nightlyEpisodes(firstWakeDay: first, nights: 18, hours: 8)
        let regularDay = wakingCurve(regular, on: day(16))
        #expect(!EventDetector.events(waking: regularDay, bedtime: at(day(16), 23), calendar: clock.calendar)
            .contains { $0.kind == .lowEnergy })

        let deprived = clock.nightlyEpisodes(firstWakeDay: first, nights: 18, hours: 8, skipping: [16])
        let nextDay = wakingCurve(deprived, on: day(16))
        let events = EventDetector.events(waking: nextDay, bedtime: at(day(16), 23), calendar: clock.calendar)
        let low = events.first { $0.kind == .lowEnergy }
        #expect(low != nil)
        #expect((low?.alertness ?? 99) <= p.sleepinessThreshold)
    }

    // MARK: Event detection details

    @Test func prominentMorningPeakDipAndEveningPeakAreDetected() {
        // A synthetic curve with a clear double hump, hourly from 07:00.
        let values: [Double] = [10, 11, 12, 12.5, 12, 11.4, 11, 11.3, 12, 12.8, 12.4, 11, 10, 9, 8, 7.5]
        let samples = values.enumerated().map { index, value in
            AlertnessSample(time: at(day(0), 7 + index), alertness: value, homeostatic: value, circadian: 0,
                            ultradian: 0, inertia: 0, isAsleep: false, confidence: .normal)
        }
        let events = EventDetector.events(waking: samples, bedtime: at(day(0), 23), calendar: clock.calendar)
        func time(_ kind: EnergyEvent.Kind) -> Date? { events.first { $0.kind == kind }?.time }
        #expect(time(.morningPeak) == at(day(0), 10))
        #expect(time(.afternoonDip) == at(day(0), 13))
        #expect(time(.eveningPeak) == at(day(0), 16))
        // The daily peak coincides with the evening peak and is not repeated.
        #expect(time(.dailyPeak) == nil)
        #expect(time(.lowEnergy) == nil)
    }

    @Test func flatBumpsBelowProminenceAreIgnored() {
        let values: [Double] = [10, 10.2, 10.1, 10.25, 10.3, 10.4, 10.2]
        let maxima = EventDetector.localExtrema(values, maxima: true)
        #expect(maxima == [1, 5])
        #expect(abs(EventDetector.prominence(values, 1, maxima: true) - 0.1) < 1e-9)
        #expect(abs(EventDetector.prominence(values, 5, maxima: true) - 0.2) < 1e-9)
    }

    // MARK: Habitual schedule

    @Test func habitualMediansHandleBedtimesAroundMidnight() {
        let onsets = [(22, 30), (23, 30), (0, 30), (1, 0), (23, 0)]
        let episodes = onsets.enumerated().flatMap { index, onset in
            clock.nightlyEpisodes(firstWakeDay: day(index), nights: 1,
                                  onset: ClockTime(hour: onset.0, minute: onset.1), hours: 8)
        }
        let schedule = HabitualSchedule.from(days: days(episodes, through: day(4)), through: day(4),
                                             calendar: clock.calendar)
        #expect(schedule.onset == ClockTime(hour: 23, minute: 30))
        #expect(schedule.wake == ClockTime(hour: 7, minute: 30))
        #expect(schedule.midSleep == ClockTime(hour: 3, minute: 30))
        #expect(abs(schedule.acrophaseHours() - 17.3) < 1e-9)
        #expect(schedule.confidence == .normal)
    }

    @Test func habitualScheduleNeedsFiveDaysAndClampsThePhase() {
        let few = clock.nightlyEpisodes(firstWakeDay: first, nights: 4, hours: 8)
        #expect(HabitualSchedule.from(days: days(few, through: day(3)), through: day(3), calendar: clock.calendar)
            .isDefault)

        let shiftWorker = clock.nightlyEpisodes(firstWakeDay: first, nights: 7, onset: ClockTime(hour: 5, minute: 0),
                                                hours: 8)
        let schedule = HabitualSchedule.from(days: days(shiftWorker, through: day(6)), through: day(6),
                                             calendar: clock.calendar)
        #expect(schedule.midSleep == ClockTime(hour: 9, minute: 0))
        #expect(abs(schedule.acrophaseHours() - 20.8) < 1e-9)
    }

    // MARK: Nights with no data

    @Test func missingNightsAreFilledWithAHabitualNightAndFlaggedLowConfidence() {
        let episodes = clock.nightlyEpisodes(firstWakeDay: first, nights: 22, hours: 8, skipping: [17, 18, 19])
        let forecaster = EnergyForecaster(calendar: clock.calendar)
        let inGap = forecaster.forecast(episodes: episodes, for: day(18))
        #expect(inGap.confidence == .low)
        #expect(inGap.wake == at(day(18), 7))
        #expect(!inGap.events.contains { $0.kind == .lowEnergy })

        let full = clock.nightlyEpisodes(firstWakeDay: first, nights: 22, hours: 8)
        let reference = forecaster.forecast(episodes: full, for: day(18))
        #expect(abs(inGap.todayPercent - reference.todayPercent) < 1e-9)

        let afterGap = forecaster.forecast(episodes: episodes, for: day(21))
        #expect(afterGap.confidence == .normal)
    }

    @Test func noDataAtAllGivesALowConfidenceDefaultForecast() {
        let forecast = EnergyForecaster(calendar: clock.calendar).forecast(episodes: [], for: day(0))
        #expect(forecast.schedule.isDefault)
        #expect(forecast.confidence == .low)
        #expect(abs(forecast.todayPercent - 1) <= 0.02)
    }

    // MARK: Sleep regularity

    @Test func perfectlyRegularSleepScoresOneHundred() throws {
        let episodes = clock.nightlyEpisodes(firstWakeDay: first, nights: 16, hours: 8)
        let result = try #require(SleepRegularity.index(days: days(episodes, through: day(15)), through: day(13),
                                                        calendar: clock.calendar))
        #expect(abs(result.index - 100) < 1e-9)
    }

    @Test func alternatingSchedulesScoreOneThird() throws {
        // Nights alternate 23:00–07:00 and 03:00–11:00: consecutive days differ for 8 h of every 24 h,
        // so P = 2/3 and SRI = 200·(2/3 − 1/2) = 33.3.
        let episodes = (0..<16).flatMap { index in
            clock.nightlyEpisodes(firstWakeDay: day(index), nights: 1,
                                  onset: ClockTime(hour: index % 2 == 0 ? 23 : 3, minute: 0), hours: 8)
        }
        let result = try #require(SleepRegularity.index(days: days(episodes, through: day(15)), through: day(13),
                                                        calendar: clock.calendar))
        #expect(abs(result.index - 100.0 / 3) < 1e-9)
    }

    @Test func regularityNeedsSevenDays() {
        let episodes = clock.nightlyEpisodes(firstWakeDay: first, nights: 6, hours: 8)
        #expect(SleepRegularity.index(days: days(episodes, through: day(5)), through: day(5),
                                      calendar: clock.calendar) == nil)
    }
}
