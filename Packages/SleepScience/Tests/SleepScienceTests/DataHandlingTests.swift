import Foundation
import Testing
@testable import SleepScience

/// Golden test 8 (SCIENCE.md section 9) and the section 3 merging rules.
struct DataHandlingTests {
    let clock = TestClock()

    @Test func overlappingSourcesUnionIntoOneEpisode() {
        let samples = [
            SleepSample(start: clock.date(2026, 5, 1, 23), end: clock.date(2026, 5, 2, 7), kind: .asleep, source: "watch"),
            SleepSample(start: clock.date(2026, 5, 1, 23, 30), end: clock.date(2026, 5, 2, 7, 30), kind: .asleep, source: "phone"),
        ]
        let episodes = EpisodeMerger.episodes(from: samples)
        #expect(episodes.count == 1)
        #expect(episodes[0].start == clock.date(2026, 5, 1, 23))
        #expect(episodes[0].end == clock.date(2026, 5, 2, 7, 30))
        #expect(episodes[0].asleepDuration == .hours(8.5))
        #expect(episodes[0].quality == .recorded)
    }

    @Test func shortWakeIsSubtractedButJoined() {
        let samples = [
            SleepSample(start: clock.date(2026, 5, 1, 23), end: clock.date(2026, 5, 2, 7), kind: .asleep, source: "watch"),
            SleepSample(start: clock.date(2026, 5, 2, 2), end: clock.date(2026, 5, 2, 2, 20), kind: .awake, source: "watch"),
        ]
        let episodes = EpisodeMerger.episodes(from: samples)
        #expect(episodes.count == 1)
        #expect(episodes[0].fragments.count == 2)
        #expect(episodes[0].asleepDuration == .hours(8) - .minutes(20))
    }

    @Test func wakeOfThirtyMinutesOrMoreSplitsEpisodes() {
        let samples = [
            SleepSample(start: clock.date(2026, 5, 1, 23), end: clock.date(2026, 5, 2, 7), kind: .asleep, source: "watch"),
            SleepSample(start: clock.date(2026, 5, 2, 2), end: clock.date(2026, 5, 2, 2, 30), kind: .awake, source: "watch"),
        ]
        #expect(EpisodeMerger.episodes(from: samples).count == 2)
    }

    @Test func inBedOnlyIsEstimatedAndUncorrected() {
        let samples = [
            SleepSample(start: clock.date(2026, 5, 1, 23), end: clock.date(2026, 5, 2, 7), kind: .inBed, source: "phone"),
            SleepSample(start: clock.date(2026, 5, 2, 3), end: clock.date(2026, 5, 2, 3, 10), kind: .awake, source: "phone"),
        ]
        let episodes = EpisodeMerger.episodes(from: samples)
        #expect(episodes.count == 1)
        #expect(episodes[0].quality == .estimated)
        #expect(episodes[0].asleepDuration == .hours(8))
    }

    @Test func inBedIsIgnoredWhereAsleepSamplesExist() {
        let samples = [
            SleepSample(start: clock.date(2026, 5, 1, 22, 30), end: clock.date(2026, 5, 2, 7, 30), kind: .inBed, source: "phone"),
            SleepSample(start: clock.date(2026, 5, 1, 23), end: clock.date(2026, 5, 2, 7), kind: .asleep, source: "watch"),
        ]
        let episodes = EpisodeMerger.episodes(from: samples)
        #expect(episodes.count == 1)
        #expect(episodes[0].quality == .recorded)
        #expect(episodes[0].asleepDuration == .hours(8))
    }

    @Test func manualEntryOverridesRecordedTime() {
        let samples = [
            SleepSample(start: clock.date(2026, 5, 1, 23), end: clock.date(2026, 5, 2, 7), kind: .asleep, source: "watch"),
            SleepSample(start: clock.date(2026, 5, 2, 1), end: clock.date(2026, 5, 2, 1, 40), kind: .awake, source: "watch"),
            SleepSample(start: clock.date(2026, 5, 2, 0), end: clock.date(2026, 5, 2, 6), kind: .inBed, source: "me", isManual: true),
        ]
        let episodes = EpisodeMerger.episodes(from: samples)
        #expect(episodes.count == 1)
        // The watch's 40 min awake inside the manual entry is overridden by the user's statement.
        #expect(episodes[0].asleepDuration == .hours(8))
        #expect(episodes[0].source == .mixed)
    }

