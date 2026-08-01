# Defect ledger

All 42 findings from `get-gym-done-web/docs/qa/UI-TEARDOWN-REPORT.md`, each with its
disposition on iOS.

**Policy: fix everything.** One item (#37) is React-Router-specific and has no iOS analogue;
one (#4) is fixed for free by the platform. The remaining 40 are fixed in the phase that
owns the surface.

The **Visual** column matters for the parity gate: `no` means the fix is behaviour-only and
the screen must still match the web reference pixel for pixel; `yes` means the fix
deliberately changes pixels, so the screen gets an entry in the **deviation register**
(ARCHITECTURE §9.1) and its diff is reviewed against the reference *plus* that registered
change, rather than being auto-gated.

| # | Sev | Defect | Fix on iOS | Visual | Phase |
|---|---|---|---|---|---|
| 1 | P0 | Import accepts any JSON object and wipes all data, with a success toast | Validate `version == 2` + required arrays before enabling Replace; auto safety-export first; error state for invalid files | no | 1 |
| 2 | P0 | "Rest day" checkbox permanently deletes that day's exercises | Keep the list in the draft; hide it while `isRestDay` | no | 3 |
| 3 | P0 | Days-per-week stepper roundtrip destroys trimmed days | Retain removed days for the screen's lifetime; drop only on commit | no | 3 |
| 4 | P1 | `.screen-scroll` never scrolls; position bleeds across tabs | N/A — a per-tab `ScrollView` gets this right by construction | no | 4 |
| 5 | P1 | Rest ±30 s silently rewrites the default rest duration | Apply ± to the running timer only; add "Default rest" to Settings → Workout | yes | 5, 6 |
| 6 | P1 | 0 kg × 0 rep sets log without validation | Require reps ≥ 1; weight 0 stays legal but is labelled (see #33) | no | 5 |
| 7 | P1 | Finishing with entirely un-logged exercises is silent | Confirm dialog listing unfinished exercises | yes | 5 |
| 8 | P1 | No "workout in progress" indicator anywhere | Up-next card becomes "Resume workout · 12 min" while a session is live | yes | 4 |
| 9 | P1 | Body metrics accept absurd values (300% body fat) | Clamp: fat 2–70%, weight 20–400 kg, muscle 5–200 kg, with inline errors | yes | 6 |
| 10 | P1 | Empty training day shows an enabled Start CTA leading to a dead end | Disable and swap to "Add exercises", opening the edit sheet | yes | 5 |
| 11 | P1 | Placeholder striped artwork in the core flow | Replace with the existing `MuscleMap` silhouette as the exercise hero and thumbnail; drop the "illustration"/"gif" labels. **Real artwork is a content task, not a code task** — no exercise images exist in any of the three repos | yes | 5 |
| 12 | P1 | Notification permission requested with no context on first workout | Ask after the first rest timer starts, behind a one-line pre-prompt | yes | 5 |
| 13 | P2 | Home ↺ button is a destructive reset disguised as refresh; Settings reset skips its confirm | Remove from Home; Settings owns it and gets the confirm dialog | yes | 4, 6 |
| 14 | P2 | ⇄ on the up-next card opens Day Overview; same icon means "switch day" elsewhere | Use a list icon + "Preview" for day overview; ⇄ stays switch-day only | yes | 4 |
| 15 | P2 | Onboarding copy references a PDF that doesn't exist in the app | "Use the preset as-is, or assemble exercises day-by-day." | yes | 3 |
| 16 | P2 | Step progress bar appears only on step 1 of 3 | Render on all three steps | yes | 3 |
| 17 | P2 | Splash theme toggle changes nothing (splash is hard-coded dark) | Restyle as an explicit "Dark mode" switch that visibly applies | yes | 3 |
| 18 | P2 | "1 sessions", "1 exercises", "1 PRs"; "· logged." fragment; "NEW" under VOL | Proper pluralisation throughout; show first-session volume with a "first time" note | yes | 4, 5 |
| 19 | P2 | lbs mode leaks raw conversions (44.09 lbs; steps to 46.59) | Round display to 0.5 lb; snap prefills and steps to 2.5/5 lb increments | yes | 1, 5 |
| 20 | P2 | Missing unit labels ("82.5", "TOTAL VOLUME 360") | Unit suffix on every weight and volume stat | yes | 4, 6 |
| 21 | P2 | Light-theme accent contrast failures across several of the 10 palettes | Per-theme accent-on-background text colour meeting WCAG AA; audit all 10 × 2 | yes | 2 |
| 22 | P2 | Replaced exercise is labelled "· ADDED" | Label "· REPLACED" | yes | 5 |
| 23 | P2 | Stale toasts stack over the completion screen | Clear the queue on navigation; cap to one visible toast | yes | 2, 5 |
| 24 | P2 | Confetti replays on every later Home visit if once interrupted | Consume the flag on first mount, not on animation end | no | 5 |
| 25 | P2 | "Streak" and "This week" disagree; "this week" is a rolling 7 days | Align definitions; relabel "LAST 7 DAYS"; count activities consistently | yes | 4 |
| 26 | P2 | Calendar: workout hides activity, past days not tappable, legend incomplete | Stack multiple entries; tap a past day → **session detail sheet** (new); extend the legend | yes | 4 |
| 27 | P2 | Workouts tab preview chips clipped mid-word | "+N more" overflow chip | yes | 4 |
| 28 | P2 | Custom exercise form defaults to Abductors / Band (first alphabetically) | Default Chest / Barbell, or an explicit "Select…" with validation | yes | 5 |
| 29 | P2 | Profile name silently truncated at 20 characters | Allow longer, ellipsize the display, show a counter near the limit | yes | 6 |
| 30 | P2 | Warmup tab is boilerplate; "Start warmup" actually starts the workout | Derive focus from the day's exercises' primary muscles; rename the CTA | yes | 5 |
| 31 | P2 | Rest overlay blocks the whole screen | Collapsible pill/bottom-bar timer state so sets and cues stay reachable | yes | 5 |
| 32 | P2 | Rest-day overview: bed icon pinned left while text is centered | Center the icon in the stack | yes | 5 |
| 33 | P2 | Bodyweight exercises prefill 20 kg like barbell moves | Per-equipment default; bodyweight shows "BW" with an optional "+kg" | yes | 5 |
| 34 | P2 | Seed data: Decline Crunch tagged `Bodyweight` equipment; MuscleMap glutes are a 4 px sliver | Audit all 155 entries; redraw the glute/hamstring region | yes | 2, 6 |
| 35 | P2 | Cloud sync surfaces raw "Failed to fetch"; duplicated empty-state copy | Map to human messages (offline, 401 → token/scopes); single state line | yes | 6 |
| 36 | P2 | Session summaries can't be revisited — logged history is write-only | **Session detail sheet** (new), reachable from the calendar and Workouts | yes | 4 |
| 37 | P3 | React Router future-flag console warnings | **N/A on iOS** | — | — |
| 38 | P3 | "~11 min per exercise" is crude and duplicated in two screens | Centralise: sets × (rest + ~40 s) | yes | 4, 5 |
| 39 | P3 | Day name persists when a customize-draft day is marked Rest | Clear or grey the field while Rest is on | yes | 3 |
| 40 | P3 | Empty routine name commits silently as "My Routine" | Show the fallback in the field, or validate inline | yes | 3 |
| 41 | P3 | "Count as today's workout" switch has no explanation | Helper text: "Marks Day 2 · Pull A as done." | yes | 4 |
| 42 | P3 | Icon-only top bars on Day Overview | Visible labels or text buttons alongside the icons | yes | 5 |

## Summary

| Disposition | Count |
|---|---|
| Fixed, behaviour only — screen must still match the reference | 6 |
| Fixed, deliberately changes pixels — deviation register entry | 34 |
| N/A on iOS | 2 (#4 platform-solved, #37 web-only) |

## Two items that go beyond "port the web app"

1. **Session detail sheet** (#26, #36) — the web app has no way to revisit a logged session,
   so fixing it means designing a screen that does not exist in any of the three
   implementations. Proposed: a sheet listing that day's sessions with per-exercise sets,
   weights, reps and volume, reachable by tapping a completed calendar day. New design, built
   in the app's existing visual language.
2. **Exercise artwork** (#11) — `seed_data.json` references `illustrationFilename` for all 155
   exercises, but no image assets exist in the web repo, the Android repo, or the handover
   PDF. The code-side fix is the `MuscleMap` silhouette fallback; shipping real illustrations
   is a separate content decision.
