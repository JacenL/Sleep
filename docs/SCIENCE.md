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
| Early-afternoon dip in alertness | Established, modest, varies by person and with sleep timing | Monk 2005; Bes 2009 |
| Evening "wake maintenance zone" shortly before habitual bedtime | Established; its timing relative to bedtime varies by hours between people | Lavie 1986; Shekleton 2013 |
| Sleep debt: chronic short sleep causes deficits that accumulate over days | Real. The effect is established; any single number of "hours owed" is a simplification | Van Dongen 2003; Belenky 2003 |
| People under chronic restriction under-rate their own impairment | Established | Van Dongen 2003 |
| Recovery from debt is slower than 1 h per 1 h; weekend catch-up sleep does not prevent metabolic effects of recurrent short sleep | Supported | Kitamura 2016; Depner 2019 (metabolic outcomes, not alertness) |
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
  Consensus guidance for adults is at least 7 h (Watson 2015; `UNVERIFIED`:
  abstract checked, full text not read), 7–9 h (Hirshkowitz 2015); teenagers
  need more (8–10 h). Individual need varies and cannot be measured by the
  app. A later milestone may *suggest* a value from sleep on unconstrained
  days, but only the user sets it. `N` also sets the model's sleep-recovery
  rate (section 4), as the three-process model does for habitual sleep
  length.
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
5. Entries the user typed or edited by hand are the user's stated truth and
   override everything else for overlapping time.
5a. The owner has no wearable, so most nights come from two phone-only
   sources (section 3.1). Both record **time in bed, not time asleep**. They
   are treated exactly like `inBed`: `quality: .estimated`, counted as sleep
   without correction, used only where no `asleep*` samples exist, and
   preferred over HealthKit `inBed` for the same time. If the user edits one,
   it becomes a hand entry under rule 5.
6. An episode belongs to the calendar day (user's current time zone) in
   which it **ends**. Episodes shorter than 3 h that end between 10:00 and
   20:00 are naps: they count toward that day's total and feed the model
   normally.

### 3.1 Phone-only sources

- **Automation-logged**: bedtime and wake-up recorded by App Intents that
  the user triggers from iOS Shortcuts automations (Sleep Focus on/off,
  alarm stopped) or from the in-app button. Start and end are the moments
  the automation fired.
- **Motion-suggested**: the app reads the phone's stored motion history and
  proposes the longest overnight stationary stretch as a candidate night.
  It is **only ever a suggestion**: nothing enters the sleep history until
  the user confirms or adjusts it. A stationary phone is not evidence of
  sleep (it may be on a desk), so an unconfirmed suggestion is never fed to
  the model, the ledger, or notifications.

Consequence to state in the explainer: time in bed overstates sleep by the
time taken to fall asleep plus time awake in the night, so on estimated
nights the debt and energy figures are somewhat optimistic. The size of
that bias is not known for the individual and the app does not correct for
it.

The exact candidate-detection rule for motion suggestions (minimum length,
time window, how gaps are bridged) is a display convention, to be proposed
by the implementer, agreed with the user, and recorded in
`DisplayConventions.swift`. It is not a scientific sleep-detection method
and must not be described as one.

## 4. Alertness model (v1): Three-Process Model

Sources: Åkerstedt & Folkard 1997; Åkerstedt, Folkard & Portin 2004;
Åkerstedt et al. 2008 (sleep-recovery "brake"); Ingre et al. 2014, which
prints the full equation set (eqs 1.1–1.8) and was co-authored by Åkerstedt.
The model extends the two-process model (Borbély 1982) and was validated
against subjective alertness and performance. Output is on a 1–21 scale
(2004 abstract and p.A77; 2008 abstract; the 1997 paper used 1–16). On it,
"3" is extreme sleepiness, "14" high alertness, and "7" a sleepiness
threshold where EOG slow eye movements appear (2004 p.A77).

**Version implemented (v1):** S with the 2008 brake + C + U. Sleep inertia
W is implemented but **off by default**. The 2004 paper says W is "presently
excluded" from predictions, and the 2014 validation found that adding W
worsened the fit ("the default parameters of process W were exaggerated";
best model S_B + C + U, model 5c). This choice was made on 2026-11-13.

Predicted alertness at time `t`:

```
A(t) = S(t) + C(t) + U(t)            (+ W(t) only if inertia is enabled)
```

**S — homeostatic component.** `τ` is hours since the last state change.

```
awake:   S(τ) = la + (S_wake − la) · e^(d·τ)                      Ingre eq 1.1; 2004 p.A76
asleep, S_sleep ≥ bl:
         S(τ) = ha − (ha − S_sleep) · e^(g·τ)                     Ingre eq 1.2
asleep, S_sleep < bl (brake):
         S(τ) = S_sleep + τ · g · (bl − ha)        for τ ≤ t_b    Ingre eq 1.3
         S(τ) = ha − (ha − bl) · e^(g·(τ − t_b))   for τ > t_b    Ingre eq 1.4
         t_b  = (bl − S_sleep) / (g · (bl − ha))                  Ingre eq 1.5
```

`S_wake` is S at the moment of waking, `S_sleep` is S at sleep onset. S is
integrated continuously across the whole sleep history, so short nights
carry into following days. Below `bl`, recovery is linear at the slope the
exponential has at `bl`. This stops the speed of recovery from growing
without limit after heavy sleep loss (2004 p.A77–78; 2008).

**Sleep need sets g.** The model handles habitual sleep need "by adjusting
the time constant of the S function to reach full recovery in the time
indicated as habitual sleep duration. The default value is 8 h" (2004
p.A78). The recovery constant is defined by recovery from 7.96 to 14.0 in
the habitual sleep length (Ingre 2014):

