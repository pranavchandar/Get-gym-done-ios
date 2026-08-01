# Get Gym Done — iOS

A native SwiftUI reimplementation of [`get-gym-done-web`](https://github.com/pranavchandar/get-gym-done-web),
built for visual parity (same UI, pixel for pixel) and behavioural parity (same domain
maths, same state machines, same `BackupFile` v2 interchange format as the web and Android
apps).

**No code yet — this repo currently holds the plan.**

| Document | What's in it |
|---|---|
| [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) | Platform decisions, module layout, persistence, state management, navigation, design-system port, fidelity policy, verification strategy, risk register |
| [`docs/ACTION-PLAN.md`](docs/ACTION-PLAN.md) | Nine phases with deliverables and objective exit gates, effort estimates, open decisions |
| [`docs/parity/web-reference/`](docs/parity/web-reference/) | 31 reference screenshots of the web app at 390×844 @2x — the visual spec |
| [`docs/parity/capture-web-reference.mjs`](docs/parity/capture-web-reference.mjs) | Playwright script that produced them, re-runnable when the web app changes |

## Reference corpus

Captured from the web app at 390×844 (the exact logical viewport of an iPhone 14
simulator, so diffs need no rescaling), covering both themes, two accent palettes, empty
and populated data, and every sheet, dialog and overlay.

Onboarding `01`–`03`, `30`–`31` · Today `04`–`05`, `10`–`11`, `24`–`27` · Workouts `06` ·
Profile `07`, `28`–`29` · Settings `08`–`09` · Day overview `12`–`16` ·
Active workout `17`–`22` · Complete `23`
