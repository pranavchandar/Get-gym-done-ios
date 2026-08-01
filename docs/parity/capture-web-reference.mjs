// Captures the web app's reference corpus — the visual specification the iOS app is
// diffed against.
//
// Size is parameterised because the CI runner image decides which simulator is
// available, and the corpus must match that device's logical viewport for a pixel
// diff to mean anything. Defaults to 390x844 (iPhone 12/13/14).
//
//   node capture-web-reference.mjs [--width 390] [--height 844] [--scale 2] [--out DIR]
//
// Requires the web app running locally (npm run dev in get-gym-done-web).

import { chromium } from 'playwright';
import fs from 'node:fs';

const argv = new Map();
for (let i = 2; i < process.argv.length; i += 2) {
  argv.set(process.argv[i].replace(/^--/, ''), process.argv[i + 1]);
}
const WIDTH = Number(argv.get('width') ?? 390);
const HEIGHT = Number(argv.get('height') ?? 844);
const SCALE = Number(argv.get('scale') ?? 2);
const OUT = argv.get('out') ?? 'docs/parity/web-reference';
fs.mkdirSync(OUT, { recursive: true });
const BASE = argv.get('base') ?? 'http://127.0.0.1:5173/get-gym-done-web/';
console.log(`capturing ${WIDTH}x${HEIGHT} @${SCALE}x -> ${OUT}`);

const browser = await chromium.launch();
const ctx = await browser.newContext({
  viewport: { width: WIDTH, height: HEIGHT },
  deviceScaleFactor: SCALE,
  isMobile: true,
  hasTouch: true,
  colorScheme: 'dark',
});
const page = await ctx.newPage();
page.on('console', (m) => { if (m.type() === 'error') console.log('PAGE ERR:', m.text()); });

const shot = async (name, full = false) => {
  await page.waitForTimeout(450);
  await page.screenshot({ path: `${OUT}/${name}.png`, fullPage: full });
  console.log('shot:', name, full ? '(full)' : '');
};

// ---------- 1. Onboarding flow ----------
await page.goto(BASE + '#/splash', { waitUntil: 'networkidle' });
await page.waitForTimeout(900);
await shot('01-splash', true);

await page.click('text=Get started');
await page.waitForTimeout(500);
await shot('02-pick-split', true);

await page.click('text=Push Pull Legs');
await page.waitForTimeout(600);
await shot('03-routine-method', true);

await page.click('text=Curate for me');
await page.waitForTimeout(700);
await shot('04-home-empty', true);

