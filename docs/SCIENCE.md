# Science specification

This file defines what the app computes and why. Code in
`Packages/SleepScience` implements this file and nothing else.

Values tagged `UNVERIFIED` were written from memory when this spec was
drafted. Check each against the cited primary source before shipping, then
replace the tag with the table/equation reference. Do not remove a tag
without having read the source.

## 1. What is and is not real

| Concept | Status | Basis |
|---|---|---|
| Sleep pressure builds with time awake and dissipates in sleep (Process S) | Well established | Borbély 1982; Daan 1984; Borbély 2016 |
| A ~24 h circadian rhythm modulates alertness independent of sleep (Process C) | Well established | same; forced-desynchrony studies |
| Grogginess right after waking (sleep inertia, Process W) | Well established | Tassi & Muzet 2000 |
| Early-afternoon dip in alertness | Established, modest, varies by person | Monk 2005 |
| Evening "wake maintenance zone" shortly before habitual bedtime | Established | Lavie 1986 |
| Sleep debt: chronic short sleep causes deficits that accumulate over days | Real. The effect is established; any single number of "hours owed" is a simplification | Van Dongen 2003; Belenky 2003 |
| People under chronic restriction under-rate their own impairment | Established | Van Dongen 2003 |
| Recovery from debt is slower than 1 h per 1 h, and weekend catch-up is incomplete | Supported | Kitamura 2016; Depner 2019 |
| Regular sleep timing matters, separately from duration | Supported | Phillips 2017; Windred 2024 |
| Large stable individual differences in vulnerability to sleep loss | Established | Van Dongen 2004 |
| 90-minute waking "ultradian energy cycles" | Weak evidence. **Not modelled.** | — |
| Sleep "cycles" you should time your alarm to | Not reliable from phone data. **Not modelled.** | — |

Consequences for the product:

- "Energy" in the UI means **predicted alertness** from a group-average
  model. It is not measured. It does not know about caffeine, illness,
  stress, exercise, light exposure, or food.
- Sleep debt is shown as an estimate with its definition one tap away.
- The app never scores sleep stages itself. If HealthKit supplies stages
  from an Apple Watch, they may be displayed, attributed to the source.

## 2. Inputs

- **Sleep episodes**: `[SleepEpisode(start: Date, end: Date, source, quality)]`
  after merging (section 3).
- **Sleep need** `N` in hours. Default 8.0, user-adjustable 6.0–10.0.
  Consensus guidance for adults is at least 7 h (Watson 2015), 7–9 h
  (Hirshkowitz 2015); teenagers need more (8–10 h). Individual need varies
  and cannot be measured by the app. A later milestone may *suggest* a value
  from sleep on unconstrained days, but only the user sets it.
- **Habitual schedule**: derived, median sleep onset, wake time and mid-sleep
  over the last 14 days with data (at least 5 required, otherwise defaults
  of 23:00–07:00).

## 3. Sleep data handling

HealthKit `sleepAnalysis` samples arrive from several sources and overlap.

1. Prefer `asleep*` samples (`asleepUnspecified`, `asleepCore`,
   `asleepDeep`, `asleepREM`). Use `inBed` only for periods with no asleep
   samples from any source.
2. Union overlapping asleep intervals; subtract `awake` samples.
3. Join fragments separated by less than 30 min of wake into one episode;
   time asleep is the sum of asleep time, not episode span.
4. `inBed`-only episodes are marked `quality: .estimated` and counted as
   sleep without correction. Do not apply a made-up efficiency factor. Show
   the "estimated" flag in the UI.
5. Manual entries are the user's stated truth and override HealthKit for
   overlapping time.