```
g(N) = ln( (ha − 14.0) / (ha − 7.96) ) / N        g(8) = −0.3813 /h
```

**C — circadian component** and **U — 12 h component**. `h` is local clock
time in hours, `p` the acrophase.

```
C(h) = Cm + Ca · cos( 2π (h − p) / 24 )             Ingre eq 1.7; 2004 p.A76
U(h) = Um + Ua · cos( 2π (h − p − 3) / 12 )         Ingre eq 1.8
```

The 2004 paper writes U as `mesor − Mu·cos(2π/12·(t − (p − 3)))`, "a 12-h
rhythm with an amplitude of 0.5 units … set 3 h before the acrophase of C".
That is the same curve, shifted by half a period. U's trough is at p − 3
(13:48 by default).

**W — sleep inertia** (off by default), `τ` hours since waking:

```
W(τ) = Wc · e^(Wd·τ)                                Ingre eq 1.6
```

The 2004 paper prints W's decay as 0.65692, which equals 1.51 / ln 10. This
looks like a base-10 vs base-e discrepancy, so Ingre 2014's −1.51 is used.
Tassi & Muzet 2000 report that, without major sleep deprivation, inertia
rarely exceeds 30 min. With these parameters W takes about 1 h 37 min to
rise above −0.5, which is another reason W is off.

Parameters (verified 2026-11-13; sources read are listed with each):

| Symbol | Value | Meaning | Source |
|---|---|---|---|
| ha | 14.3 | upper asymptote of S | 2004 p.A76; Ingre 2014 |
| la | 2.4 | lower asymptote of S | 2004 p.A76; Ingre 2014 |
| d | −0.0353 /h | decay of S while awake | 2004 p.A76; Ingre eq 1.1 |
| g | ln(0.3/6.34)/N, −0.3813 /h at N = 8 | recovery of S while asleep | 2004 p.A76 (0.381), p.A78; Ingre 2014 |
| bl | 12.2 | brake point: recovery linear below it | 2008 abstract; Ingre eqs 1.3–1.5 (2004 used 12.5) |
| Cm, Ca | 0, 2.5 | circadian mesor, amplitude | Ingre eq 1.7; 2004 p.A76 (M = 2.5) |
| p | 16.8 h | circadian acrophase (default) | Ingre 2014 (the 2004 paper gives no default) |
| Um, Ua | −0.5, 0.5 | 12 h component mesor, amplitude | Ingre eq 1.8; 2004 p.A77 (amplitude) |
| Wc, Wd | −5.72, −1.51 /h | inertia magnitude, decay (off by default) | Ingre eq 1.6 |
| 7 | — | sleepiness threshold on the 1–21 scale | 2004 p.A77; Åkerstedt & Folkard 1995 |

