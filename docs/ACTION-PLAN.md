# Get Gym Done — iOS Action Plan

Execution plan for the architecture in [`ARCHITECTURE.md`](./ARCHITECTURE.md), with the
defect dispositions in [`DEFECT-LEDGER.md`](./DEFECT-LEDGER.md).

Nine phases. Each has explicit deliverables and an **exit gate** — an objective check that
must pass before the next phase starts. Phases 1 and 2 are independent and can run in
parallel; everything from Phase 3 on depends on both.

Effort is given in relative units (1u ≈ half a focused day) rather than dates.

---

## Resolved decisions

All six open questions are settled; nothing blocks Phase 1.

| # | Decision | Resolution |
|---|---|---|
| 1 | Fidelity policy | **Fix all 42 defects.** 40 fixed on iOS, 2 N/A. Dispositions in `DEFECT-LEDGER.md`; the parity gate becomes a deviation register (ARCHITECTURE §9.1). |
| 2 | Minimum iOS | **17.0** — current − 2, the standard support window, and the version that introduces `@Observable`. |
| 3 | Dynamic Type | **Supported**, capped at `.accessibility1` on the dense screens. Apple HIG expects it and shipping without it is an App Review risk. |
| 4 | Light-mode accent contrast | **Fixed to WCAG AA** — subsumed by decision 1 (defect #21). |
| 5 | CI | **GitHub Actions `macos-15`.** The repo is public, so macOS minutes are free. `GymDoneKit` also builds on Linux for fast feedback. |
| 6 | Native extras | **None in v1.** Phase 8 stays deferred; parity ships first. |

---

## Phase 0 — Foundations & toolchain  · 3u

The environment problem is solved first, because SwiftUI written in a Linux container
cannot be compiled there (Risk #2).

| # | Task | Deliverable |
|---|---|---|
| 0.1 | Repo skeleton per ARCHITECTURE §3 | directory tree, `.gitignore` |
| 0.2 | `project.yml` (XcodeGen): app target, `GymDoneKit` dep, UITests target, iOS 17.0, portrait-only, `UIAppFonts` | `project.yml` |
| 0.3 | `GymDoneKit` SwiftPM manifest, Linux-buildable | `Package.swift` |
| 0.4 | Bundle fonts: `Anton-Regular.ttf` (copied verbatim, OFL) + Inter static TTFs (OFL) | `App/Resources/Fonts/` + licences |
| 0.5 | Copy `seed_data.json` byte-identical; assert SHA-256 `5627340b…` in CI | `docs/parity/seed.sha256` |
| 0.6 | **CI**: `ubuntu` job (`swift build`/`swift test`) + `macos-15` job (`xcodegen`, `xcodebuild`, `swift test`, simulator smoke test) | `.github/workflows/ci.yml` |
| 0.7 | Reference corpus + capture script | `docs/parity/` ✅ *done* |
| 0.8 | Transcribe the handover PDF's token/component sections from the page PNGs into a machine-readable reference | `docs/parity/handover-notes.md` |
| 0.9 | Stand up `docs/parity/deviations.yml` (empty) and the diff script that reads it | `docs/parity/diff.mjs` |

**Exit gate:** CI green on both runners; an empty app target boots on the iPhone 14
simulator; `swift test` runs on Linux; the diff script round-trips a known-identical pair.

---

## Phase 1 — Domain & store  · 9u  *(parallel with Phase 2)*

The accuracy-critical layer. No SwiftUI. Every file is a direct port of a named TS file.

| # | Task | Source | Notes |
|---|---|---|---|
| 1.1 | `Types.swift` | `types.ts` | Structs + `Codable`; constants (`REST_MIN` 30, `REST_MAX` 600, `DEFAULT_START_WEIGHT_KG` 20, …) |
| 1.2 | `Dates.swift` | `dates.ts` | `epochDayLocal` uses `Date.UTC(y,m,d)/86400000` on **local** components — port via `Calendar.current.dateComponents` |
| 1.3 | `Units.swift` | `units.ts` | `KG_PER_LB = 0.45359237`; **+ defect #19** — round lbs display to 0.5, snap steps to 2.5/5 lb |
| 1.4 | `Metrics.swift` | `metrics.ts` | `totalVolumeKg`, `compactNumber`, `countPRs`, `isTrainingSession` |
| 1.5 | `Rotation.swift` | `rotation.ts` | Rest-day skipping, wrap-around, cyclic `maxConsecutiveRestDays` |
| 1.6 | `Streak.swift` | `streak.ts` | Rest-gap bridging; dead if `today − mostRecent > maxRestGap + 1` |
| 1.7 | `Progression.swift` | `progression.ts` | Highest-subtlety function: group by session, 2 most recent, bucket by set number, present in every session, `abs(w − w0) < 1e-3`, all reps ≥ `max(repsHigh, 1)`, heaviest qualifying |
| 1.8 | `Seed.swift` | `seed.ts` | `dayExerciseId` composite key `"\(dayId)_\(exerciseId)_\(orderIndex)"` must match exactly |
| 1.9 | `StoreData.swift` + `AppStore.swift` | `store.ts` | 30 actions; `ensureSeeded` merge semantics (add new, update descriptive fields, never remove, preserve custom splits) |
| 1.10 | `Selectors.swift` | `selectors.ts` | 14 selectors, identical signatures |
| 1.11 | `Persistence.swift` | zustand `persist` | Atomic write, 400 ms debounce, scene-phase flush, corrupt-file side-filing |
| 1.12 | `Backup.swift` | `backup.ts` | v2 + Android `userPrefs` names; **+ defect #1** — validate `version == 2` and required arrays, auto safety-export before replace |
| 1.13 | **Golden vectors**: TS script emitting input→output JSON for the 8 pure functions | new | ARCHITECTURE §9.2 |
| 1.14 | Swift test suite against those vectors + hand-written edge cases | | |

**Exit gate:** `swift test` green on Linux; every golden vector reproduces exactly; backup
round-trip (web export → iOS import → iOS export) JSON-equal modulo `exportedAt`;
importing a non-backup file is rejected without touching stored data.

---

## Phase 2 — Design system  · 8u  *(parallel with Phase 1)*

| # | Task | Source | Notes |
|---|---|---|---|
| 2.1 | `Tokens.swift` — all `:root` custom properties, light + dark | `global.css` | |
| 2.2 | `Palettes.swift` — 10 accents, confetti colours, `SPLIT_OPTIONS` | `palettes.ts` | verbatim hex |
| 2.3 | `ThemeEnvironment.swift` — `@Environment(\.theme)`, `.ob` onboarding override | `apply.ts` | |
| 2.4 | **`Typography.swift` + calibration pass** | `global.css` | 13 styles; solve the Anton line-height problem (Risk #1); type-specimen diff before any screen is built |
| 2.5 | **Defect #21** — per-theme accent-on-background text colours meeting WCAG AA; audit 10 palettes × 2 themes | | the one fix that touches every screen |
| 2.6 | `Icons.swift` — 24 icons as `Path` shapes | `icons.tsx` | 2 pt stroke, round cap/join, 24×24 |
| 2.7 | Primitives: BigCTA, GhostCTA, IconButton, TextLink, PillChip, Chip, Badge, DayChip, StepperControl(+mini), SegTabs, SwitchControl, RadioDot, Card, StatPill, SplitCard, SetRow, Track, StripedPlaceholder, TrendArrow, TopBar | `ui.tsx` | |
| 2.8 | `SheetPresentation.swift` — bottom sheet (88 vh / 22 pt / grabber) + centered dialog overlay | | |
| 2.9 | `Toast.swift` — root host, 2,600 ms; **+ defect #23** — clear on navigation, cap to one visible | `toast.tsx` | |
| 2.10 | `Avatar.swift` — initials rule, photo variant | `Avatar.tsx` | |
| 2.11 | `MuscleMap.swift` — 11 regions as `Path`; **+ defect #34** — redraw the glute/hamstring region | `MuscleMap.tsx` | needed early: it becomes the artwork fallback (#11) |
| 2.12 | Component gallery screen (dev-only), every primitive × 2 themes × 10 accents | | |

**Exit gate:** type-specimen and icon-sheet diffs ≤2%; gallery correct across all 10 accents
in both themes; every accent passes WCAG AA for text on its background.

---

## Phase 3 — Onboarding  · 6u  · **first parity gate**

| # | Screen / task | Source | Reference shots |
|---|---|---|---|
| 3.1 | `SplashScreen`; **+ defect #17** — theme toggle visibly applies | `Splash.tsx` | `01-splash` |
| 3.2 | `PickSplitScreen`; **+ #16** — progress bar on all three steps | `PickSplit.tsx` | `02-pick-split` |
| 3.3 | `RoutineMethodScreen`; **+ #15** — drop the phantom PDF copy | `RoutineMethod.tsx` | `03-routine-method` |
| 3.4 | `CustomizeRoutineScreen`; **+ #2, #3, #39, #40** — draft data survives rest-day toggling and day-count changes; day name cleared on Rest; routine-name fallback visible | `CustomizeRoutine.tsx` | `30`, `31` |
| 3.5 | Onboarding `NavigationStack` + `RootView` gate | `App.tsx` | |
| 3.6 | **Screenshot harness**: XCUITest target, deterministic fixture, diff + deviation register wired into CI | | |

**Exit gate:** shots 01, 02, 03, 30, 31 show no *undeclared* difference above 2%; a preset
split and a custom split both commit and land on Home; toggling rest-day and cycling the
day count loses nothing.

---

## Phase 4 — Main shell · Today · Workouts  · 11u

| # | Task | Source | Reference shots |
|---|---|---|---|
| 4.1 | Custom tab bar + crossfade shell | `App.tsx` | all tab shots |
| 4.2 | `HomeScreen` — header, stat strip, rest-day card, up-next card with watermark; **+ #13** (remove the ↺ reset), **#14** (icon collision), **#20** (unit suffixes) | `Home.tsx` | `04`, `05`, `10`, `11` |
| 4.3 | **Defect #8** — up-next card becomes "Resume workout · 12 min" while a session is live | new state | |
| 4.4 | `CalendarCard`; **+ #26** — stack workout + activity, tappable past days, extended legend; **#18** pluralisation | `Home.tsx` | `05`, `24` |
| 4.5 | **Session detail sheet** — new screen (#26, #36): a day's sessions with per-exercise sets, weights, reps, volume | new design | — |
| 4.6 | This-week list + edit mode; **+ #25** — align streak/week definitions, relabel "LAST 7 DAYS" | `Home.tsx` | `27` |
| 4.7 | `LogActivityDialog`; **+ #41** — explain what "count as today's workout" does | `Home.tsx` | `25` |
| 4.8 | Reset-routine dialog (now owned by Settings, #13) | | `26` |
| 4.9 | Auto rest-day logging effect, once per calendar day | `Home.tsx` | |
| 4.10 | `WorkoutsListScreen` + edit mode; **+ #27** — "+N more" overflow chip | `WorkoutsList.tsx` | `06` |
| 4.11 | **Defect #38** — centralised duration estimate: sets × (rest + ~40 s) | | |

**Exit gate:** shots 04, 05, 06, 10, 11, 24, 25, 26, 27 clean against the register; rotation
matches the web on identical fixtures; a past calendar day opens its session detail.

---

## Phase 5 — Workout loop  · 15u  *(largest phase)*

| # | Task | Source | Reference shots |
|---|---|---|---|
| 5.1 | `ExercisePicker` — search, muscle grouping, custom-exercise form; **+ #28** — sensible defaults, not first-alphabetical | `ExercisePicker.tsx` | `20` |
| 5.2 | `DayOverviewScreen` — tabs, switch-day, edit sheet, rest-day variant; **+ #32** (center the bed icon), **#42** (visible labels), **#10** (no dead-end CTA) | `DayOverview.tsx` | `12`–`16` |
| 5.3 | **Defect #30** — warmup focus derived from the day's exercises; CTA renamed | | `13` |
| 5.4 | `ActiveWorkoutScreen` shell — top bar, progress track, exercise dots, terminals | `ActiveWorkout.tsx` | `17` |
| 5.5 | `ExerciseContent` — hero, targets, form cues, prescription; **+ #11** — `MuscleMap` fallback replaces striped placeholders | | `17` |
| 5.6 | Set rows + prefill chain; **+ #6** (reps ≥ 1), **#33** (bodyweight "BW" semantics) | | `17`, `22` |
| 5.7 | `Keypad` — buffer semantics, quick-add chips, decimal rules | `Keypad.tsx` | `18` |
| 5.8 | Progression suggestion card + bump-all-undone-sets | | |
| 5.9 | Overflow menu: add / replace / remove; **+ #22** — "· REPLACED" not "· ADDED" | | `19` |
| 5.10 | `RestOverlay` — wall-clock countdown, ring (r=84, C=2πr), ±30 s, skip; **+ #5** (± affects only the running timer), **#31** (collapsible so sets stay reachable) | | `21` |
| 5.11 | **Platform**: local notification scheduling/cancellation, `AVAudioSession` beeps, haptics; **+ #12** — contextual permission pre-prompt after the first timer | no web analogue | |
| 5.12 | **Defect #7** — confirm dialog listing unfinished exercises before finishing | | |
| 5.13 | `WorkoutCompleteScreen`; **+ #18** — pluralisation, real first-session volume instead of "NEW" | `WorkoutComplete.tsx` | `23` |
| 5.14 | `Confetti` — 120 pieces, ported physics; **+ #24** — consume the flag on first mount | `Confetti.tsx` | |
| 5.15 | Session resume across app relaunch, timer still running | | |

**Exit gate:** shots 12–23 clean against the register; a full workout logs end-to-end;
killing and relaunching mid-workout restores exercise index, sets and an accurate
countdown; the rest notification fires when backgrounded; a 0-rep set cannot be logged.

---

## Phase 6 — Profile · Settings · Sync  · 10u

| # | Task | Source | Reference shots |
|---|---|---|---|
| 6.1 | `Sparkline` / `DualSparkline` | `Sparkline.tsx` | `07` |
| 6.2 | `Heatmap` — 18 weeks, 4 buckets, rest-gap autofill | `Heatmap.tsx` | `07` |
| 6.3 | `ProfileScreen` — header, totals, ranges, body card + history; **+ #20** unit suffixes | `Profile.tsx` | `07` |
| 6.4 | Progression + PR lists with expandable curve | | `07` |
| 6.5 | Edit-profile and log-body sheets; **+ #9** (clamp body metrics with inline errors), **#29** (name length handled honestly) | | `28`, `29` |
| 6.6 | **Platform**: `PhotosPicker` + 256 px downscale | | |
| 6.7 | `SettingsScreen` — theme, 10 accent swatches, units, reset; **+ #13** (reset gets its confirm), **#5** (new "Default rest" setting) | `Settings.tsx` | `08`, `09` |
| 6.8 | Export / import via `fileExporter` / `fileImporter` + confirm dialogs | | |
| 6.9 | `GistSync` — push/pull/auto-push, Keychain token; **+ #35** — human-readable errors, single state line | `gist.ts` | |
| 6.10 | **Defect #34** — audit all 155 seed entries for equipment/muscle mismatches | | |

**Exit gate:** shots 07, 08, 09, 28, 29 clean against the register; a real Gist round-trip
succeeds; export → import → export is stable; 300% body fat is rejected.

---

## Phase 7 — Parity sweep & hardening  · 7u

| # | Task |
|---|---|
| 7.1 | Full 31-shot run; every screen clean against the deviation register; each register entry reviewed by eye and justified by its defect number |
| 7.2 | Re-run golden vectors + backup round-trip against the finished app |
| 7.3 | Edge cases: empty routine · day with 0 exercises · all-rest split · single-exercise workout · very long names · 30k set logs · unit switching mid-session |
| 7.4 | Accessibility: VoiceOver labels on every icon-only control, Dynamic Type sweep to `.accessibility1`, contrast re-audit |
| 7.5 | Performance: Instruments on ActiveWorkout (store invalidation), Profile (155-exercise aggregation), snapshot write timing at 30k set logs |
| 7.6 | State restoration, memory-warning behaviour, cold-launch time |
| 7.7 | App Store readiness: icon set from `public/icons/`, launch screen, privacy manifest (no tracking; network only to `api.github.com` when sync is configured) |
| 7.8 | Back-port review: which of the 40 fixes should also land in the web app, so the two don't drift |

**Exit gate:** no undeclared visual difference; every declared one justified; all 40 defect
fixes verified; no P0/P1 open; CI green.

---

## Phase 8 — Native enhancements  · deferred

Not in v1 (decision 6). Listed so they aren't lost: Live Activity / Dynamic Island rest
timer (~4u) · Home Screen widgets (~3u) · App Intents + Siri (~2u) · HealthKit write (~3u) ·
Apple Watch companion (~10u) · CloudKit sync alongside Gist (~6u).

---

## Summary

| Phase | Focus | Effort |
|---|---|---|
| 0 | Foundations & toolchain | 3u |
| 1 | Domain & store | 9u |
| 2 | Design system | 8u |
| 3 | Onboarding · first parity gate | 6u |
| 4 | Shell · Today · Workouts | 11u |
| 5 | Workout loop | 15u |
| 6 | Profile · Settings · Sync | 10u |
| 7 | Parity sweep & hardening | 7u |
| | **Total** | **69u** |

Phases 1 and 2 overlap, so the critical path is roughly **61u**. The defect fixes add ~12u
over a straight port — most of it in Phases 4 and 5, where the session detail sheet, the
resume-workout state and the collapsible rest timer live.
