# Get Gym Done — iOS Architecture

A native SwiftUI reimplementation of [`get-gym-done-web`](https://github.com/pranavchandar/get-gym-done-web),
targeting **visual parity** (the UI is the same UI) and **behavioural parity** (the domain
math, state machines, and data format are bit-identical).

The web app is itself a 1:1 port of the original Android app, so this is the third
implementation of one specification. That is a useful constraint: the spec is already
pinned down in code, in doc comments, and in a shared JSON interchange format.

---

## 1. What we are replicating

**Source of truth:** `get-gym-done-web` @ `claude/ios-gym-done-architecture-kg5qh3`
(5,392 lines of TS/TSX, zero runtime dependencies beyond React, React Router and Zustand).

| Layer | Files | Lines | Nature |
|---|---|---|---|
| Domain logic | `src/domain/*.ts` (6) | 356 | Pure functions, fully doc-commented |
| Store + selectors + seed | `src/store/*.ts` (3) | 915 | Single persisted state tree |
| Backup + cloud sync | `src/backup`, `src/sync` | 251 | JSON v2 interchange, GitHub Gist |
| Design system | `src/styles/global.css`, `src/theme/*` | 533 | CSS custom properties, 10 accents |
| Components | `src/components/*.tsx` (10) | 758 | All hand-rolled, no UI library |
| Screens | `src/screens/*.tsx` (11) | 2,472 | |
| Seed catalog | `src/data/seed_data.json` | — | 155 exercises, 7 preset splits |

**Reference screenshots:** 31 states captured at 390×844 @2x (`docs/parity/web-reference/`),
covering dark + light themes, two accent palettes, empty + populated data, and every
sheet, dialog and overlay. Capture script: `docs/parity/capture-web-reference.mjs`.

### 1.1 Three reference sources, one of them canonical

| Source | Standing |
|---|---|
| **`get-gym-done-web`** | **Canonical.** The brief is to replicate this app; where sources disagree, the web wins. |
| `get-gym-done` (Android) | The original implementation. Its `seed_data.json` is **byte-identical** to the web's (SHA-256 `5627340b…`), which confirms the 155-exercise catalog is stable across implementations. Useful for cross-checking domain semantics. |
| `app/reference/Get Gym Done — Master Engineering Handover.pdf` | The 27-page design specification both other apps were built from — tokens, shared components, iconography, navigation model, and per-screen specs, describing itself as "sufficient to rebuild the app pixel- and behaviour-perfect without the source." |

The handover PDF is the **tiebreaker for ambiguity**, not a competing spec: where the web
diverges from it, the web is what we replicate. It is most valuable for things the CSS
doesn't record — original animation curves, spacing rationale, and the icon set's intent.

Note its text layer is scrambled by subsetted fonts with broken `ToUnicode` maps; the body
font decodes with the substitution map in `docs/parity/decode-handover.py`, and the page
PNGs (`app/reference/pages/*.png`) render perfectly. Transcribing it is a Phase 0 task.

---

## 2. Platform decisions

| Decision | Choice | Rationale |
|---|---|---|
| Minimum OS | **iOS 17.0** | `@Observable` maps cleanly onto Zustand's model; `ContentUnavailableView`, `.presentationCornerRadius`. ~95%+ device coverage in 2026. |
| UI framework | **SwiftUI**, no UIKit except where required (haptics, audio session, image resize) | The web UI is entirely custom-drawn; SwiftUI's declarative model mirrors React closely enough that screens port structurally 1:1. |
| Dependencies | **None** | Matches the web app's minimal footprint. Everything needed (Path, Canvas, TimelineView, URLSession, Keychain) is in the SDK. |
| Orientation / idiom | iPhone, portrait only | Web app is phone-first with a 480px max width. iPad runs in compatibility mode; a centered max-width column (as the web does on desktop) is a Phase 8 nicety. |
| Project generation | **XcodeGen** (`project.yml`) | Text-based, reviewable in PRs, authorable without Xcode — which matters because this repo is developed in a Linux container (§9). |
| Logic packaging | **SwiftPM package `GymDoneKit`** | Domain + store + backup compile and test without Xcode or a simulator, so CI can verify the parts that carry the accuracy risk. Also structurally forbids SwiftUI from leaking into logic. |

---

## 3. Module layout

Deliberately mirrors the web tree file-for-file so a reviewer can diff the two side by side.

```
Get-gym-done-ios/
├── project.yml                          # XcodeGen
├── GymDoneKit/                          # SwiftPM — pure logic, no SwiftUI
│   ├── Sources/GymDoneKit/
│   │   ├── Types.swift                  ← src/types.ts
│   │   ├── Domain/
│   │   │   ├── Dates.swift              ← domain/dates.ts
│   │   │   ├── Metrics.swift            ← domain/metrics.ts
│   │   │   ├── Progression.swift        ← domain/progression.ts
│   │   │   ├── Rotation.swift           ← domain/rotation.ts
│   │   │   ├── Streak.swift             ← domain/streak.ts
│   │   │   └── Units.swift              ← domain/units.ts
│   │   ├── Store/
│   │   │   ├── StoreData.swift          ← store/store.ts   (state shape)
│   │   │   ├── AppStore.swift           ← store/store.ts   (actions)
│   │   │   ├── Selectors.swift          ← store/selectors.ts
│   │   │   ├── Seed.swift               ← store/seed.ts
│   │   │   └── Persistence.swift        ← zustand `persist` middleware
│   │   ├── Backup/Backup.swift          ← backup/backup.ts
│   │   ├── Sync/GistSync.swift          ← sync/gist.ts
│   │   └── Resources/seed_data.json     ← data/seed_data.json (byte-identical)
│   └── Tests/GymDoneKitTests/
│       ├── ProgressionTests.swift
│       ├── StreakTests.swift
│       ├── RotationTests.swift
│       ├── UnitsTests.swift
│       ├── MetricsTests.swift
│       ├── BackupRoundTripTests.swift
│       └── Vectors/*.json               # generated from the TS implementation (§8.3)
├── App/
│   ├── GetGymDoneApp.swift              ← main.tsx
│   ├── RootView.swift                   ← App.tsx (routing + onboarding gate)
│   ├── Theme/
│   │   ├── Palettes.swift               ← theme/palettes.ts
│   │   ├── Tokens.swift                 ← global.css `:root` custom properties
│   │   ├── Typography.swift             ← global.css typography scale
│   │   └── ThemeEnvironment.swift       ← theme/apply.ts
│   ├── Components/                      ← components/*.tsx
│   │   ├── Icons.swift, Primitives.swift, SheetPresentation.swift,
│   │   ├── Toast.swift, Avatar.swift, Keypad.swift, ExercisePicker.swift,
│   │   ├── MuscleMap.swift, Sparkline.swift, Heatmap.swift, Confetti.swift
│   ├── Screens/                         ← screens/*.tsx (11 files, same names)
│   ├── Platform/                        # no web analogue (§7)
│   │   ├── RestNotifications.swift, RestAlarm.swift,
│   │   ├── Keychain.swift, DocumentIO.swift, ImageResize.swift
│   └── Resources/Fonts/{Anton-Regular,Inter-*}.ttf
├── UITests/                             # screenshot parity harness (§8.2)
└── docs/
    ├── ARCHITECTURE.md  ACTION-PLAN.md
    └── parity/web-reference/*.png       # 31 reference shots
```

---

## 4. Data & persistence

### 4.1 Decision: single Codable snapshot, **not** SwiftData / Core Data

The web persists one JSON blob under `localStorage["get-gym-done:v1"]`. We keep exactly
that shape, serialised to a file.

**Why not SwiftData**, despite it being the "native" answer:

1. **The interchange format is flat JSON.** `BackupFile` v2 is the contract with the
   Android app and the web app. With a snapshot store, export *is* the store — no mapping
   layer, so no place for drift to hide.
2. **Every selector operates over dictionaries.** `Selectors.swift` ports from
   `selectors.ts` as near-identical code. Rewriting 12 selectors as `FetchDescriptor`
   predicates is precisely where behavioural divergence would creep in, and behavioural
   accuracy is the top requirement.
3. **The dataset is small and bounded** (§4.3).
4. **No migration machinery needed.** The `seedVersion` merge logic in `ensureSeeded`
   ports directly; SwiftData would add schema versioning on top of it.

### 4.2 Implementation

- `StoreData: Codable, Sendable` — same `[String: T]` dictionaries, same JSON key names as
  the web blob, so a raw `localStorage` dump can be dropped in unmodified.
- Location: `Application Support/get-gym-done/v1.json`, excluded from iCloud backup? **No** —
  included, so device restore keeps history (the web has no equivalent, this is free on iOS).
- Atomic writes: encode off-main → write to `.tmp` → `FileManager.replaceItemAt`.
- Debounced 400 ms; forced flush on `scenePhase` leaving `.active` and on
  `willTerminate`.
- A corrupt/unreadable file falls back to a fresh store **and** side-files the bad payload
  as `v1.corrupt-<timestamp>.json` rather than silently discarding it.

### 4.3 Scale

| Usage | Set logs | Snapshot size | Encode time (off-main) |
|---|---|---|---|
| 1 year @ 5 sessions/wk × 25 sets | ~6,500 | ~1.3 MB | ~20 ms |
| 5 years | ~32,500 | ~6.5 MB | ~80 ms |

Debounced writes make this a non-issue. Documented escape hatch if a user ever exceeds
~50k set logs: swap `Persistence.swift` for an append-only log with periodic compaction.
Contained to one file; the rest of the app is unaffected.

---

## 5. State management

| Zustand (web) | SwiftUI (iOS) |
|---|---|
| `create<Store>()(persist(...))` | `@MainActor @Observable final class AppStore` |
| `useStore(s => s.prefs.theme)` | `store.data.prefs.theme` — Observation tracks property reads automatically |
| `set(s => ({ ... }))` | direct mutation of the `StoreData` struct |
| `selectors.ts` module | free functions `func activeSplit(_ s: StoreData) -> Split?` — identical signatures |
| `persist` middleware | `didSet` on `data` → debounced `save()` |
| `getState()` for non-hook access | `store.data` (already a value type) |

Injected once at the root with `.environment(store)`; consumed with
`@Environment(AppStore.self) private var store`.

### Two invalidation gotchas, both already solved by the web's own design

1. **Whole-tree invalidation.** `StoreData` is one struct, so any mutation invalidates every
   view reading it. The web has the same property (`Home.tsx` calls `useStore()` unscoped).
   Acceptable — *provided* nothing high-frequency lives in the store.
2. **The rest timer ticks at 5 Hz.** The web keeps the ticking `now` in component state and
   only `restEndAt` (a wall-clock epoch) in the store. We do the same: `TimelineView`
   drives the countdown locally; the store holds only the deadline. Likewise
   `ActiveWorkout`'s ephemeral `extra` / `removed` / `overrides` dictionaries stay in
   `@State`, exactly as in the web.

---

## 6. Navigation

| Web route | iOS presentation |
|---|---|
| `/splash` | Root branch when `!prefs.onboardingComplete` |
| `/pick-split` | push — onboarding `NavigationStack` |
| `/routine-method/:splitId` | push |
| `/customize`, `/customize/:seedSplitId` | push |
| `/home` → `MainShell` (4 tabs) | Root branch when onboarding complete |
| `/day/:dayId` | push, inside the active tab's stack |
| `/workout/:dayId` | `.fullScreenCover` — matches the web's chrome-less takeover and its ✕-to-close affordance |
| `/complete/:sessionId` | `.fullScreenCover`, replacing the workout cover |
| `*` → `Navigate to="/"` | Not representable — typed routes make bad IDs impossible |

`Route: Hashable` enum + one `NavigationPath` per tab.

**Tab bar is custom, not `TabView`'s.** The web's bar is 10 px uppercase 1.2-tracked labels
over `--surface` with a 1 px top hairline and accent-tinted active state — none of which
`UITabBar` can be styled into. `MainShell` literally swaps content with a 0.2 s crossfade,
so the faithful port is a `ZStack` + `.transition(.opacity)` with a custom `HStack` bar
pinned via `.safeAreaInset(edge: .bottom)`.

The three terminal states in `ActiveWorkout` (`NOT FOUND`, `REST DAY`, `NOTHING TO DO`)
must be preserved — the latter two are reachable through real state, not just bad URLs.

---

## 7. Design system port

### 7.1 Typography — the highest-risk area for pixel parity

The web scale is 13 classes from `.display-large` (Anton 56/56, +0.5 tracking, uppercase)
down to `.label-small` (Inter 700 10/12, +1.6 tracking, uppercase).

**The gotcha:** CSS `line-height` sets the line box directly. SwiftUI derives line height
from font metrics and `.lineSpacing` *adds* to it. Anton's ascent+descent at 56 pt exceeds
56 px, so a naive port renders visibly taller and mis-baselined.

**Solution:** one `TypeStyle` value per CSS class, applied through a single
`.typeStyle(.displayLarge)` modifier that sets `.font(.custom(…, size:relativeTo:))`,
`.tracking(...)`, `.lineSpacing(target − UIFont.lineHeight)` and a compensating negative
vertical padding. Calibrated once against the reference screenshots, then every screen
inherits correct metrics. This deserves a dedicated calibration pass (Phase 2) with a
side-by-side type-specimen diff.

`text-transform: uppercase` has no SwiftUI equivalent — the `TypeStyle` carries an
`uppercase` flag and the modifier applies `.uppercased()`.

**Dynamic Type:** the web is fixed-size. We use `relativeTo:` so text scales, capped at
`.accessibility1` on the dense screens (ActiveWorkout, Home stat strip) to protect the
fixed layouts. *This is an intentional deviation* — flagged in §8.1 Bucket C.

### 7.2 Colour

`:root` custom properties → a `ThemeTokens` struct with light/dark variants, plus the 10
accent palettes ported verbatim from `palettes.ts`. Recomputed when `prefs.theme` or
`prefs.accent` changes and pushed into `@Environment(\.theme)` at the root — the same
single-source-of-truth shape as the CSS `data-theme` / `data-accent` attributes.

- `color-mix(in srgb, X p%, Y)` (heatmap buckets, selected split card) → a `Color.mix`
  helper operating in sRGB.
- The `.ob` onboarding scope — fixed lime-on-near-black regardless of the user's theme —
  becomes a `ThemeTokens` override injected into the onboarding subtree only.

### 7.3 Icons — ported as `Path`, not SF Symbols

The web ships 24 hand-rolled 24×24 stroke icons (`icons.tsx`, Feather-style: 2 pt stroke,
round caps and joins). SF Symbols are *close* but not identical — different terminals and
optical weights — and would visibly break "exactly the same", while also drifting between
OS versions.

So each icon becomes a SwiftUI `Shape` on the same 24×24 space with
`.stroke(lineWidth: 2, lineCap: .round, lineJoin: .round)`. ~85 lines of TSX → ~250 lines of
Swift; entirely mechanical and verifiable with an icon-sheet diff.

### 7.4 Component mapping

| Web | iOS |
|---|---|
| `.big-cta` / `.ghost-cta` / `.icon-btn` / `.text-link` | `BigCTAButton` / `GhostCTAButton` / `IconButton` / `TextLink` |
| `.pill`, `.chip`, `.badge`, `.day-chip` | `PillChip`, `Chip`, `Badge`, `DayChip` |
| `.stepper` (+ `.mini`) | `StepperControl(mini:)` — custom; native `Stepper` can't match |
| `.seg` | `SegTabs` — custom; `Picker(.segmented)` can't match |
| `.switch`, `.radio-dot` | custom; native `Toggle` / no native radio |
| `.card`, `.stat-pill`, `.split-card`, `.set-row` | container views |
| `.striped` placeholder | `Canvas` drawing the repeating −45° line pattern |
| `.track` progress | `Capsule` + `GeometryReader` |
| `.sheet` (bottom, 88 vh, 22 pt radius, drag handle) | `.sheet` + `.presentationDetents([.fraction(0.88)])` + `.presentationDragIndicator(.visible)` + `.presentationCornerRadius(22)` |
| `.dialog` (centered, 420 pt max, `pop` animation) | custom `ZStack` overlay — needed to match the scale-in and the exact inset |
| `.rest-overlay` | full-screen `ZStack` overlay, `.transition(.opacity)` |
| `.toast-wrap` | root `ToastHost` overlay; same 2,600 ms lifetime and bottom offset |
| `.watermark` (120 pt Anton @ 12%, overflow-hidden) | `.overlay(alignment: .topTrailing)` + `.clipped()` |
| `.cal-grid` | `LazyVGrid`, 7 columns, `aspectRatio(1)` |
| `.confetti-canvas` | `Canvas` + `TimelineView`, physics ported 1:1 |
| `MuscleMap` (11 SVG regions, 100×200 viewBox) | `Path` — `Q` → `addQuadCurve`, scaled by `GeometryReader` |
| `Sparkline` / `DualSparkline` / `Heatmap` | `Path` / `Canvas`, direct ports |

---

## 8. Fidelity policy — **fix the defects** (confirmed)

The web app ships with 42 documented defects
(`get-gym-done-web/docs/qa/UI-TEARDOWN-REPORT.md`), three of which cause unrecoverable
data loss. **The decision is to fix all of them.** Full dispositions are in
[`DEFECT-LEDGER.md`](./DEFECT-LEDGER.md); the summary:

| Disposition | Count |
|---|---|
| Fixed, behaviour only — the screen must still match the reference pixel for pixel | 6 |
| Fixed, deliberately changes pixels — logged in the deviation register (§9.1) | 34 |
| N/A on iOS — #4 solved by the platform, #37 is React-Router-specific | 2 |

What this does **not** change: the visual language. Every fix is a correction *within* the
app's existing design system — same tokens, same type scale, same components, same
iconography. Nothing is redesigned for its own sake, and the 31 reference screenshots
remain the specification for everything not named in the ledger.

Two consequences worth stating plainly:

1. **Roughly a third of the fixes move pixels** — corrected pluralisation, unit suffixes,
   a resume-workout state, WCAG-compliant accents in light mode. A blunt "≤2% diff on every
   screen" gate would therefore fail by design, which is why §9.1 replaces it with a
   deviation register.
2. **Two items go beyond porting.** Fixing "logged history is write-only" (#26, #36)
   requires a **session detail sheet that exists in none of the three implementations** —
   new design, built in the existing visual language. And exercise artwork (#11) has no
   source: `seed_data.json` names an `illustrationFilename` for all 155 exercises, but no
   image assets exist in the web repo, the Android repo, or the handover PDF. The code-side
   fix is the `MuscleMap` silhouette fallback; real illustrations are a content decision,
   not a code task.

### Platform-mandated divergence

Independent of the defect list: Keychain for the Gist token (not `localStorage`); local
notifications for rest-timer completion (iOS suspends timers, the web relies on a live tab);
share-sheet export and `fileImporter` in place of anchor-download / `<input type=file>`;
`PhotosPicker`; Dynamic Type; interactive back-swipe.

---

## 9. Verification strategy

Two independent guarantees, one for pixels and one for behaviour.

### 9.1 Visual parity — screenshot diffing against a deviation register

- **Reference corpus:** the 31 captured web states, 390×844 @2x (`docs/parity/web-reference/`).
- **Device match:** **iPhone 14 simulator is exactly 390×844** — the same logical viewport as
  the capture, so diffs are meaningful without rescaling.
- **iOS harness:** an XCUITest target that seeds the *same deterministic fixture* used for
  the web capture (fixed timestamps, fixed RNG, not `Date.now()`), walks the same 31 states,
  and writes PNGs.
- **Determinism:** the domain functions already take an injectable `now` parameter
  (`currentStreakDays(sessions, maxRestGap, now = Date.now())`), so freezing the clock ports
  cleanly. Animations disabled during capture.

**The gate.** Because 34 defect fixes deliberately change pixels, a flat threshold would
reject correct work. Instead every intentional change is declared up front in
`docs/parity/deviations.yml`:

```yaml
- screen: 05-home-today
  defect: 18          # "29 sessions" pluralisation
  region: [24, 1040, 340, 1080]   # x, y, w, h in reference pixels
  reason: "Calendar header pluralisation fix"
```

The diff script then classifies every differing pixel as **declared** (inside a registered
region for that screen) or **undeclared**. Declared regions are reported and eyeballed;
**undeclared difference is gated at ≤2% non-antialiasing pixels**. So the check becomes
"the only things that differ are the things we said would differ" — which is a stronger
guarantee than a blanket percentage, and it keeps the reference corpus meaningful instead
of quietly rotting as fixes land.

A screen whose fix is behaviour-only (6 of them) has no register entry and must match
outright.

### 9.2 Behavioural parity — golden vectors generated from the web

The strongest available guarantee, and cheap:

1. Run the **TypeScript** implementations of `weightIncreaseSuggestion`, `currentStreakDays`,
   `longestStreakDays`, `nextWorkoutDay`, `maxConsecutiveRestDays`, `countPRs`,
   `compactNumber` and the whole of `units.ts` over a few thousand pseudo-random inputs.
2. Dump `input → output` pairs to `GymDoneKit/Tests/Vectors/*.json`.
3. Assert the Swift implementations reproduce them exactly.

This turns "perfect accuracy" from an aspiration into a CI gate, and it catches the subtle
cases the doc comments describe but tests usually miss — the ±1e-3 weight-equality
tolerance in progression, the rest-gap bridging in streaks, the wrap-around in rotation.

Additionally: **backup round-trip** — export from web → import to iOS → export from iOS →
assert JSON-equal modulo `exportedAt`; and the same against an Android export.

### 9.3 Build & CI — a hard environment constraint

**This repo is developed in a Linux container with no Swift toolchain, no Xcode and no
simulator.** SwiftUI code can be authored here but not compiled or run here. That has to be
solved in Phase 0, not discovered in Phase 5.

**Resolved:** a **GitHub Actions `macos-15` runner** doing `xcodebuild build` +
`swift test` (GymDoneKit) + `xcrun simctl` screenshot capture + the parity diff, on every
push. `pranavchandar/Get-gym-done-ios` is a **public** repository, so macOS runner minutes
are free — no budget constraint. `GymDoneKit` additionally builds and tests on the Linux
runner, giving fast feedback on the accuracy-critical layer in seconds rather than minutes.

---

## 10. Platform work with no web analogue

| Area | Web | iOS |
|---|---|---|
| Rest timer in background | Relies on the tab staying alive | Wall-clock `restEndAt` (already the design) **plus** a `UNCalendarNotificationTrigger` scheduled on backgrounding, cancelled on skip / adjust / foreground fire |
| Notification permission | Requested on first workout mount, with no context (QA #12) | Requested *after* the first rest timer starts, behind a one-line pre-prompt |
| Alarm sound | WebAudio 2×880 Hz beeps | Same two beeps via `AVAudioPlayer`, `AVAudioSession` `.ambient` so music isn't ducked and the silent switch is respected |
| Haptics | `navigator.vibrate([200,100,200])` | `UINotificationFeedbackGenerator().notificationOccurred(.success)` |
| Token storage | `localStorage` | Keychain, `kSecAttrAccessibleAfterFirstUnlock` |
| Export / import | `<a download>` / `<input type=file>` | `.fileExporter` + share sheet / `.fileImporter` |
| Avatar photo | `<input type=file>` + canvas resize | `PhotosPicker` + `CGImageSource` downscale to 256 px JPEG q0.85, base64 in prefs (keeps backup-format compatibility) |
| Keyboard | Native | `.scrollDismissesKeyboard(.interactively)`, `.safeAreaInset` CTAs |

---

## 11. Risk register

| # | Risk | Severity | Mitigation |
|---|---|---|---|
| 1 | Anton line-height mismatch throws off every screen's vertical rhythm | **High** | Dedicated Phase 2 calibration pass + type-specimen diff before any screen is built |
| 2 | No Mac/Xcode in the dev container — SwiftUI can't be compiled where it's written | **High** | Phase 0 sets up the macOS CI runner; `GymDoneKit` stays Linux-buildable for fast local feedback |
| 3 | Whole-store invalidation degrades ActiveWorkout | Medium | Tick state stays local (§5); measure with Instruments in Phase 5 |
| 4 | 24 hand-translated icon paths drift from the SVGs | Medium | Icon-sheet screen diffed against a matching web icon sheet |
| 5 | `seed_data.json` drifts from the web copy | Medium | Bundle byte-identical; CI checksums it against the web repo |
| 6 | Snapshot write amplification at large histories | Low | Debounce + documented append-log escape hatch (§4.3) |
| 7 | Sheet detent chrome (grabber, corner radius) doesn't match `.sheet` CSS exactly | Low | Fall back to a custom overlay presentation if the diff gate fails |

---

## 12. Out of scope for 1:1 parity

Deliberately excluded, matching the web port's own scope cuts: friends/social/Firebase,
QR codes, exercise-media uploads, the debug screen.

**Optional iOS-native enhancements** (Phase 8, opt-in — these *add* to the web app rather
than replicate it, so they are listed for a decision, not assumed):
Live Activity / Dynamic Island rest timer · Home Screen widgets (streak, up-next) ·
App Intents + Siri ("start my workout") · HealthKit workout write · Apple Watch companion ·
iCloud/CloudKit sync alongside the Gist backend.
