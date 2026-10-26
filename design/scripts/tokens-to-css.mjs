// Turns design/tokens.json into CSS custom properties for the Next.js website/admin.
// Same variable names as the approved prototype (--c-*, --navy-*, --s-*, ...), so styles carry over.
// Usage: node design/scripts/tokens-to-css.mjs design/tokens.json apps/web/app/tokens.css
import fs from 'node:fs';

const [src, out] = process.argv.slice(2);
const t = JSON.parse(fs.readFileSync(src, 'utf8'));
const kebab = (s) => s.replace(/[A-Z]/g, (m) => '-' + m.toLowerCase());
const lines = (obj, fn) => Object.entries(obj).map(([k, v]) => `  ${fn(k, v)};`).join('\n');

let base = '';
for (const [name, scale] of Object.entries(t.color.palette)) base += lines(scale, (k, v) => `--${name}-${k}: ${v}`) + '\n';
base += lines(t.space, (k, v) => `--s-${k}: ${v}px`) + '\n';
base += lines(t.radius, (k, v) => `--r-${k}: ${v}px`) + '\n';
base += lines(t.motion.duration, (k, v) => `--dur-${k}: ${v}ms`) + '\n';
base += lines(t.motion.easing, (k, v) => `--ease-${k}: ${v}`) + '\n';

const roles = (r) => lines(r, (k, v) => `--c-${kebab(k)}: ${v}`);
const shadows = (e) => lines(e, (k, v) => `--shadow-${k}: ${v}`);

const css = `/* Generated from design/tokens.json by design/scripts/tokens-to-css.mjs. Do not edit by hand. */
:root {
${base}}
:root, .light {
${roles(t.color.light)}
${shadows(t.elevation.light)}
  color-scheme: light;
}
.dark {
${roles(t.color.dark)}
${shadows(t.elevation.dark)}
  color-scheme: dark;
}
`;
fs.writeFileSync(out, css);
console.log(`wrote ${out}`);
