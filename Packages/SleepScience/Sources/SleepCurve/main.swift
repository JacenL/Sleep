import Foundation
import SleepScience

// Prints one day of the predicted alertness curve as CSV, for eyeballing against the papers' figures.
// Sleep is used exactly as given: nights with no data are NOT filled, so a skipped night is a night awake.

let usage = """
usage: sleep-curve [--preset regular|short|deprived|shifted] [--history FILE.csv] [--day YYYY-MM-DD]
                   [--need HOURS] [--tz IDENTIFIER] [--step MINUTES] [--inertia] [--no-brake]

  --preset    built-in 21-night history ending on --day (default: regular)
                regular   23:00–07:00 every night
                short     14 nights of 01:00–07:00 after 7 regular nights
                deprived  regular, but no sleep the night before --day
                shifted   7 regular nights, then 14 nights of 01:00–09:00
  --history   CSV of asleep intervals: start,end as ISO 8601 with offset (header optional);
              an optional third column inBed|asleep|awake and fourth column manual
  --day       the day to print, in --tz (default: 2026-04-21)
  --need      sleep need N in hours (default: 8)
  --tz        time zone identifier (default: the machine's)
  --step      minutes between rows (default: 5)
  --inertia   add sleep inertia W (off in v1)
  --no-brake  use the original exponential sleep recovery
"""

@MainActor func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data((message + "\n\n" + usage + "\n").utf8))
    exit(2)
}

var options: [String: String] = [:]
var flags: Set<String> = []
var arguments = CommandLine.arguments.dropFirst()
while let argument = arguments.popFirst() {
    switch argument {
    case "--inertia", "--no-brake": flags.insert(argument)
    case "-h", "--help": print(usage); exit(0)
    case "--preset", "--history", "--day", "--need", "--tz", "--step":
        guard let value = arguments.popFirst() else { fail("missing value for \(argument)") }
        options[argument] = value
    default: fail("unknown argument \(argument)")
    }
}

var calendar = Calendar(identifier: .gregorian)
if let identifier = options["--tz"] {
    guard let zone = TimeZone(identifier: identifier) else { fail("unknown time zone \(identifier)") }
    calendar.timeZone = zone
}

let dayParts = (options["--day"] ?? "2026-04-21").split(separator: "-").compactMap { Int($0) }
guard dayParts.count == 3,
      let target = calendar.date(from: DateComponents(year: dayParts[0], month: dayParts[1], day: dayParts[2]))
else { fail("--day must be YYYY-MM-DD") }
guard let need = Double(options["--need"] ?? "8"), DisplayConventions.sleepNeedRangeHours.contains(need)
else { fail("--need must be between 6 and 10") }
guard let stepMinutes = Double(options["--step"] ?? "5"), stepMinutes > 0 else { fail("--step must be positive") }

@MainActor func night(endingOn day: Date, onset: ClockTime, hours: Double) -> SleepSample {
    let previous = calendar.date(byAdding: .day, value: -1, to: day)!
    let start = onset.on(day: onset.hour >= 12 ? previous : day, in: calendar)!
    return SleepSample(start: start, end: start.addingTimeInterval(hours * 3600), kind: .asleep, source: "preset")
}

@MainActor func presetSamples(_ name: String) -> [SleepSample] {
    let regular = ClockTime(hour: 23, minute: 0)
    let late = ClockTime(hour: 1, minute: 0)
    return (0..<21).compactMap { index -> SleepSample? in
        let day = calendar.date(byAdding: .day, value: index - 20, to: target)!
        switch name {
        case "regular": return night(endingOn: day, onset: regular, hours: 8)
        case "short": return index < 7 ? night(endingOn: day, onset: regular, hours: 8)
                                       : night(endingOn: day, onset: late, hours: 6)
        case "deprived": return index == 20 ? nil : night(endingOn: day, onset: regular, hours: 8)
        case "shifted": return index < 7 ? night(endingOn: day, onset: regular, hours: 8)
                                         : night(endingOn: day, onset: late, hours: 8)
        default: fail("unknown preset \(name)")
        }
    }
}

@MainActor func historySamples(_ path: String) -> [SleepSample] {
    guard let text = try? String(contentsOfFile: path, encoding: .utf8) else { fail("cannot read \(path)") }
    let parser = ISO8601DateFormatter()
    return text.split(whereSeparator: \.isNewline).enumerated().compactMap { number, line in
        let fields = line.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        guard fields.count >= 2, let start = parser.date(from: fields[0]), let end = parser.date(from: fields[1]) else {
            if number == 0 { return nil }
            fail("line \(number + 1): expected start,end in ISO 8601")
        }
        let kind: SleepSample.Kind = switch fields.count > 2 ? fields[2] : "asleep" {
        case "inBed": .inBed
        case "awake": .awake
        default: .asleep
        }
        return SleepSample(start: start, end: end, kind: kind, source: "csv",
                           isManual: fields.count > 3 && fields[3] == "manual")
    }
}

let samples = options["--history"].map(historySamples) ?? presetSamples(options["--preset"] ?? "regular")
let episodes = EpisodeMerger.episodes(from: samples)
let firstDay = episodes.map { calendar.startOfDay(for: $0.end) }.min() ?? target
let days = DayAssigner.days(from: episodes, firstDay: min(firstDay, target), lastDay: target, calendar: calendar)
let schedule = HabitualSchedule.from(days: days, through: target, calendar: calendar)

var parameters = ThreeProcessParameters.published
parameters.includeSleepInertia = flags.contains("--inertia")
parameters.brakeEnabled = !flags.contains("--no-brake")
let model = ThreeProcessModel(parameters: parameters)
let acrophase = schedule.acrophaseHours(parameters: parameters)
let input = AlertnessInput(sleep: episodes.flatMap(\.fragments), sleepNeedHours: need, acrophaseHours: acrophase,
                           calendar: calendar)

let dayStart = calendar.startOfDay(for: target)
let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!
let curve = model.predict(input, from: dayStart, to: dayEnd.addingTimeInterval(-1), step: stepMinutes * 60)

let wake = days.last?.mainSleep.map(\.end).max() ?? schedule.wake.on(day: dayStart, in: calendar)!
let bedtime = schedule.onset.nextOccurrence(atOrAfter: wake.addingTimeInterval(60), in: calendar)!
let waking = model.predict(input, from: wake, to: bedtime, step: DisplayConventions.sampleInterval)
let events = EventDetector.events(waking: waking, bedtime: bedtime, calendar: calendar, parameters: parameters)

let timeFormatter = ISO8601DateFormatter()
timeFormatter.timeZone = calendar.timeZone
timeFormatter.formatOptions = [.withInternetDateTime]

print("# schedule: onset \(schedule.onset) wake \(schedule.wake) mid-sleep \(schedule.midSleep)"
      + (schedule.isDefault ? " (default)" : " (\(schedule.daysUsed) days)")
      + String(format: "; acrophase %.2f h; N %.1f h; brake %@; inertia %@", acrophase, need,
               parameters.brakeEnabled ? "on" : "off", parameters.includeSleepInertia ? "on" : "off"))
for event in events {
    let value = event.alertness.map { String(format: " A=%.2f", $0) } ?? ""
    print("# event: \(event.kind) \(timeFormatter.string(from: event.time))\(value)")
}
print("time,S,C,U,W,A,asleep")
for sample in curve {
    print(String(format: "%@,%.3f,%.3f,%.3f,%.3f,%.3f,%d", timeFormatter.string(from: sample.time),
                 sample.homeostatic, sample.circadian, sample.ultradian, sample.inertia, sample.alertness,
                 sample.isAsleep ? 1 : 0))
}
