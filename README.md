# Get Gym Done — iOS

A native SwiftUI reimplementation of [`get-gym-done-web`](https://github.com/pranavchandar/get-gym-done-web),
built for visual parity (same UI, pixel for pixel) and behavioural parity (same domain
maths, same state machines, same `BackupFile` v2 interchange format as the web and Android
apps).

**No code yet — this repo currently holds the plan, which is final.**

| Document | What's in it |
|---|---|
| [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) | Platform decisions, module layout, persistence, state management, navigation, design-system port, fidelity policy, verification strategy, risk register |
| [`docs/ACTION-PLAN.md`](docs/ACTION-PLAN.md) | Nine phases with deliverables and objective exit gates, effort estimates, resolved decisions |
| [`docs/DEFECT-LEDGER.md`](docs/DEFECT-LEDGER.md) | All 42 known web-app defects with their disposition, visual impact and owning phase |
| [`docs/parity/web-reference/`](docs/parity/web-reference/) | 31 reference screenshots of the web app at 390×844 @2x — the visual spec |
| [`docs/parity/capture-web-reference.mjs`](docs/parity/capture-web-reference.mjs) | Playwright script that produced them, re-runnable when the web app changes |
| [`docs/parity/decode-handover.py`](docs/parity/decode-handover.py) | Decodes the scrambled text layer of the original Android handover PDF |

## Reference sources

The **web app is canonical** — it is what gets replicated. Two supporting sources:
the original Android app (`pranavchandar/get-gym-done`), whose `seed_data.json` is
byte-identical to the web's; and its 27-page *Master Engineering Handover* PDF, the design
spec both existing apps were built from, used as a tiebreaker for ambiguity.

## Defect policy

All 42 documented defects in the web app are **fixed**, not replicated — including three
that cause unrecoverable data loss. Because ~34 of those fixes deliberately move pixels,
the screenshot-parity gate works against a declared deviation register rather than a flat
threshold: the check is *"the only things that differ are the things we said would differ."*

## Reference corpus

Captured from the web app at 390×844 (the exact logical viewport of an iPhone 14
simulator, so diffs need no rescaling), covering both themes, two accent palettes, empty
and populated data, and every sheet, dialog and overlay.

Onboarding `01`–`03`, `30`–`31` · Today `04`–`05`, `10`–`11`, `24`–`27` · Workouts `06` ·
Profile `07`, `28`–`29` · Settings `08`–`09` · Day overview `12`–`16` ·
Active workout `17`–`22` · Complete `23`
