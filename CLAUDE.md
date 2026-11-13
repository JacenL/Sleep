# Sleep — personal iOS sleep & energy app

A native iPhone app, for one user (the owner), that records sleep, shows a
calendar/timeline of it, and predicts daytime alertness ("energy") from
published biomathematical sleep models. Runs entirely on-device: no server,
no account, no analytics.

Read these before touching the matching area. They are the source of truth:

- `docs/SCIENCE.md` — the models, equations, parameters, citations, and what
  we may and may not claim. Read before any change in `Packages/SleepScience`.
- `docs/DESIGN.md` — screens, visual language, copy rules. Read before UI work.
- `docs/ROADMAP.md` — build order and the definition of done for each
  milestone. Work on one milestone at a time, in order.

## Stack

- Swift 6, SwiftUI, iOS 26 deployment target, Xcode 26. iPhone only.
- Swift Charts for every chart. SwiftData for local storage.
- HealthKit (read sleep analysis; write only the user's manual entries).
- UserNotifications, local only. No push, no server.
- No third-party dependencies. If one seems necessary, stop and ask.
- XcodeGen: `project.yml` is the source of truth for the Xcode project.
  Never hand-edit `Sleep.xcodeproj`; edit `project.yml` and run `xcodegen`.
  The `.xcodeproj` is git-ignored.

## Layout

```
project.yml                 XcodeGen spec
App/                        app target: SwiftUI views, view models, app wiring
  Features/Today/           energy curve, % of rested peak, debt, next event
  Features/Sleep/           calendar heat map, 24h timeline, entry editor
  Features/Insights/        trends, regularity, how-this-is-calculated
  Features/Settings/
  Services/                 HealthKitSleepStore, NotificationScheduler, etc.
  DesignSystem/             colors, type, spacing, shared components
Packages/SleepScience/      pure Swift package. No UIKit/SwiftUI/HealthKit imports.
  Sources/SleepScience/     models, debt ledger, event detection, parameters
  Tests/SleepScienceTests/  unit + golden tests
docs/                       SCIENCE.md, DESIGN.md, ROADMAP.md
```

The hard boundary: **all science lives in `Packages/SleepScience`** and takes
plain value types in (sleep intervals, a sleep-need setting, a time range) and
returns plain value types out (alertness samples, events, debt). The app
target never contains a model constant or an equation. This keeps the science
testable with `swift test` in seconds, with no simulator.

## Commands

```
swift test --package-path Packages/SleepScience      # science tests; run after every science change
xcodegen                                             # regenerate project after project.yml or file adds
xcodebuild -project Sleep.xcodeproj -scheme Sleep \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
xcodebuild ... test                                  # app-level tests
```

A change is not done until the science tests pass and the app builds for the
simulator. For UI changes, also launch in the simulator and look at the screen
in both a data-rich and an empty state before calling it finished.

## Scientific rigor rules

These exist because the app's whole value is that its numbers are honest.
A plausible-looking number with no source is worse than no number.

1. **Every constant has a citation.** Model parameters live only in
   `Parameters.swift`, each with a doc comment naming the paper and the table
   or equation it came from. `docs/SCIENCE.md` marks some values
   `UNVERIFIED`: those were written from memory and must be checked against
   the primary paper before they ship. If you cannot access the paper, leave
   the tag in place and tell the user; do not silently treat it as confirmed.
2. **Never invent a formula.** If the spec does not cover a case, stop and
   ask rather than improvising something reasonable-sounding. Where the app
   needs a display convention that is not science (for example mapping the
   alertness scale to a percentage), it goes in `DisplayConventions.swift`,
   labelled as a convention, and is described as such in the in-app
   "How this is calculated" screen.
3. **Models sit behind the `AlertnessModel` protocol** so the v1 model can be
   replaced by a better one without touching the UI.
4. **Golden tests encode published behaviour**, listed in `docs/SCIENCE.md`.
   If a golden test fails after your change, the change is wrong until shown
   otherwise; do not loosen the test to make it pass.
5. **Claims in UI copy are limited** to what `docs/SCIENCE.md` section
   "What we can claim" allows. Predictions are estimates from group-average
   models: say "predicted", "estimated", "likely". No medical claims, no
   diagnosis, no sleep-stage scoring of our own.
6. **Time is handled with `Date` and `Calendar` only.** No arithmetic on
   hour-of-day doubles outside the science package's own circadian phase
   maths. Sleep that crosses midnight, DST changes, and time-zone travel all
   need tests. A sleep episode belongs to the day on which it ends.

## Code conventions

- Swift 6 strict concurrency on. `@Observable` view models, `@MainActor` UI.
- Views stay small and dumb: they render view-model state. No HealthKit or
  science calls from a `View` body.
- Services are protocols with a real and an in-memory fake implementation so
  previews and tests never need HealthKit or the notification centre.
- Every screen has SwiftUI previews for: typical data, no data, and
  permission denied.
- HealthKit read permission cannot be queried; an empty result may mean
  "denied". Always design the empty state to offer manual logging.
- Keep the pending notification count well under iOS's limit of 64: schedule
  at most the next 48 hours and reschedule whenever sleep data changes.
- Comments explain why, not what. No commented-out code.

## Usage limits

This project is built by one person on a single Claude Pro subscription.
There is no second account and no API budget.

- Never suggest, enable, or rely on paid extra usage, API billing, or a plan
  upgrade. If the usage limit is reached, the work simply pauses until the
  limit resets, and continues in the next session.
- Because a session can end abruptly at the limit, keep work resumable:
  finish one small step at a time, leave the build and tests passing between
  steps, and when a milestone is partly done, state exactly what is finished
  and what is left so a fresh session can pick it up from the docs and the
  code alone.
- Be economical: read only the files a task needs, and do not spawn
  subagents or run broad searches where a targeted read will do.

## Git and GitHub

The remote is `origin`, https://github.com/JacenL/Sleep (public). The default
branch is `main`. This is a solo project: no pull requests or reviews are
required.

- **The repo is public.** Never commit anything personal or secret: real
  sleep data, CSV exports, HealthKit dumps, screenshots containing real data,
  signing certificates, provisioning profiles, tokens, or `.env` files. Test
  fixtures use invented data only. If a file like that needs to exist locally,
  add it to `.gitignore` first.
- **Commit identity** is already set for this repo to GitHub's private
  noreply address. Do not change `user.email`, and do not write the owner's
  real email address into any file or commit message.
- **Branching:** do each milestone on a branch named `m<n>-<short-name>`
  (for example `m2-data-layer`). When the user accepts the milestone,
  fast-forward `main` to it, push `main`, and delete the branch. Keep `main`
  always building with tests passing.
- **Commits:** small, one concern each, in the order the work makes sense to
  read. Subject line in the imperative, under about 70 characters ("Add debt
  ledger"), with a body only when the why is not obvious. Run the science
  tests and the simulator build before committing.
- **Commit only when asked. Push only when asked.** "Commit this" does not
  mean push.
- **Never rewrite pushed history:** no force-push, no amend or rebase of
  commits already on `origin`. Fix mistakes with a new commit. If something
  private is pushed by accident, stop and tell the user immediately rather
  than trying to hide it.
- **Never commit generated files:** `Sleep.xcodeproj`, `.build/`,
  `DerivedData/` (already git-ignored).

## Working agreement

- Ask before: adding a dependency, changing a model or a parameter, adding a
  HealthKit data type, or anything that changes what a number on screen means.
- Commit and push only when asked; see "Git and GitHub" below.
- When a milestone in `docs/ROADMAP.md` is complete, say what was verified
  and how, and what was not.