    @Test func manualOnlyEpisode() {
        let samples = [SleepSample(start: clock.date(2026, 5, 1, 23), end: clock.date(2026, 5, 2, 6), kind: .asleep,
                                   source: "me", isManual: true)]
        let episode = EpisodeMerger.episodes(from: samples)[0]
        #expect(episode.quality == .manual)
        #expect(episode.source == .manual)
    }

    @Test func midnightCrossingEpisodeBelongsToDayItEnds() {
        let episode = SleepEpisode(fragments: [DateInterval(start: clock.date(2026, 5, 1, 23), end: clock.date(2026, 5, 2, 7))],
                                   quality: .recorded, source: .healthKit)
        #expect(DayAssigner.day(of: episode, in: clock.calendar) == clock.day(2026, 5, 2))
    }

    @Test func dstSpringForwardNightIsSevenRealHours() {
        // 2026-03-08 02:00 EST jumps to 03:00 EDT in New York.
        let samples = [SleepSample(start: clock.date(2026, 3, 7, 23), end: clock.date(2026, 3, 8, 7), kind: .asleep, source: "watch")]
        let episode = EpisodeMerger.episodes(from: samples)[0]
        #expect(episode.asleepDuration == .hours(7))
        #expect(DayAssigner.day(of: episode, in: clock.calendar) == clock.day(2026, 3, 8))
        let days = DayAssigner.days(from: [episode], firstDay: clock.day(2026, 3, 7), lastDay: clock.day(2026, 3, 9),
                                    calendar: clock.calendar)
        #expect(days.map(\.hasData) == [false, true, false])
        #expect(days[1].totalSleep == .hours(7))
    }

    @Test func dayAssignmentFollowsTheSuppliedTimeZone() {
        let utc = TestClock(timeZone: "UTC")
        let end = utc.date(2026, 6, 1, 22)  // 23:00 in London (BST), 07:00 on 2 June in Tokyo
        let episode = SleepEpisode(fragments: [DateInterval(start: end.addingTimeInterval(-.hours(8)), end: end)],
                                   quality: .recorded, source: .healthKit)
        let london = TestClock(timeZone: "Europe/London")
        let tokyo = TestClock(timeZone: "Asia/Tokyo")
        #expect(DayAssigner.day(of: episode, in: london.calendar) == london.day(2026, 6, 1))
        #expect(DayAssigner.day(of: episode, in: tokyo.calendar) == tokyo.day(2026, 6, 2))
    }

    @Test func napsAreShortAndEndInTheDaytime() {
        func episode(_ start: Date, _ end: Date) -> SleepEpisode {
            SleepEpisode(fragments: [DateInterval(start: start, end: end)], quality: .recorded, source: .healthKit)
        }
        let nap = episode(clock.date(2026, 5, 2, 14), clock.date(2026, 5, 2, 14, 40))
        let eveningDoze = episode(clock.date(2026, 5, 2, 19), clock.date(2026, 5, 2, 21))
        let longDaySleep = episode(clock.date(2026, 5, 2, 11), clock.date(2026, 5, 2, 15))
        #expect(DayAssigner.isNap(nap, in: clock.calendar))
        #expect(!DayAssigner.isNap(eveningDoze, in: clock.calendar))
        #expect(!DayAssigner.isNap(longDaySleep, in: clock.calendar))

        let night = episode(clock.date(2026, 5, 1, 23), clock.date(2026, 5, 2, 6))
        let day = DayAssigner.days(from: [night, nap], firstDay: clock.day(2026, 5, 2), lastDay: clock.day(2026, 5, 2),
                                   calendar: clock.calendar)[0]
        #expect(day.naps.count == 1)
        #expect(day.totalSleep == .hours(7) + .minutes(40))
    }

    @Test func threeDayGapProducesDaysWithoutData() {
        let episodes = clock.nightlyEpisodes(firstWakeDay: clock.day(2026, 5, 1), nights: 7, hours: 8, skipping: [2, 3, 4])
        let days = DayAssigner.days(from: episodes, firstDay: clock.day(2026, 5, 1), lastDay: clock.day(2026, 5, 7),
                                    calendar: clock.calendar)
        #expect(days.map(\.hasData) == [true, true, false, false, false, true, true])
    }
}
