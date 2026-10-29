// Turns design/tokens.json into Dart constants for the Flutter app (single source of truth).
// Usage: node design/scripts/tokens-to-dart.mjs design/tokens.json apps/mobile/lib/theme/tokens.g.dart
import fs from 'node:fs';

const [src, out] = process.argv.slice(2);
const t = JSON.parse(fs.readFileSync(src, 'utf8'));
const dbl = (n) => (Number.isInteger(n) ? n.toFixed(1) : String(n));
const camel = (s) => s.replace(/[-_](\w)/g, (_, c) => c.toUpperCase());
const color = (hex) => {
  if (hex.startsWith('rgba')) {
    const [r, g, b, a] = hex.match(/[\d.]+/g).map(Number);
    return `Color.fromRGBO(${r}, ${g}, ${b}, ${a})`;
  }
  return `Color(0xFF${hex.replace('#', '').toUpperCase()})`;
};
const roles = (obj) =>
  Object.entries(obj)
    .filter(([, v]) => typeof v === 'string' && (v.startsWith('#') || v.startsWith('rgba')))
    .map(([k, v]) => `  final Color ${camel(k)};`).join('\n');
const roleValues = (obj) =>
  Object.entries(obj)
    .filter(([, v]) => typeof v === 'string' && (v.startsWith('#') || v.startsWith('rgba')))
    .map(([k, v]) => `    ${camel(k)}: ${color(v)},`).join('\n');

let palette = '';
for (const [name, scale] of Object.entries(t.color.palette))
  for (const [step, hex] of Object.entries(scale)) palette += `  static const ${name}${step} = ${color(hex)};\n`;

const dart = `// GENERATED from design/tokens.json by design/scripts/tokens-to-dart.mjs. Do not edit by hand.
// ignore_for_file: constant_identifier_names
import 'package:flutter/material.dart';

/// Raw tonal palettes (navy, blue, gold, neutral, green, amber, red).
abstract final class Palette {
${palette}}

/// Semantic colour roles for one theme (light or dark).
class AppColors {
  const AppColors({
${Object.keys(t.color.light).filter((k) => /^#|^rgba/.test(t.color.light[k])).map((k) => `    required this.${camel(k)},`).join('\n')}
  });
${roles(t.color.light)}

  static const light = AppColors(
${roleValues(t.color.light)}
  );
  static const dark = AppColors(
${roleValues(t.color.dark)}
  );
}

/// 8-pt spacing scale.
abstract final class Space {
${Object.entries(t.space).map(([k, v]) => `  static const double s${k} = ${v};`).join('\n')}
}

/// Corner radii (cards use lg = 16).
abstract final class Radii {
${Object.entries(t.radius).map(([k, v]) => `  static const double ${camel(k)} = ${v};`).join('\n')}
}

/// Component sizes (tap targets are at least 48).
abstract final class Sizes {
${Object.entries(t.size).map(([k, v]) => `  static const double ${camel(k)} = ${v};`).join('\n')}
}

/// Type scale: size, line height, weight, letter spacing.
abstract final class TypeScale {
${Object.entries(t.type).map(([k, v]) => `  static const ${camel(k)} = (size: ${dbl(v.size)}, line: ${dbl(v.line)}, weight: ${v.weight}, tracking: ${dbl(v.tracking)});`).join('\n')}
}

/// Motion: durations (ms) and easing curves. Respect reduce-motion (MediaQuery.disableAnimations).
abstract final class Motion {
${Object.entries(t.motion.duration).map(([k, v]) => `  static const ${camel(k)} = Duration(milliseconds: ${v});`).join('\n')}
${Object.entries(t.motion.easing).map(([k, v]) => { const n = v.match(/[\d.]+/g).map(Number); return `  static const ${k === "in" ? "easeIn" : camel(k)} = Cubic(${n.join(', ')});`; }).join('\n')}
  static const stagger = Duration(milliseconds: ${t.motion.stagger});
  static const pressScale = ${t.motion.pressScale};
}
`;
fs.writeFileSync(out, dart);
console.log(`wrote ${out}`);