6. An episode belongs to the calendar day (user's current time zone) in
   which it **ends**. Episodes shorter than 3 h that end between 10:00 and
   20:00 are naps: they count toward that day's total and feed the model
   normally.

## 4. Alertness model (v1): Three-Process Model

Source: Åkerstedt & Folkard 1997; Åkerstedt, Folkard & Portin 2004. It
extends the two-process model (Borbély 1982) and was validated against
subjective alertness and performance. Output is on a 1–21 scale where
roughly 7 and below marks significant sleepiness risk `UNVERIFIED`.

Predicted alertness at time `t`:

```
A(t) = S(t) + C(t) + U(t) + W(t)
```

**S — homeostatic component.** `τ` is hours since the last state change.

```
awake:   S(τ) = ha − (ha − S_wake)  · e^(d·τ)
asleep:  S(τ) = ha − (ha − S_sleep) · e^(g·τ)
```

`S_wake` is S at the moment of waking, `S_sleep` is S at sleep onset. S is
integrated continuously across the whole sleep history, so short nights
carry into following days.

**C — circadian component** and **U — 12 h component** (produces the
afternoon dip). `h` is local clock time in hours, `p` the acrophase.

```
C(h) = Cm + Ca · cos( 2π (h − p) / 24 )
U(h) = Um + Ua · cos( 2π (h − p − 3) / 12 )
```

**W — sleep inertia**, `τ` hours since waking:

```
W(τ) = Wc · e^(Wd·τ)
```

Parameters (all `UNVERIFIED` — confirm against Åkerstedt & Folkard 1997 and
the 2004 paper; note the later papers describe a modified two-phase sleep
recovery function, decide which version to implement and record it here):

| Symbol | Value | Meaning |
|---|---|---|
| ha | 14.3 | upper asymptote of S |
| la | 2.4 | lower asymptote of S |
| d | −0.0353 /h | decay of S while awake |
| g | −0.381 /h | recovery of S while asleep |
| Cm, Ca | 0, 2.5 | circadian mesor, amplitude |
| p | 16.8 h | circadian acrophase (default) |
| Um, Ua | −0.5, 0.5 | 12 h component mesor, amplitude |
| Wc, Wd | −5.72, −1.51 /h | inertia magnitude, decay |

**Initial condition.** Start the simulation 14 days before the first day
displayed, with S at the model's steady-state wake value for a regular
`N`-hour schedule. With less than 14 days of history, fill missing earlier
nights with the habitual schedule and mark output `lowConfidence`.

**Personalising phase.** The default `p = 16.8` assumes a conventional
schedule. Shift it by the user's habitual mid-sleep relative to a reference
mid-sleep of 03:00: `p_user = 16.8 + (midSleep − 3.0)`, clamped to ±4 h.
This is a **heuristic** in the spirit of chronotype-from-mid-sleep
(Roenneberg 2003), not a measured circadian phase. Use the 14-day median so
one late night does not move the curve. Label it as a heuristic in-app.

**Known limitation.** Under sustained restriction this model's S settles to
a new steady state within a few days, whereas laboratory data show deficits
still growing after two weeks (Van Dongen 2003). So v1 understates the cost
of long-running debt. That is why debt is shown as its own number (section
5) and why the model sits behind a protocol.

**v2 candidate.** The unified model of performance (Rajdev 2013) or
McCauley 2013, both designed to reproduce chronic restriction and total
deprivation together. Implement only from the papers' published equations
and parameters, as a second `AlertnessModel`, and compare against v1 with
the golden tests before switching.

## 5. Sleep debt

Laboratory definition: cumulative sleep lost relative to need over a period
of restriction (Van Dongen 2003 used 14 days). There is no agreed formula
for free-living data, so the app uses a transparent ledger and says so.

```
debt_0 = 0                                     (14 days before today)
debt_d = clamp( debt_{d−1} + (N − sleep_d), 0, 14·N/2 )
```

- `sleep_d` is total time asleep in episodes ending on day `d`.
- Surplus sleep pays debt down hour for hour but debt never goes below
  zero: evidence for "banking" sleep is limited, so the app does not credit
  it. Real recovery is slower than hour for hour (Kitamura 2016); the
  ledger is therefore optimistic about recovery and the explainer says so.
- Days with no data are skipped (debt unchanged) and reduce confidence.
- Window: 14 days. Display in hours and minutes, with the nightly
  contributions listed so the user can see where it came from.

This ledger is a **convention**, documented as such. It does not feed the
alertness model in v1; the model sees the same sleep history directly.

## 6. "Percent of maximal energy"

Not a scientific quantity. Display convention, defined as:

```
A_ref  = peak A(t) over a waking day in a reference simulation: the user's
         habitual schedule, sleeping exactly N hours for 14 days
now%   = clamp( (A(now)        − 1) / (A_ref − 1), 0, 1.05 )
today% = clamp( (peak A today  − 1) / (A_ref − 1), 0, 1.05 )
```

`1` is the bottom of the model's scale. `today%` is "the most you are
likely to reach today compared with a well-rested you"; `now%` is the
current point on the curve. Show `today%` as the headline capacity figure
and `now%` as the live value. Copy: "of your rested peak", never "of your
maximum potential" or anything implying measurement.

## 7. Events and notifications

From the predicted curve `A(t)` for the current waking day (wake time to
habitual bedtime), sampled every 5 minutes:

| Event | Definition |
|---|---|
| Inertia cleared | first time `W(τ) > −0.5` after waking |
| Morning peak | highest local maximum before 14:00 local |
| Afternoon dip | lowest local minimum between the morning peak and the evening peak |
| Evening peak | highest local maximum after the dip |
| Wind-down | 90 min before habitual sleep onset (a habit prompt, not a model output) |

A local extremum counts only if it differs from its neighbours by at least
0.3 scale units (prominence), to avoid notifying on flat stretches. If no
dip or second peak qualifies, emit none: do not fabricate events.

Notifications fire at the predicted time of the event ("You're likely at
today's energy peak"). They are predictions scheduled in advance, and the
copy must say "likely"/"predicted". Reschedule whenever sleep data or
settings change. No notifications during habitual sleep hours.

## 8. Other metrics

- **Sleep regularity**: Sleep Regularity Index (Phillips 2017), the
  probability of being in the same state (asleep/awake) at two times 24 h
  apart, over the last 14 days, scaled 0–100. Needs at least 7 days.
- **Social jetlag** (Wittmann 2006): absolute difference between mid-sleep
  on work days and free days. Needs the user to mark which days are free;
  ship only if that setting exists.
- **Averages**: 7-day and 14-day mean time asleep, mean onset and wake.

## 9. Golden tests

Each is a test in `SleepScienceTests`. They pin behaviour, not exact
decimals, unless a paper gives a figure to match.

1. Regular 8 h sleep 23:00–07:00 for 14 days: curve repeats day to day
   (steady state, day-to-day difference < 0.05); one morning peak, one
   afternoon dip, one evening peak; dip falls between 13:00 and 16:30.
2. Sleep inertia: A at wake + 5 min is lower than at wake + 2 h.
3. One night of total deprivation: A at 05:00 on the deprived night is the
   lowest point of the 48 h window; next-day peak is lower than baseline.
4. 6 h in bed for 14 days vs 8 h: daily peak lower every day in the 6 h arm;
   debt ledger rises by 2 h per day to 28 h (cap permitting).
5. Recovery: after test 4, three 9 h nights reduce debt by 3 h and raise
   the daily peak.
6. Phase shift: moving the schedule 2 h later moves all events ~2 h later
   once the 14-day median has caught up.
7. Parameters: if the source paper publishes a worked example or figure
   values, reproduce them to the stated precision.
8. Data handling: overlapping sources, midnight-crossing episodes, a DST
   spring-forward night, a time-zone change, naps, a 3-day data gap.
9. `now%` is 1.0 ± 0.02 at the peak of the reference simulation itself.

## 10. What we can claim

Allowed: "predicted", "estimated", "based on your last 14 nights",
"models of this kind describe the average person; you may differ".

Not allowed: diagnosis; "you are impaired"; guidance on driving or other
safety decisions; claims of accuracy for the individual; "optimal" wake
times from sleep cycles; anything implying the phone measured alertness.

The app carries a persistent "How this is calculated" screen that states
the model, the debt ledger, the conventions in sections 5–6, the
limitations in sections 1 and 4, and the references below.

## References

- Åkerstedt T, Folkard S. The three-process model of alertness and its extension to performance, sleep latency, and sleep length. Chronobiol Int. 1997;14(2):115–123.
- Åkerstedt T, Folkard S, Portin C. Predictions from the three-process model of alertness. Aviat Space Environ Med. 2004;75(3 Suppl):A75–83.
- Belenky G, et al. Patterns of performance degradation and restoration during sleep restriction and subsequent recovery. J Sleep Res. 2003;12(1):1–12.
- Borbély AA. A two process model of sleep regulation. Hum Neurobiol. 1982;1(3):195–204.
- Borbély AA, Daan S, Wirz-Justice A, Deboer T. The two-process model of sleep regulation: a reappraisal. J Sleep Res. 2016;25(2):131–143.
- Daan S, Beersma DG, Borbély AA. Timing of human sleep: recovery process gated by a circadian pacemaker. Am J Physiol. 1984;246(2):R161–183.
- Depner CM, et al. Ad libitum weekend recovery sleep fails to prevent metabolic dysregulation during a repeating pattern of insufficient sleep and weekend recovery sleep. Curr Biol. 2019;29(6):957–967.
- Hirshkowitz M, et al. National Sleep Foundation's sleep time duration recommendations. Sleep Health. 2015;1(1):40–43.
- Kitamura S, et al. Estimating individual optimal sleep duration and potential sleep debt. Sci Rep. 2016;6:35812.
- Lavie P. Ultrashort sleep-waking schedule. III. 'Gates' and 'forbidden zones' for sleep. Electroencephalogr Clin Neurophysiol. 1986;63(5):414–425.
- McCauley P, et al. Dynamic circadian modulation in a biomathematical model for the effects of sleep and sleep loss on waking neurobehavioral performance. Sleep. 2013;36(12):1987–1997.
- Monk TH. The post-lunch dip in performance. Clin Sports Med. 2005;24(2):e15–23.
- Phillips AJK, et al. Irregular sleep/wake patterns are associated with poorer academic performance and delayed circadian and sleep/wake timing. Sci Rep. 2017;7:3216.
- Rajdev P, et al. A unified mathematical model to quantify performance impairment for both chronic sleep restriction and total sleep deprivation. J Theor Biol. 2013;331:66–77.
- Roenneberg T, Wirz-Justice A, Merrow M. Life between clocks: daily temporal patterns of human chronotypes. J Biol Rhythms. 2003;18(1):80–90.
- Tassi P, Muzet A. Sleep inertia. Sleep Med Rev. 2000;4(4):341–353.
- Van Dongen HPA, Maislin G, Mullington JM, Dinges DF. The cumulative cost of additional wakefulness. Sleep. 2003;26(2):117–126.
- Van Dongen HPA, et al. Systematic interindividual differences in neurobehavioral impairment from sleep loss. Sleep. 2004;27(3):423–433.
- Watson NF, et al. Recommended amount of sleep for a healthy adult. Sleep. 2015;38(6):843–844.
- Windred DP, et al. Sleep regularity is a stronger predictor of mortality risk than sleep duration. Sleep. 2024;47(1):zsad253.
- Wittmann M, Dinich J, Merrow M, Roenneberg T. Social jetlag: misalignment of biological and social time. Chronobiol Int. 2006;23(1-2):497–509.
