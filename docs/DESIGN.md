# Design specification

## Principles

- **One answer per screen.** Today answers "how much energy do I have and
  when does it change?". Sleep answers "how have I been sleeping?".
- **Dark first.** This app is opened at night and on waking. Design in dark
  mode, then verify light mode. No pure white on pure black for large areas.
- **Calm, not gamified.** No streaks, scores out of 100, badges, or red
  alarm states. Low sleep is shown plainly, without scolding.
- **Honest numbers.** Every predicted value is visually distinct from every
  measured value (see "Measured vs predicted"), and every number has a path
  to its definition.
- **Native.** System components, SF Pro, SF Symbols, standard navigation,
  iOS 26 materials. Custom drawing only for the charts.

## Visual language

- Background: near-black indigo. Surfaces: one step lighter, 20 pt corner
  radius, no borders, no drop shadows.
- Two data hues only, defined once in `DesignSystem/Palette.swift` as asset
  colours with light and dark variants:
  - **Sleep**: indigo/violet family.
  - **Energy**: warm amber at high alertness shading to a cool desaturated
    blue at low alertness. This one gradient is reused everywhere energy
    appears (curve fill, ring, calendar tint) so the mapping is learned once.
- Text: primary, secondary, tertiary from system label colours. Check 4.5:1
  contrast for all text and 3:1 for chart marks against their surface.
- Type: SF Pro. Large numerals use the rounded design with monospaced
  digits so values do not jitter as they update.
- Spacing on a 4 pt grid; 16 pt screen margins; 12 pt between cards.
- Motion: charts draw in once on first appearance (about 0.5 s); value
  changes use numeric text transitions. Respect Reduce Motion.
- Never encode meaning by colour alone: peaks and dips also get a symbol
  and a label.

## Measured vs predicted

- Measured (sleep you actually had, the curve up to now): solid line, full
  opacity fill.
- Predicted (curve after now, events not yet reached): same hue, dashed
  line, lighter fill.
- Estimated sleep (in-bed only, see SCIENCE.md section 3): hatched bar.
- Low-confidence output (under 14 days of data): a small "Limited data"
  caption on the card. Do not hide the chart.

## Screens

Tab bar: **Today**, **Sleep**, **Insights**. Settings is reached from a
toolbar button on Today.

### Today

Top to bottom:

1. **Headline**: `now%` as a large numeral with "of your rested peak"
   beneath, inside a thin ring coloured by the energy gradient. Beside it,
   one line of state: "Rising toward your morning peak, about 10:40".
2. **Energy map** (the centrepiece): area chart of predicted alertness from
   today's wake time to tonight's habitual bedtime, extended lightly into
   the night. A vertical "now" rule. Markers for morning peak, afternoon
   dip, evening peak, wind-down. Last night's sleep shown as a sleep-hued
   band on the left edge of the time axis. Scrubbing with a finger shows
   time and value. The y-axis has no numbers; it has two faint guide labels,
   "rested peak" and "low".
3. **Three stat tiles**: Last night (duration, onset–wake), Sleep debt
   (hours and minutes, with a 14-day trend sparkline), Today's capacity
   (`today%`).
4. **Next up**: the next event with a relative time ("Afternoon dip in
   2 h 10 min").
5. If awake state is unknown (no sleep recorded for last night): a single
   prompt card, "When did you sleep?", opening the entry editor.

A "Going to sleep" / "I'm awake" button sits in the bottom toolbar for
manual tracking. It is hidden when HealthKit is supplying nightly data.

### Sleep

1. **Segmented control**: Timeline | Month.
2. **Timeline** (default): one row per day, newest first. Each row is a
   24-hour horizontal axis running noon to noon, so a night is one unbroken
   bar; sleep episodes drawn as rounded bars in the sleep hue, naps
   included. Duration at the row's right edge. A faint vertical guide marks
   habitual onset and wake so irregularity is visible at a glance. This is
   the "daily map".
3. **Month**: calendar grid. Each day cell holds a filled circle whose fill
   level is sleep relative to need (full at or above need), with the
   duration beneath. Days with no data are an empty outline, never zero.
4. Tapping a day opens **Day detail**: that night's episodes (with stages
   if HealthKit supplied them, attributed to the source), that day's energy
   map as it was predicted, and edit/add/delete for manual entries.

### Insights

- 14-day averages: time asleep, onset, wake.
- Sleep debt over time (line), with nightly surplus/deficit bars beneath.
- Regularity index with a one-sentence explanation.
- **How this is calculated**: plain-language description of the model,
  the debt ledger, the percentage convention, the limitations, and the
  reference list from SCIENCE.md. Linked from every info button in the app.

### Settings

Sleep need (stepper, 15-minute steps, with the guidance ranges shown),
notification toggles per event type plus quiet hours, data sources
(HealthKit status, link to the Health app's permissions), export data as
CSV, delete all data.

### Onboarding

Three screens at most: what the app does and that its energy figures are
predictions; sleep need; permissions (Health, then notifications), each
requested at the moment its value is explained. The app must be fully
usable with both denied.

## Copy rules

- Sentence case. Plain words. Times in the user's locale format.
- Durations as "7 h 25 min". Debt as "3 h 10 min", never negative.
- Predictions always carry "predicted", "likely", or "about".
- Notifications: title states the event, body gives one useful fact.
  "Likely at your morning peak" / "Good window for demanding work until
  about 12:30." No exclamation marks, no emoji.
- See SCIENCE.md section 10 for claims that are off limits.

## Accessibility

Dynamic Type to the largest accessibility sizes without truncating key
numbers; VoiceOver labels and audio-graph descriptors on every chart;
minimum 44 pt touch targets; Reduce Motion and Increase Contrast honoured.
