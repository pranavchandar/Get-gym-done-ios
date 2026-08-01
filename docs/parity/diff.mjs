#!/usr/bin/env node
// Screenshot parity checker.
//
// Compares simulator captures against the web reference corpus. Because ~34 defect
// fixes deliberately change pixels (see docs/DEFECT-LEDGER.md), a flat threshold
// would reject correct work. Instead every intentional change is declared in
// deviations.yml, and only *undeclared* difference is gated.
//
//   node diff.mjs --reference DIR --actual DIR [--deviations FILE] [--out REPORT.md]
//                 [--threshold 2.0] [--tolerance 24]
//
// Exits non-zero if any screen exceeds the undeclared-difference threshold.

import fs from 'node:fs';
import path from 'node:path';
import { decodePNG, encodePNG, resize } from './png.mjs';

const args = new Map();
for (let i = 2; i < process.argv.length; i += 2) {
  args.set(process.argv[i].replace(/^--/, ''), process.argv[i + 1]);
}
const REF = args.get('reference') ?? 'docs/parity/web-reference';
const ACT = args.get('actual') ?? 'docs/parity/ios-actual';
const DEV = args.get('deviations') ?? 'docs/parity/deviations.yml';
const OUT = args.get('out') ?? 'docs/parity/REPORT.md';
const THRESHOLD = Number(args.get('threshold') ?? 2.0);
const TOLERANCE = Number(args.get('tolerance') ?? 24);
const DIFF_DIR = path.join(path.dirname(ACT), 'diff');

// Reference captures are 390x844 @2x; simulator captures are @3x. Normalise both
// to @1x logical points so the comparison is about layout and colour rather than
// resampling artefacts.
const TARGET_W = 390, TARGET_H = 844;

