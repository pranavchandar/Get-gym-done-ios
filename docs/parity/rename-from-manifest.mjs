#!/usr/bin/env node
// xcresulttool exports attachments under opaque filenames and records the real names
// in a manifest. This maps them back to the reference-corpus filenames the diff tool
// expects. The manifest shape has changed between Xcode versions, so this handles
// several and fails soft — a missed rename costs a "missing" row in the report, not
// a broken build.
//
//   node rename-from-manifest.mjs <exported-dir> <output-dir>

import fs from 'node:fs';
import path from 'node:path';

const [src, dest] = process.argv.slice(2);
if (!src || !dest) {
  console.error('usage: rename-from-manifest.mjs <exported-dir> <output-dir>');
  process.exit(2);
}
fs.mkdirSync(dest, { recursive: true });

// xcresulttool decorates each attachment as `<name>_<index>_<UUID>.png`, and emits
// unnamed system captures as a bare `<UUID>.png`. Normalise both before anything else:
// the diff tool matches captures to references purely by filename.
function normalise(dir) {
  if (!fs.existsSync(dir)) return;
  const BARE_UUID = /^[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}\.png$/i;
  const DECORATED = /^(.+?)_\d+_[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}\.png$/i;
  for (const file of fs.readdirSync(dir)) {
    if (BARE_UUID.test(file)) {
      // An unnamed capture — nothing to compare it against, and leaving it would
      // pollute the corpus with a file no reference shot corresponds to.
      fs.unlinkSync(path.join(dir, file));
      console.log(`dropped unnamed capture ${file}`);
      continue;
    }
    const m = file.match(DECORATED);
    if (m) {
      fs.renameSync(path.join(dir, file), path.join(dir, `${m[1]}.png`));
      console.log(`normalised ${file} -> ${m[1]}.png`);
    }
  }
}

const manifestPath = path.join(src, 'manifest.json');
if (!fs.existsSync(manifestPath)) {
  console.log('no manifest.json — normalising already-copied filenames');
  normalise(dest);
  process.exit(0);
}

let manifest;
try {
  manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));
} catch (e) {
  console.log(`manifest.json unreadable (${e.message}) — skipping rename`);
  process.exit(0);
}

/** Walk any nesting and yield every {exported, human} pair we can recognise. */
function* pairs(node) {
  if (Array.isArray(node)) {
    for (const n of node) yield* pairs(n);
    return;
  }
  if (!node || typeof node !== 'object') return;

  const exported =
    node.exportedFileName ?? node.exported_file_name ?? node.fileName ?? node.filename;
  const human =
    node.suggestedHumanReadableName ??
    node.suggested_human_readable_name ??
    node.name ??
    node.displayName;
  if (exported && human) yield { exported, human };

  for (const key of Object.keys(node)) {
    if (typeof node[key] === 'object') yield* pairs(node[key]);
  }
}

let renamed = 0;
for (const { exported, human } of pairs(manifest)) {
  if (!/\.png$/i.test(human)) continue;
  const from = path.join(src, exported);
  if (!fs.existsSync(from)) continue;
  const safe = path.basename(human).replace(/[^A-Za-z0-9._-]/g, '_');
  fs.copyFileSync(from, path.join(dest, safe));
  renamed++;
}
normalise(dest);
console.log(`renamed ${renamed} attachment(s) into ${dest}`);