// ---------- 2. Inject realistic history ----------
const injected = await page.evaluate(() => {
  const KEY = 'get-gym-done:v1';
  const raw = JSON.parse(localStorage.getItem(KEY));
  const s = raw.state;
  const DAY = 86400000;
  const now = Date.now();
  const uid = () => 'x' + Math.random().toString(36).slice(2, 11);

  const days = Object.values(s.workoutDays)
    .filter((d) => d.splitId === s.prefs.activeSplitId)
    .sort((a, b) => a.dayNumber - b.dayNumber);
  const dayExOf = (dayId) =>
    Object.values(s.dayExercises).filter((d) => d.workoutDayId === dayId).sort((a, b) => a.orderIndex - b.orderIndex);

  const sessions = {}, setLogs = {}, bodyMetrics = {};

  // 8 weeks of history, walking the rotation backwards from 2 days ago
  let cursor = now - 2 * DAY;
  const ordered = [];
  for (let i = 0; i < 34; i++) ordered.push(days[i % days.length]);
  ordered.reverse();

  let t = now - 34 * DAY;
  for (const d of ordered) {
    t += DAY;
    if (t > now - DAY) break;
    const sid = uid();
    if (d.isRestDay) {
      sessions[sid] = { id: sid, workoutDayId: d.id, startedAt: t, completedAt: t, notes: 'rest' };
      continue;
    }
    sessions[sid] = { id: sid, workoutDayId: d.id, startedAt: t - 3600000, completedAt: t, notes: null };
    const exs = dayExOf(d.id);
    const weekIdx = Math.floor((now - t) / (7 * DAY));
    for (const de of exs) {
      const base = 20 + ((de.exerciseId.length * 7) % 60);
      const w = Math.round((base + (8 - weekIdx) * 2.5) / 2.5) * 2.5;
      for (let n = 1; n <= de.prescribedSets; n++) {
        const id = uid();
        setLogs[id] = {
          id, sessionId: sid, exerciseId: de.exerciseId, setNumber: n,
          weightKg: Math.max(10, w), reps: de.prescribedRepsHigh - (n > 2 ? 2 : 0),
          completedAt: t - (de.prescribedSets - n) * 180000, rir: null,
        };
      }
    }
  }
  // body metrics, weekly
  for (let i = 9; i >= 0; i--) {
    const id = uid();
    const at = now - i * 7 * DAY;
    bodyMetrics[id] = {
      id, recordedAt: at,
      bodyweightKg: Math.round((82 - i * 0.45) * 10) / 10,
      bodyFatPct: Math.round((19.5 - i * 0.28) * 10) / 10,
      muscleMassKg: Math.round((36 + i * 0.12) * 10) / 10,
    };
  }
  // one non-lifting activity
  const aid = uid();
  sessions[aid] = { id: aid, workoutDayId: null, startedAt: now - 5 * DAY, completedAt: now - 5 * DAY, notes: 'Easy pace', activityType: 'Running', durationMin: 35 };

  s.sessions = sessions;
  s.setLogs = setLogs;
  s.bodyMetrics = bodyMetrics;
  s.prefs.handle = 'Pranav C';
  localStorage.setItem(KEY, JSON.stringify(raw));
  return { sessions: Object.keys(sessions).length, logs: Object.keys(setLogs).length };
});
console.log('injected:', JSON.stringify(injected));

// ---------- 3. Main tabs ----------
await page.goto(BASE + '#/home', { waitUntil: 'networkidle' });
await page.reload({ waitUntil: 'networkidle' });
await page.waitForTimeout(1100);
await shot('05-home-today', true);

await page.click('.tabbar button:nth-child(2)');
await shot('06-workouts', true);
await page.click('.tabbar button:nth-child(3)');
await page.waitForTimeout(700);
await shot('07-profile', true);
await page.click('.tabbar button:nth-child(4)');
await shot('08-settings', true);

// light theme + alt accent
await page.click('.seg button:has-text("light")');
await page.waitForTimeout(400);
await shot('09-settings-light', true);
await page.click('.tabbar button:nth-child(1)');
await shot('10-home-light', true);
await page.click('.tabbar button:nth-child(4)');
await page.click('.swatch-grid button:nth-child(5)'); // violet
await page.waitForTimeout(300);
await page.click('.seg button:has-text("dark")');
await page.waitForTimeout(300);
await page.click('.tabbar button:nth-child(1)');
await shot('11-home-violet-dark', true);
// back to lime/dark
await page.click('.tabbar button:nth-child(4)');
await page.click('.swatch-grid button:nth-child(1)');
await page.waitForTimeout(300);

// ---------- 4. Day overview ----------
const firstDayId = await page.evaluate(() => {
  const s = JSON.parse(localStorage.getItem('get-gym-done:v1')).state;
  return Object.values(s.workoutDays).find((d) => d.splitId === s.prefs.activeSplitId && d.dayNumber === 1).id;
});
await page.goto(BASE + `#/day/${firstDayId}`, { waitUntil: 'networkidle' });
await page.reload({ waitUntil: 'networkidle' });
await page.waitForTimeout(700);
await shot('12-day-overview', true);
await page.click('.seg button:has-text("Warmup")');
await shot('13-day-warmup', true);
await page.click('button[aria-label="Edit exercises"]');
await page.waitForTimeout(500);
await shot('14-edit-exercises-sheet', false);
await page.keyboard.press('Escape');
await page.waitForTimeout(300);
await page.click('button[aria-label="Switch day"]');
await page.waitForTimeout(400);
await shot('15-switch-day-sheet', false);
await page.keyboard.press('Escape');