**Behaviour on a regular schedule.** With these parameters, a regular
23:00–07:00 sleeper's curve rises from waking to a single maximum in late
afternoon (about 16:40), then falls. U only flattens the late-morning slope.
**v1 produces no morning peak and no afternoon dip on a regular schedule.**
This is consistent with alertness being relatively stable across a rested
waking day (Goel 2013) and with the dip being modest and person- and
schedule-dependent (Monk 2005; Bes 2009). However, the literature does
describe a real post-noon dip, a late-morning high and an evening wake
maintenance zone in many people (Lavie 1986; Bes 2009). v1 does not
reproduce these: a model limitation, not evidence that they are absent. The
timing of the evening high relative to bedtime varies by hours between
people (Shekleton 2013).

**Initial condition.** Start the simulation 14 days before the first day
displayed, with S at the model's steady-state wake value for a regular
`N`-hour schedule. With less than 14 days of history, fill missing earlier
nights with the habitual schedule and mark output `lowConfidence`.

**Nights with no data** (decided 2026-11-13). A day inside the simulated
range on which no sleep episode ends at all is treated the same way. The
model assumes a habitual night of exactly `N` hours ending at the habitual
wake time on that day, and output from that night until the next day with
data is marked `lowConfidence`. This is an assumption, not data, and the UI
says so. As a consequence, a real all-nighter is invisible unless the user
records it explicitly. The debt ledger does not use filled nights (section
5: days with no data are skipped). A filled night ends at the habitual wake
time and starts `N` hours earlier. The same rule places the nights of the
rested reference simulation in section 6 (a display convention).

**Personalising phase.** The default `p = 16.8` assumes a conventional
schedule. Shift it by the user's habitual mid-sleep relative to a reference
mid-sleep of 03:00: `p_user = 16.8 + (midSleep − 3.0)`, clamped to ±4 h.
This is a **heuristic** in the spirit of chronotype-from-mid-sleep
(Roenneberg 2003), not a measured circadian phase. Use the 14-day median so
one late night does not move the curve. Label it as a heuristic in-app.

**Known limitation.** Under sustained restriction this model's S settles to
a new steady state within a few days, whereas laboratory data show deficits
still growing after two weeks (Van Dongen 2003). The 2008 brake was added to
reduce this gap but does not remove it. So v1 understates the cost of
long-running debt. That is why debt is shown as its own number (section 5)
and why the model sits behind a protocol.

**v2 candidates.** The unified model of performance (Rajdev 2013) or
McCauley 2013, both designed to reproduce chronic restriction and total
deprivation together. Also SAFTE (Hursh 2004), revised for "the unexpected
persistence of performance effects following chronic sleep restriction"; to
evaluate, from published equations only (not yet read). Implement any of
these only from the papers' published equations and parameters, as a second
`AlertnessModel`, and compare against v1 with the golden tests before
switching.

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
| Daily peak | the highest point of `A` during the waking day |
| Low energy | first time `A ≤ 7` during the waking day: the published sleepiness threshold (2004 p.A77) |
| Morning peak | highest local maximum before 14:00 local (conditional, see below) |
| Afternoon dip | lowest local minimum between the morning peak and the evening peak (conditional) |
| Evening peak | highest local maximum after the dip (conditional) |
| Wind-down | 90 min before habitual sleep onset (a habit prompt, not a model output) |

A local extremum counts only if it differs from its neighbours by at least
0.3 scale units (prominence), to avoid notifying on flat stretches. If no
dip or second peak qualifies, emit none: do not fabricate events. With v1
on a regular schedule none of the three conditional events qualify (section
4), so in practice the daily peak, low energy and wind-down are the events
users see. When a morning peak qualifies, the daily peak is still emitted
only once: if it coincides with a qualifying peak, emit the qualifying peak
and not a duplicate.

Low energy fires only after short or missed sleep: a rested regular day
bottoms out near 8.8 before bed. Its copy must respect section 10: it is a
prediction ("Your predicted alertness is likely low from here on"). It must
never say "impaired" and never give driving or safety advice.

"Inertia cleared" was removed with sleep inertia (section 4).

