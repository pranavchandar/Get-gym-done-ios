# Get Gym Done — iOS Action Plan

Execution plan for the architecture in [`ARCHITECTURE.md`](./ARCHITECTURE.md).

Nine phases. Each has explicit deliverables and an **exit gate** — an objective check that
must pass before the next phase starts. Phases 1 and 2 are independent and can run in
parallel; everything from Phase 3 on depends on both.

Effort is given in relative units (1u ≈ half a focused day) rather than dates.

---

## Phase 0 — Foundations & toolchain  · 3u

The environment problem is solved first, because SwiftUI written in a Linux container
cannot be compiled there (Risk #2).

| # | Task | Deliverable |
|---|---|---|
| 0.1 | Repo skeleton per §3 layout | directory tree, `.gitignore`, `README.md` |
| 0.2 | `project.yml` (XcodeGen): app target, `GymDoneKit` dep, UITests target, iOS 17.0, portrait-only, `UIAppFonts` | `project.yml` |
| 0.3 | `GymDoneKit` SwiftPM manifest, Linux-buildable | `Package.swift` |
| 0.4 | Bundle fonts: `Anton-Regular.ttf` (copied verbatim from the web repo, OFL) + Inter static TTFs (OFL) | `App/Resources/Fonts/` + licence files |
| 0.5 | Copy `seed_data.json` byte-identical; record its SHA-256 | `GymDoneKit/Sources/.../Resources/`, `docs/parity/seed.sha256` |
| 0.6 | **CI**: GitHub Actions — `ubuntu` job (`swift build`/`swift test` on GymDoneKit) + `macos-15` job (`xcodegen`, `xcodebuild`, `swift test`, simulator boot smoke test) | `.github/workflows/ci.yml` |
| 0.7 | Commit the 31-shot reference corpus + capture script | `docs/parity/` ✅ *already done* |

**Exit gate:** CI green on both runners; an empty app target boots on the iPhone 14
simulator and renders "Hello"; `swift test` runs on Linux.

---

## Phase 1 — Domain & store  · 8u  *(parallel with Phase 2)*

The accuracy-critical layer. No SwiftUI. Every file is a direct port of a named TS file.

| # | Task | Source | Notes |
|---|---|---|---|
| 1.1 | `Types.swift` | `types.ts` (104 L) | Structs + `Codable`; constants (`REST_MIN` 30, `REST_MAX` 600, `DEFAULT_START_WEIGHT_KG` 20, …) |
| 1.2 | `Dates.swift` | `dates.ts` | `epochDayLocal` uses `Date.UTC(y,m,d)/86400000` on **local** components — port carefully via `Calendar.current.dateComponents`; weekday/month name tables |
| 1.3 | `Units.swift` | `units.ts` | `KG_PER_LB = 0.45359237`; kg↔display, `displayStep`, `incrementKgFor`, `formatWeight` trailing-zero trimming |
| 1.4 | `Metrics.swift` | `metrics.ts` | `totalVolumeKg`, `compactNumber` (1.2M/3.4k), `countPRs`, `isTrainingSession` |
| 1.5 | `Rotation.swift` | `rotation.ts` | `nextWorkoutDay` rest-day skipping + wrap-around; `maxConsecutiveRestDays` (cyclic, doubled-list trick) |
| 1.6 | `Streak.swift` | `streak.ts` | Rest-gap bridging; "dead if `today − mostRecent > maxRestGap + 1`" |
| 1.7 | `Progression.swift` | `progression.ts` | Highest-subtlety function: group by session, take 2 most recent, bucket by set number, require presence in every session, `abs(w − w0) < 1e-3` equality, all reps ≥ `max(repsHigh, 1)`, pick heaviest qualifying |
| 1.8 | `Seed.swift` | `seed.ts` | Catalog build; `dayExerciseId` composite key format `"\(dayId)_\(exerciseId)_\(orderIndex)"` must match exactly |
| 1.9 | `StoreData.swift` + `AppStore.swift` | `store.ts` (665 L) | 30 actions; `ensureSeeded` merge semantics (add new, update descriptive fields in place, never remove, preserve custom splits) |
| 1.10 | `Selectors.swift` | `selectors.ts` | 14 selectors, identical signatures |
| 1.11 | `Persistence.swift` | zustand `persist` | Atomic write, 400 ms debounce, scene-phase flush, corrupt-file side-filing |
| 1.12 | `Backup.swift` | `backup.ts` | `BackupFile` v2 + Android `userPrefs` field names; **plus Bucket B fix #1** (validate `version == 2` and required arrays; safety export before replace) |
| 1.13 | **Golden vectors**: TS script emitting input→output JSON for the 8 pure functions | new | See ARCHITECTURE §9.2 |
| 1.14 | Swift test suite asserting against those vectors + hand-written edge cases | | |

**Exit gate:** `swift test` green on Linux; every golden vector reproduces exactly;
backup round-trip (web export → iOS import → iOS export) is JSON-equal modulo `exportedAt`.

---

## Phase 2 — Design system  · 7u  *(parallel with Phase 1)*

| # | Task | Source | Notes |
|---|---|---|---|
| 2.1 | `Tokens.swift` — all `:root` custom properties, light + dark | `global.css` 11–45 | |
| 2.2 | `Palettes.swift` — 10 accents + confetti colours + `SPLIT_OPTIONS` | `palettes.ts` | verbatim hex |
| 2.3 | `ThemeEnvironment.swift` — `@Environment(\.theme)`, `.ob` onboarding override | `apply.ts` | |
| 2.4 | **`Typography.swift` + calibration pass** | `global.css` 93–108 | 13 styles; solve the Anton line-height problem (Risk #1); produce a type-specimen screen and diff it against a matching web specimen before proceeding |
| 2.5 | `Icons.swift` — 24 icons as `Path` shapes | `icons.tsx` | 2 pt stroke, round cap/join, 24×24 |
| 2.6 | Primitives: BigCTA, GhostCTA, IconButton, TextLink, PillChip, Chip, Badge, DayChip, StepperControl(+mini), SegTabs, SwitchControl, RadioDot, Card, StatPill, SplitCard, SetRow, Track, StripedPlaceholder, TrendArrow, TopBar | `ui.tsx` + `global.css` | |
| 2.7 | `SheetPresentation.swift` — bottom sheet (88 vh / 22 pt / grabber) + centered dialog overlay | `.sheet`/`.dialog` | |
| 2.8 | `Toast.swift` — root host, 2,600 ms, stacked, bottom offset 76 + safe area | `toast.tsx` | |
| 2.9 | `Avatar.swift` — initials rule (first + last word), photo variant | `Avatar.tsx` | |
| 2.10 | Component gallery screen (dev-only) exercising every primitive in both themes × 10 accents | new | |

**Exit gate:** type-specimen diff ≤2%; icon-sheet diff ≤2%; gallery renders correctly in
light + dark across all 10 accents.

---

## Phase 3 — Onboarding  · 5u  · **first parity gate**

| # | Screen | Source | Reference shots |
|---|---|---|---|
| 3.1 | `SplashScreen` | `Splash.tsx` (53 L) | `01-splash` |
| 3.2 | `PickSplitScreen` | `PickSplit.tsx` (153 L) | `02-pick-split` |
| 3.3 | `RoutineMethodScreen` | `RoutineMethod.tsx` (66 L) | `03-routine-method` |
| 3.4 | `CustomizeRoutineScreen` | `CustomizeRoutine.tsx` (202 L) | `30-customize-blank`, `31-customize-seeded` |
| 3.5 | Onboarding `NavigationStack` + `RootView` gate | `App.tsx` | |
| 3.6 | **Bucket B fixes #2, #3** — rest-day checkbox and days-per-week stepper stop destroying draft data | | behaviour only, no pixel change |

Also stand up the **screenshot harness** here (XCUITest + deterministic fixture + diff
script), so parity is measured from the very first screen rather than retrofitted.

**Exit gate:** shots 01, 02, 03, 30, 31 diff ≤2%; a preset split and a custom split can
both be committed and land on Home.

---

## Phase 4 — Main shell · Today · Workouts  · 8u

| # | Task | Source | Reference shots |
|---|---|---|---|
| 4.1 | Custom tab bar + crossfade shell | `App.tsx` `MainShell` | all tab shots |
| 4.2 | `HomeScreen` — header, stat strip, rest-day card, up-next card with watermark | `Home.tsx` (402 L) | `04-home-empty`, `05-home-today`, `10-home-light`, `11-home-violet-dark` |
| 4.3 | `CalendarCard` — month grid, D-tags, activity tags, legend | `Home.tsx` 284–346 | `05`, `24` |
| 4.4 | This-week list + edit mode (reorder, delete, add day) | `Home.tsx` 198–251 | `27-home-edit-week` |
| 4.5 | `LogActivityDialog` — 11 chips, duration, notes, count-as-today switch | `Home.tsx` 348–402 | `25-log-activity` |
| 4.6 | Reset-routine dialog | | `26-reset-dialog` |
| 4.7 | Auto rest-day logging effect (once per calendar day, guarded) | `Home.tsx` 57–63 | |
| 4.8 | `WorkoutsListScreen` + edit mode + exercise preview chips | `WorkoutsList.tsx` (92 L) | `06-workouts` |

**Exit gate:** shots 04, 05, 06, 10, 11, 24, 25, 26, 27 diff ≤2%; rotation "up next"
matches the web given identical fixture data.

---

## Phase 5 — Workout loop  · 12u  *(largest phase)*

| # | Task | Source | Reference shots |
|---|---|---|---|
| 5.1 | `MuscleMap` — 11 regions as `Path` | `MuscleMap.tsx` (118 L) | `17` |
| 5.2 | `ExercisePicker` — search, muscle grouping, custom-exercise form | `ExercisePicker.tsx` (170 L) | `20-exercise-picker` |
| 5.3 | `DayOverviewScreen` — exercises/warmup tabs, switch-day, edit sheet, rest-day variant | `DayOverview.tsx` (228 L) | `12`, `13`, `14`, `15`, `16` |
| 5.4 | `ActiveWorkoutScreen` shell — top bar, progress track, exercise dots, terminals | `ActiveWorkout.tsx` (604 L) | `17-active-workout` |
| 5.5 | `ExerciseContent` — hero, targets, form cues, prescription pill | | `17` |
| 5.6 | Set rows + prefill logic (override → extra-set → same set number → last set → 20 kg default) | `ActiveWorkout.tsx` 283–303 | `17`, `22` |
| 5.7 | `Keypad` — buffer semantics, fresh-clear, quick-add chips, decimal rules | `Keypad.tsx` (95 L) | `18-keypad-weight` |
| 5.8 | Progression suggestion card + "bump to" applying to all undone sets | | |
| 5.9 | Overflow menu: add / replace / remove exercise | | `19-workout-menu` |
| 5.10 | **`RestOverlay`** — wall-clock countdown, SVG-equivalent ring (r=84, C=2πr), ±30 s, skip | | `21-rest-overlay` |
| 5.11 | **Platform**: local notification scheduling/cancellation, `AVAudioSession` beeps, haptics, contextual permission pre-prompt | no web analogue | |
| 5.12 | **Bucket B fixes #5, #6** — ±30 s no longer rewrites the default; reps ≥ 1 required | | |
| 5.13 | `WorkoutCompleteScreen` — PR count, volume delta, bodyweight log | `WorkoutComplete.tsx` (137 L) | `23-workout-complete` |
| 5.14 | `Confetti` — 120 pieces, burst + fall, ported physics | `Confetti.tsx` (152 L) | |
| 5.15 | Session resume across app relaunch (mid-workout, timer still running) | | |

**Exit gate:** shots 12–23 diff ≤2%; a full workout can be logged end-to-end; killing and
relaunching the app mid-workout restores exercise index, logged sets and a still-accurate
rest countdown; the rest notification fires when backgrounded.

---

## Phase 6 — Profile · Settings · Sync  · 8u

| # | Task | Source | Reference shots |
|---|---|---|---|
| 6.1 | `Sparkline` / `DualSparkline` | `Sparkline.tsx` (69 L) | `07` |
| 6.2 | `Heatmap` — 18 weeks, 4 colour buckets, rest-gap autofill | `Heatmap.tsx` (53 L) | `07` |
| 6.3 | `ProfileScreen` — header, totals, range segments, body card + history table | `Profile.tsx` (427 L) | `07-profile` |
| 6.4 | Progression list + PR list with expandable curve | | `07` |
| 6.5 | Edit-profile sheet (name, 10 colours, photo) + log-body sheet | | `28-edit-profile`, `29-log-body` |
| 6.6 | **Platform**: `PhotosPicker` + 256 px downscale | | |
| 6.7 | `SettingsScreen` — theme segments, 10 accent swatches (two-tone pie), units, reset | `Settings.tsx` (211 L) | `08-settings`, `09-settings-light` |
| 6.8 | Export / import via `fileExporter` / `fileImporter` + confirm dialogs | | |
| 6.9 | `GistSync` — push/pull/auto-push, Keychain token, human-readable error mapping | `gist.ts` (109 L) | |

**Exit gate:** shots 07, 08, 09, 28, 29 diff ≤2%; a Gist round-trip succeeds against a real
token; export → import → export is stable.

---

## Phase 7 — Parity sweep & hardening  · 6u

| # | Task |
|---|---|
| 7.1 | Full 31-shot diff run; drive every screen ≤2%; log any accepted deviation with a reason |
| 7.2 | Re-run golden vectors + backup round-trip against the finished app |
| 7.3 | Edge cases: empty routine · day with 0 exercises · every-day-is-rest split · single-exercise workout · 43-char names · huge histories · unit switching mid-session |
| 7.4 | Accessibility: VoiceOver labels on all icon-only controls, Dynamic Type sweep to `.accessibility1`, contrast audit of all 10 accents in **light** mode (web QA #21 flags real failures — decide fix-or-replicate) |
| 7.5 | Performance: Instruments pass on ActiveWorkout (store invalidation), Profile (155-exercise aggregation), snapshot write timing at 30k set logs |
| 7.6 | State restoration, memory-warning behaviour, cold-launch time |
| 7.7 | App Store readiness: icon set from `public/icons/`, launch screen, privacy manifest (no tracking; network only to `api.github.com` when the user configures sync) |

**Exit gate:** all 31 diffs ≤2% or explicitly waived; no P0/P1 open; CI green.

---

## Phase 8 — Optional iOS-native enhancements  · opt-in

Not part of 1:1 parity — these *add* capability the web app doesn't have. Listed for a
decision, not assumed.

Live Activity / Dynamic Island rest timer (~4u) · Home Screen widgets: streak, up-next
(~3u) · App Intents + Siri "start my workout" (~2u) · HealthKit workout write (~3u) ·
Apple Watch companion (~10u) · CloudKit sync alongside the Gist backend (~6u).

---

## Summary

| Phase | Focus | Effort |
|---|---|---|
| 0 | Foundations & toolchain | 3u |
| 1 | Domain & store | 8u |
| 2 | Design system | 7u |
| 3 | Onboarding · first parity gate | 5u |
| 4 | Shell · Today · Workouts | 8u |
| 5 | Workout loop | 12u |
| 6 | Profile · Settings · Sync | 8u |
| 7 | Parity sweep & hardening | 6u |
| | **Total (1:1 parity)** | **57u** |
| 8 | Native enhancements | opt-in |

Phases 1 and 2 overlap, so the critical path is roughly **50u**.

---

## Open decisions — needed before Phase 1

1. **Fidelity buckets** (ARCHITECTURE §8) — confirm the 5 Bucket-B fixes and the Bucket-C
   platform divergences, or move items between buckets. Everything else replicates as-is,
   cosmetic defects included.
2. **Minimum iOS version** — 17.0 proposed. Raising to 18.0 buys little here; lowering to
   16 costs `@Observable` and forces `ObservableObject`.
3. **Dynamic Type** — support with a cap at `.accessibility1` (proposed), or fixed sizes for
   literal pixel parity?
4. **Light-mode accent contrast** (web QA #21: lime-on-light is near-invisible for several
   palettes) — replicate the web exactly, or fix on iOS and back-port to the web?
5. **CI budget** — is a `macos-15` GitHub Actions runner available? Without it there is no
   automated way to compile or screenshot this app from the dev container.
6. **Phase 8** — any of the native enhancements wanted in the first release?
