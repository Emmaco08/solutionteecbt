// Copies ONLY the public design files into the separate design repo (default: ../solutiontee-cbt-design).
// Private material (docs/, CLAUDE.md, SPEC, app code) is never copied.
// Usage: node prototype/publish/sync.mjs [targetDir]
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const TARGET = path.resolve(process.argv[2] || path.join(ROOT, '..', 'solutiontee-cbt-design'));
const FILES = path.join(ROOT, 'prototype', 'publish', 'files');

const COPY = [
  ['prototype', 'prototype', p => !p.split(path.sep).includes('publish')],
  ['design/tokens.json', 'design/tokens.json'],
  ['design/scripts', 'design/scripts'],
  ['brand', 'brand']
];

fs.mkdirSync(TARGET, { recursive: true });
// Remove everything except .git so deleted files disappear from the design repo too
for (const name of fs.readdirSync(TARGET)) if (name !== '.git') fs.rmSync(path.join(TARGET, name), { recursive: true, force: true });

// Plain recursive copy (fs.cpSync crashes on some Windows/Node 24 setups)
function copy(src, dst, filter) {
  if (filter && !filter(path.relative(ROOT, src))) return;
  const st = fs.statSync(src);
  if (st.isDirectory()) {
    fs.mkdirSync(dst, { recursive: true });
    for (const name of fs.readdirSync(src)) copy(path.join(src, name), path.join(dst, name), filter);
  } else {
    fs.mkdirSync(path.dirname(dst), { recursive: true });
    fs.copyFileSync(src, dst);
  }
}
for (const [from, to, filter] of COPY) copy(path.join(ROOT, from), path.join(TARGET, to), filter);
copy(FILES, TARGET);

let n = 0;
(function count(d) { for (const e of fs.readdirSync(d, { withFileTypes: true })) { if (e.name === '.git') continue; e.isDirectory() ? count(path.join(d, e.name)) : n++; } })(TARGET);
console.log(`Synced ${n} files to ${TARGET}`);