/** Deliberately tiny YAML reader — deviations.yml is a fixed, flat shape. */
function readDeviations(file) {
  if (!fs.existsSync(file)) return [];
  const out = [];
  let cur = null;
  for (const rawLine of fs.readFileSync(file, 'utf8').split('\n')) {
    const line = rawLine.replace(/#.*$/, '').trimEnd();
    if (!line.trim()) continue;
    const item = line.match(/^\s*-\s*(\w+)\s*:\s*(.*)$/);
    const pair = line.match(/^\s+(\w+)\s*:\s*(.*)$/);
    if (item) {
      if (cur) out.push(cur);
      cur = {};
      assign(cur, item[1], item[2]);
    } else if (pair && cur) {
      assign(cur, pair[1], pair[2]);
    }
  }
  if (cur) out.push(cur);
  return out;
}
function assign(obj, key, val) {
  const v = val.trim().replace(/^["']|["']$/g, '');
  if (key === 'region') {
    obj.region = v.replace(/[[\]]/g, '').split(',').map((n) => Number(n.trim()));
  } else {
    obj[key] = /^\d+$/.test(v) ? Number(v) : v;
  }
}

const deviations = readDeviations(DEV);
const byScreen = new Map();
for (const d of deviations) {
  if (!d.screen) continue;
  if (!byScreen.has(d.screen)) byScreen.set(d.screen, []);
  byScreen.get(d.screen).push(d);
}

function inAnyRegion(regions, x, y) {
  for (const r of regions) {
    const [rx, ry, rw, rh] = r;
    if (x >= rx && x < rx + rw && y >= ry && y < ry + rh) return true;
  }
  return false;
}

const refFiles = fs.existsSync(REF)
  ? fs.readdirSync(REF).filter((f) => f.endsWith('.png')).sort()
  : [];
const actFiles = new Set(
  fs.existsSync(ACT) ? fs.readdirSync(ACT).filter((f) => f.endsWith('.png')) : [],
);

fs.mkdirSync(DIFF_DIR, { recursive: true });

const rows = [];
let failures = 0;
let compared = 0;

for (const file of refFiles) {
  const screen = file.replace(/\.png$/, '');
  if (!actFiles.has(file)) {
    rows.push({ screen, status: 'missing', undeclared: null, declared: null });
    continue;
  }
  let a, b;
  try {
    a = resize(decodePNG(fs.readFileSync(path.join(REF, file))), TARGET_W, TARGET_H);
    b = resize(decodePNG(fs.readFileSync(path.join(ACT, file))), TARGET_W, TARGET_H);
  } catch (e) {
    rows.push({ screen, status: `decode error: ${e.message}`, undeclared: null, declared: null });
    failures++;
    continue;
  }

  const regions = (byScreen.get(screen) ?? []).map((d) => d.region).filter(Boolean);
  const diffImg = Buffer.alloc(TARGET_W * TARGET_H * 4);
  let undeclared = 0, declared = 0;

  for (let y = 0; y < TARGET_H; y++) {
    for (let x = 0; x < TARGET_W; x++) {
      const o = (y * TARGET_W + x) * 4;
      const d =
        Math.abs(a.data[o] - b.data[o]) +
        Math.abs(a.data[o + 1] - b.data[o + 1]) +
        Math.abs(a.data[o + 2] - b.data[o + 2]);
      const differs = d > TOLERANCE;
      if (differs && inAnyRegion(regions, x, y)) {
        declared++;
        diffImg[o] = 40; diffImg[o + 1] = 120; diffImg[o + 2] = 255; diffImg[o + 3] = 255;
      } else if (differs) {
        undeclared++;
        diffImg[o] = 255; diffImg[o + 1] = 40; diffImg[o + 2] = 40; diffImg[o + 3] = 255;
      } else {
        // dim the matching content so differences pop
        const g = (a.data[o] + a.data[o + 1] + a.data[o + 2]) / 3;
        const v = 32 + g * 0.28;
        diffImg[o] = v; diffImg[o + 1] = v; diffImg[o + 2] = v; diffImg[o + 3] = 255;
      }
    }
  }

  const total = TARGET_W * TARGET_H;
  const undeclaredPct = (undeclared / total) * 100;
  const declaredPct = (declared / total) * 100;
  fs.writeFileSync(
    path.join(DIFF_DIR, file),
    encodePNG({ width: TARGET_W, height: TARGET_H, data: diffImg }),
  );

  const pass = undeclaredPct <= THRESHOLD;
  if (!pass) failures++;
  compared++;
  rows.push({
    screen,
    status: pass ? 'pass' : 'FAIL',
    undeclared: undeclaredPct,
    declared: declaredPct,
    regions: regions.length,
  });
}

const fmt = (n) => (n == null ? '—' : `${n.toFixed(2)}%`);
const lines = [
  '# Parity report',
  '',
  `Reference \`${REF}\` · actual \`${ACT}\``,
  '',
  `Normalised to ${TARGET_W}×${TARGET_H} @1x · per-pixel tolerance ${TOLERANCE}/765 ·`,
  `undeclared-difference gate ≤ ${THRESHOLD.toFixed(1)}%`,
  '',
  `**${compared} compared · ${failures} failing · ${refFiles.length - compared} not yet captured**`,
  '',
  '| Screen | Status | Undeclared | Declared | Regions |',
  '|---|---|---|---|---|',
  ...rows.map(
    (r) =>
      `| \`${r.screen}\` | ${r.status === 'pass' ? '✅ pass' : r.status === 'missing' ? '⚪ missing' : '❌ ' + r.status} | ${fmt(r.undeclared)} | ${fmt(r.declared)} | ${r.regions ?? '—'} |`,
  ),
  '',
  'Red pixels in `docs/parity/diff/` are undeclared differences; blue pixels fall inside a',
  'region declared in `deviations.yml` and are expected.',
  '',
];
fs.writeFileSync(OUT, lines.join('\n'));
console.log(lines.join('\n'));

if (failures > 0) {
  console.error(`\n${failures} screen(s) exceeded the undeclared-difference gate.`);
  process.exit(1);
}
