# Roadmap

Build in this order. Each milestone ends with something that runs and is
verified. Do not start a milestone until the previous one meets its
definition of done.

## M0 — Skeleton

- `brew install xcodegen`; `git init`; `.gitignore` (Xcode, `*.xcodeproj`,
  `.build`, `DerivedData`).
- `project.yml`: app target `Sleep` (iOS 26, iPhone), local package
  `Packages/SleepScience`, test targets, Swift 6 strict concurrency.
  Bundle identifier and development team are supplied by the user.
- `Info.plist` keys and entitlements declared but unused: HealthKit,
  HealthKit background delivery, `NSHealthShareUsageDescription`,
  `NSHealthUpdateUsageDescription`, background modes.
- Empty three-tab shell with the design system's palette and type.

Done when: `swift test` passes on an empty package, the app builds and
launches in the iPhone 17 Pro simulator showing three tabs.

## M1 — Science package

Implement `docs/SCIENCE.md` sections 2–9 in `Packages/SleepScience`, with
no app code.

- Before coding, verify every `UNVERIFIED` parameter against the primary
  papers. Report to the user which were confirmed, corrected, or could not
  be checked.
- Types: `SleepEpisode`, `SleepDay`, `AlertnessSample`, `EnergyEvent`,
  `DebtLedger`, `Confidence`.
- `AlertnessModel` protocol; `ThreeProcessModel`; `Parameters.swift`;
  `DisplayConventions.swift`.
- Episode merging, day assignment, habitual schedule, debt ledger, event
  detection, percent-of-rested-peak, regularity index.
- All golden tests from SCIENCE.md section 9.
- A small command-line executable target that prints a day's curve as
  CSV for a given sleep history, for eyeballing against the papers' figures.

Done when: all golden tests pass and the user has seen the parameter
verification report.

## M2 — Data layer

- SwiftData models for manual sleep entries and settings.
- `SleepStore` protocol with `HealthKitSleepStore`, `ManualSleepStore`, a
  merging `CombinedSleepStore`, and an in-memory fake with fixture
  histories (regular sleeper, short sleeper, irregular, sparse, empty).
- HealthKit authorisation flow, anchored queries, observer query with
  background delivery.
- Manual tracking: start/stop sleep, add/edit/delete an entry.

Done when: unit tests cover merging and fixtures; in the simulator, sleep
added in the Health app appears in a debug list, and manual entries persist
across relaunch.

## M3 — Today

Build the Today screen per `docs/DESIGN.md`, driven by fixtures first, then
live data. Energy map, headline ring, stat tiles, next-up, empty and
permission-denied states.

Done when: verified in the simulator in dark and light mode with each
fixture history and at the largest Dynamic Type size.

## M4 — Sleep

Timeline, Month, Day detail, entry editor.

Done when: verified with fixtures including a midnight-crossing night, a
nap day, a no-data gap, and a DST change week.

## M5 — Notifications

- `NotificationScheduler`: schedules the next 48 h of events, replaces all
  pending requests on any data or settings change, respects quiet hours and
  per-event toggles.
- Background refresh so tomorrow's schedule is set after the night's sleep
  lands in HealthKit.
- Unit tests against a fake notification centre.

Done when: tests pass and a scheduled notification is observed firing in
the simulator. Note for the user: background delivery timing can only be
confirmed on a real device over a few days.

## M6 — Insights, onboarding, settings, polish

Insights screen, "How this is calculated", onboarding, settings, CSV
export, accessibility pass, app icon.

Done when: a fresh install can be walked from onboarding to a populated
Today screen with permissions denied and with permissions granted.

## Later (not scheduled)

- v2 alertness model for chronic restriction (SCIENCE.md section 4).
- Home Screen and Lock Screen widgets; Live Activity for the next event.
- Suggested sleep need from unconstrained days.
- Caffeine logging, only with a published pharmacokinetic model.
- Apple Watch complication.

## Things only the user can do

- Sign in to Xcode with an Apple ID and choose a development team. A free
  account works for a personal device but the app must be re-installed
  every 7 days; the paid developer programme extends that to a year.
- Trust the developer profile on the iPhone and enable Developer Mode.
- Grant Health and notification permissions on the device.
- Decide the sleep-need setting.