Notifications fire at the predicted time of the event ("You're likely at
today's energy peak"). They are predictions scheduled in advance, and the
copy must say "likely"/"predicted". Reschedule whenever sleep data or
settings change. No notifications during habitual sleep hours.

## 8. Other metrics

- **Sleep regularity**: Sleep Regularity Index (Phillips 2017, Methods).
  `P` is the probability that any two minutes 24 h apart are in the same
  state (asleep/awake), computed minute by minute. `SRI = 200 · (P − ½)`,
  which ranges from −100 to 100: 100 is perfectly periodic and 0 is random.
  In practice values fall between 0 and 100, but negative values are
  possible and are shown as computed. Phillips used 30 days; the app uses
  the last 14 complete days and needs at least 7 with data (a display
  convention). Minute pairs are compared only when both calendar days have
  data, so a gap is not counted as wake (also a convention).
- **Social jetlag** (Wittmann 2006): absolute difference between mid-sleep
  on work days and free days (`UNVERIFIED`: concept confirmed from the
  abstract; formula not checked in the full text). Needs the user to mark
  which days are free; ship only if that setting exists.
- **Averages**: 7-day and 14-day mean time asleep, mean onset and wake.

## 9. Golden tests

Each is a test in `SleepScienceTests`. They pin behaviour, not exact
decimals, unless a paper gives a figure to match.

1. Regular 8 h sleep 23:00–07:00 for 14 days: curve repeats day to day
   (steady state, day-to-day difference < 0.05); a single daily maximum
   between 15:30 and 18:00; no morning peak, afternoon dip or evening peak
   event is emitted (section 4, "Behaviour on a regular schedule").
2. (Removed 2026-11-13 with sleep inertia. A non-golden unit test checks the
   optional W against Ingre eq 1.6.)
3. One night of total deprivation after a regular baseline: the minimum of
   A during the deprived night (23:00–07:00) falls between 04:00 and 06:00
   and is below every point of the baseline waking day; the next day's
   peak is lower than the baseline peak. (The lowest point of the whole
   48 h window is the following evening, after ~40 h awake, so the test
   does not claim 05:00 is the global minimum.)
4. 6 h in bed for 14 days vs 8 h: daily peak lower every day in the 6 h arm;
   debt ledger rises by 2 h per day to 28 h (cap permitting).
5. Recovery: after test 4, three 9 h nights reduce debt by 3 h and raise
   the daily peak.
6. Phase shift: moving the schedule 2 h later moves all events ~2 h later
   once the 14-day median has caught up.
7. Parameters, from the published equations, to ±0.001:
   - Brake disabled: 8 h of sleep from S = 7.96 at N = 8 reaches 14.000.
     This is the definition of g in Ingre 2014.
   - Brake enabled (bl = 12.2): from S = 7.96 the linear phase lasts
     t_b = 5.294 h at 0.8008 /h, and 8 h of sleep reaches 13.552 (Ingre eqs
     1.3–1.5).
   - Wake decay: S − la falls by 3.47 % per hour (e^−0.0353; "3.5 % of the
     previous value per hour", Åkerstedt & Folkard 1995).
   No parameter may be adjusted to make these pass.
8. Data handling: overlapping sources, midnight-crossing episodes, a DST
   spring-forward night, a time-zone change, naps, a 3-day data gap.
9. `now%` is 1.0 ± 0.02 at the peak of the reference simulation itself.
10. Low energy: not emitted on the regular schedule of test 1; emitted on
    the day after the deprived night of test 3.

## 10. What we can claim

Allowed: "predicted", "estimated", "based on your last 14 nights",
"models of this kind describe the average person; you may differ".

Not allowed: diagnosis; "you are impaired"; guidance on driving or other
safety decisions; claims of accuracy for the individual; "optimal" wake
times from sleep cycles; anything implying the phone measured alertness.

The app carries a persistent "How this is calculated" screen that states
the model, the debt ledger, the conventions in sections 5–6, the
limitations in sections 1 and 4, and the references below. It says
explicitly that grogginess just after waking (sleep inertia) is not part of
the curve, and that the model does not reproduce an afternoon dip or
evening high that the user may personally have.

## References

Every reference below was checked to exist in PubMed on 2026-11-13. Full text
was read for Åkerstedt 2004, Ingre 2014, Åkerstedt & Folkard 1995, Phillips
2017, Goel 2013, Bes 2009 and Shekleton 2013; the others were checked from
their abstracts.

- Åkerstedt T, Folkard S. Quantitative model for vigilance regulation and its application in transport operations. In: Vallet M, Khardi S, eds. Vigilance et transports. Presses universitaires de Lyon; 1995:199–206.
- Åkerstedt T, Folkard S. The three-process model of alertness and its extension to performance, sleep latency, and sleep length. Chronobiol Int. 1997;14(2):115–123. (Uses a 1–16 scale.)
- Åkerstedt T, Folkard S, Portin C. Predictions from the three-process model of alertness. Aviat Space Environ Med. 2004;75(3 Suppl):A75–83.
- Åkerstedt T, et al. Accounting for partial sleep deprivation and cumulative sleepiness in the three-process model of alertness regulation. Chronobiol Int. 2008;25(2):309–319.
- Belenky G, et al. Patterns of performance degradation and restoration during sleep restriction and subsequent recovery. J Sleep Res. 2003;12(1):1–12.
- Bes F, Jobert M, Schulz H. Modeling napping, post-lunch dip, and other variations in human sleep propensity. Sleep. 2009;32(3):392–398.
- Borbély AA. A two process model of sleep regulation. Hum Neurobiol. 1982;1(3):195–204.
- Borbély AA, Daan S, Wirz-Justice A, Deboer T. The two-process model of sleep regulation: a reappraisal. J Sleep Res. 2016;25(2):131–143.
- Daan S, Beersma DG, Borbély AA. Timing of human sleep: recovery process gated by a circadian pacemaker. Am J Physiol. 1984;246(2 Pt 2):R161–183.
- Depner CM, et al. Ad libitum weekend recovery sleep fails to prevent metabolic dysregulation during a repeating pattern of insufficient sleep and weekend recovery sleep. Curr Biol. 2019;29(6):957–967.e4.
- Goel N, Basner M, Rao H, Dinges DF. Circadian rhythms, sleep deprivation, and human performance. Prog Mol Biol Transl Sci. 2013;119:155–190.
- Hirshkowitz M, et al. National Sleep Foundation's sleep time duration recommendations: methodology and results summary. Sleep Health. 2015;1(1):40–43.
- Hursh SR, et al. Fatigue models for applied research in warfighting. Aviat Space Environ Med. 2004;75(3 Suppl):A44–53.
- Ingre M, Van Leeuwen W, Klemets T, et al. Validating and extending the three process model of alertness in airline operations. PLoS One. 2014;9(10):e108679.
- Kitamura S, et al. Estimating individual optimal sleep duration and potential sleep debt. Sci Rep. 2016;6:35812.
- Lavie P. Ultrashort sleep-waking schedule. III. 'Gates' and 'forbidden zones' for sleep. Electroencephalogr Clin Neurophysiol. 1986;63(5):414–425.
- McCauley P, et al. Dynamic circadian modulation in a biomathematical model for the effects of sleep and sleep loss on waking neurobehavioral performance. Sleep. 2013;36(12):1987–1997.
- Monk TH. The post-lunch dip in performance. Clin Sports Med. 2005;24(2):e15–23.
- Phillips AJK, et al. Irregular sleep/wake patterns are associated with poorer academic performance and delayed circadian and sleep/wake timing. Sci Rep. 2017;7(1):3216.
- Rajdev P, et al. A unified mathematical model to quantify performance impairment for both chronic sleep restriction and total sleep deprivation. J Theor Biol. 2013;331:66–77.
- Roenneberg T, Wirz-Justice A, Merrow M. Life between clocks: daily temporal patterns of human chronotypes. J Biol Rhythms. 2003;18(1):80–90.
- Shekleton JA, Rajaratnam SMW, Gooley JJ, Van Reen E, Czeisler CA, Lockley SW. Improved neurobehavioral performance during the wake maintenance zone. J Clin Sleep Med. 2013;9(4):353–362.
- Tassi P, Muzet A. Sleep inertia. Sleep Med Rev. 2000;4(4):341–353.
- Van Dongen HPA, Maislin G, Mullington JM, Dinges DF. The cumulative cost of additional wakefulness. Sleep. 2003;26(2):117–126.
- Van Dongen HPA, et al. Systematic interindividual differences in neurobehavioral impairment from sleep loss. Sleep. 2004;27(3):423–433.
- Watson NF, et al. Recommended amount of sleep for a healthy adult. Sleep. 2015;38(6):843–844.
- Windred DP, et al. Sleep regularity is a stronger predictor of mortality risk than sleep duration. Sleep. 2024;47(1):zsad253.
- Wittmann M, Dinich J, Merrow M, Roenneberg T. Social jetlag: misalignment of biological and social time. Chronobiol Int. 2006;23(1-2):497–509.