// rest-day overview
const restDayId = await page.evaluate(() => {
  const s = JSON.parse(localStorage.getItem('get-gym-done:v1')).state;
  const d = Object.values(s.workoutDays).find((d) => d.splitId === s.prefs.activeSplitId && d.isRestDay);
  return d ? d.id : null;
});
if (restDayId) {
  await page.goto(BASE + `#/day/${restDayId}`, { waitUntil: 'networkidle' });
  await page.reload({ waitUntil: 'networkidle' });
  await shot('16-day-rest', true);
}

// ---------- 5. Active workout ----------
await page.goto(BASE + `#/workout/${firstDayId}`, { waitUntil: 'networkidle' });
await page.reload({ waitUntil: 'networkidle' });
await page.waitForTimeout(900);
await shot('17-active-workout', true);

await page.click('.stepper .value >> nth=0');
await page.waitForTimeout(500);
await shot('18-keypad-weight', false);
await page.keyboard.press('Escape');
await page.waitForTimeout(300);

await page.click('button[aria-label="Menu"]');
await page.waitForTimeout(400);
await shot('19-workout-menu', false);
await page.click('text=Add exercise');
await page.waitForTimeout(600);
await shot('20-exercise-picker', false);
await page.keyboard.press('Escape');
await page.waitForTimeout(400);

// complete a set → rest overlay
await page.click('button:has-text("Complete set")');
await page.waitForTimeout(700);
await shot('21-rest-overlay', false);
await page.click('.ghost-cta:has-text("Skip")');
await page.waitForTimeout(400);
await shot('22-workout-set-logged', true);

// ---------- 6. Complete screen ----------
const sid = await page.evaluate(() => {
  const s = JSON.parse(localStorage.getItem('get-gym-done:v1')).state;
  return s.activeSession ? s.activeSession.sessionId : null;
});
await page.evaluate(() => {
  const KEY = 'get-gym-done:v1';
  const raw = JSON.parse(localStorage.getItem(KEY));
  const s = raw.state;
  const id = s.activeSession.sessionId;
  s.sessions[id].completedAt = Date.now();
  s.activeSession = null;
  localStorage.setItem(KEY, JSON.stringify(raw));
});
await page.goto(BASE + `#/complete/${sid}`, { waitUntil: 'networkidle' });
await page.reload({ waitUntil: 'networkidle' });
await page.waitForTimeout(700);
await shot('23-workout-complete', true);

// ---------- 7. Home dialogs ----------
await page.goto(BASE + '#/home', { waitUntil: 'networkidle' });
await page.reload({ waitUntil: 'networkidle' });
await page.waitForTimeout(1200);
await shot('24-home-after-workout', true);
await page.click('.ghost-cta:has-text("Log activity")');
await page.waitForTimeout(500);
await shot('25-log-activity', false);
await page.keyboard.press('Escape');
await page.waitForTimeout(300);
await page.click('button[aria-label="Reset routine"]');
await page.waitForTimeout(400);
await shot('26-reset-dialog', false);
await page.keyboard.press('Escape');
await page.waitForTimeout(300);
await page.click('.text-link:has-text("Edit")');
await page.waitForTimeout(400);
await shot('27-home-edit-week', true);

// ---------- 8. Profile sheets ----------
await page.click('.text-link:has-text("Done")');
await page.click('.tabbar button:nth-child(3)');
await page.waitForTimeout(700);
await page.click('.chip:has-text("Edit")');
await page.waitForTimeout(500);
await shot('28-edit-profile', false);
await page.keyboard.press('Escape');
await page.waitForTimeout(300);
await page.click('.card .chip:has-text("Log")');
await page.waitForTimeout(500);
await shot('29-log-body', false);
await page.keyboard.press('Escape');

// ---------- 9. Customize routine ----------
await page.goto(BASE + '#/customize', { waitUntil: 'networkidle' });
await page.waitForTimeout(700);
await shot('30-customize-blank', true);
await page.goto(BASE + '#/customize/ppl_6day', { waitUntil: 'networkidle' });
await page.waitForTimeout(700);
await shot('31-customize-seeded', true);

await browser.close();
console.log('DONE');
