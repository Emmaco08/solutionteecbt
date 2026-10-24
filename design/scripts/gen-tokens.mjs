// Generates design/tokens.json (tonal scales + semantic roles) and prints a WCAG contrast report.
// Usage: node design/scripts/gen-tokens.mjs design/tokens.json
import fs from 'node:fs';
const out = process.argv[2];

const hex2rgb = h => [1,3,5].map(i => parseInt(h.slice(i,i+2),16));
const rgb2hex = c => '#' + c.map(v => Math.round(Math.max(0,Math.min(255,v))).toString(16).padStart(2,'0')).join('').toUpperCase();
const mix = (a,b,t) => rgb2hex(hex2rgb(a).map((v,i)=> v + (hex2rgb(b)[i]-v)*t));
const lum = h => { const c = hex2rgb(h).map(v=>{v/=255;return v<=0.03928?v/12.92:((v+0.055)/1.055)**2.4}); return 0.2126*c[0]+0.7152*c[1]+0.0722*c[2]; };
const cr = (a,b) => { const [x,y]=[lum(a),lum(b)].sort((p,q)=>q-p); return +( (x+0.05)/(y+0.05) ).toFixed(2); };

const STEPS = [50,100,200,300,400,500,600,700,800,900,950];
// Build a scale that passes exactly through `base` at `baseStep`.
function scale(base, baseStep, light='#FFFFFF', dark='#030812') {
  const idx = STEPS.indexOf(baseStep), s = {};
  STEPS.forEach((st,i) => {
    if (i === idx) s[st] = base.toUpperCase();
    else if (i < idx) { const t = (idx - i) / (idx + 1); s[st] = mix(base, light, Math.pow(t, 0.75)); }
    else { const t = (i - idx) / (STEPS.length - idx); s[st] = mix(base, dark, t * 0.9); }
  });
  return s;
}

const navy = scale('#0B1F44', 900, '#FFFFFF', '#020611');
// lighter navy steps should lean toward blue so they don't go grey
Object.assign(navy, { 50:'#EEF2F9', 100:'#D9E1EF', 200:'#B4C3DD', 300:'#8A9FC6', 400:'#5F7AAA', 500:'#3E5A8C', 600:'#2A4573', 700:'#1B335E', 800:'#13284F', 950:'#06132B' });
const blue = scale('#2563B3', 600, '#FFFFFF', '#04142E');
const gold = scale('#F2B233', 400, '#FFFFFF', '#2A1A00');
Object.assign(gold, { 500:'#D99A1E', 600:'#B57D12', 700:'#8C600F', 800:'#66450C', 900:'#463008', 950:'#2A1C04' });
const neutral = { 0:'#FFFFFF', 25:'#FAFBFD', 50:'#F4F6FA', 100:'#EAEEF4', 200:'#DCE2EB', 300:'#C3CBD8', 400:'#98A3B5', 500:'#6B778C', 600:'#4F5B70', 700:'#384458', 800:'#232E40', 900:'#141D2C', 950:'#0A111D' };
const green = { 50:'#ECFAF2', 100:'#D2F3E0', 300:'#7FD8A6', 500:'#1FA463', 600:'#14874F', 700:'#0F6B3F', 900:'#073821' };
const amber = { 50:'#FFF5E8', 100:'#FFE7C7', 300:'#FDB868', 500:'#E07B0E', 600:'#B8620A', 700:'#8F4B08', 900:'#4A2603' };
const red   = { 50:'#FDEEEE', 100:'#FAD7D7', 300:'#F09A9A', 500:'#D93A3A', 600:'#B82828', 700:'#921F1F', 900:'#4D1010' };

const light = {
  bg: neutral[50], surface: neutral[0], surfaceAlt: neutral[25], surfaceSunken: neutral[100],
  border: neutral[200], borderStrong: neutral[300],
  text: navy[950], textMuted: neutral[600], textSubtle: neutral[500], textInverse: neutral[0],
  primary: navy[900], onPrimary: neutral[0], primarySoft: navy[50], onPrimarySoft: navy[900],
  secondary: blue[600], onSecondary: neutral[0], secondarySoft: blue[50], onSecondarySoft: blue[800],
  accent: gold[400], onAccent: navy[900], accentSoft: gold[50], onAccentSoft: gold[800],
  link: blue[700], focus: blue[500],
  success: green[600], successSoft: green[50], onSuccessSoft: green[700],
  warning: amber[700], warningSoft: amber[50], onWarningSoft: amber[700],
  error: red[600], errorSoft: red[50], onErrorSoft: red[700],
  scrim: 'rgba(6,19,43,0.48)', shadowTint: '11,31,68',
  answered: green[600], unanswered: neutral[200], flagged: amber[500], current: blue[600],
  frame: '#0A111D', canvas: '#E3E8F0'
};
const dark = {
  bg: '#060E1D', surface: '#0D1A30', surfaceAlt: '#11203A', surfaceSunken: '#091427',
  border: '#1C2D4A', borderStrong: '#2A3F62',
  text: '#EAF0FA', textMuted: '#A7B4CA', textSubtle: '#8090AA', textInverse: navy[950],
  primary: '#DDE6F5', onPrimary: navy[950], primarySoft: '#16284A', onPrimarySoft: '#DDE6F5',
  secondary: blue[400], onSecondary: navy[950], secondarySoft: '#10284D', onSecondarySoft: blue[200],
  accent: gold[400], onAccent: navy[900], accentSoft: '#2B2210', onAccentSoft: gold[200],
  link: blue[300], focus: blue[300],
  success: green[300], successSoft: '#0C2A1D', onSuccessSoft: green[300],
  warning: amber[300], warningSoft: '#2E1D08', onWarningSoft: amber[300],
  error: red[300], errorSoft: '#33121A', onErrorSoft: red[300],
  scrim: 'rgba(2,6,14,0.66)', shadowTint: '0,0,0',
  answered: green[500], unanswered: '#22365A', flagged: amber[500], current: blue[400],
  frame: '#000510', canvas: '#03070F'
};

const tokens = {
  $meta: { name: 'SolutionTee CBT design tokens', version: '1.0.0', generated: '2026-10-24',
    note: 'Single source of truth for prototype, Flutter (apps/mobile) and Next.js (apps/web). color.palette = raw tonal scales; color.light / color.dark = semantic roles. Gold is never used for text on light surfaces.' },
  color: {
    brand: { navy: '#0B1F44', blue: '#2563B3', gold: '#F2B233' },
    palette: { navy, blue, gold, neutral, green, amber, red },
    light, dark
  },
  font: {
    family: { sans: "'Plus Jakarta Sans', system-ui, -apple-system, 'Segoe UI', Roboto, sans-serif", math: 'KaTeX_Main, serif', mono: "ui-monospace, 'SF Mono', Menlo, Consolas, monospace" },
    weight: { regular: 500, bold: 700 },
    files: ['vendor/fonts/plus-jakarta-sans-latin-500-normal.woff2','vendor/fonts/plus-jakarta-sans-latin-700-normal.woff2','vendor/fonts/plus-jakarta-sans-latin-ext-500-normal.woff2','vendor/fonts/plus-jakarta-sans-latin-ext-700-normal.woff2']
  },
  type: {
    display:  { size: 32, line: 38, weight: 700, tracking: -0.6 },
    h1:       { size: 26, line: 32, weight: 700, tracking: -0.4 },
    h2:       { size: 21, line: 28, weight: 700, tracking: -0.2 },
    h3:       { size: 17, line: 24, weight: 700, tracking: -0.1 },
    bodyLg:   { size: 17, line: 26, weight: 500, tracking: 0 },
    body:     { size: 15, line: 22, weight: 500, tracking: 0 },
    bodySm:   { size: 13, line: 18, weight: 500, tracking: 0 },
    label:    { size: 14, line: 20, weight: 700, tracking: 0.1 },
    caption:  { size: 12, line: 16, weight: 500, tracking: 0.2 },
    overline: { size: 11, line: 14, weight: 700, tracking: 0.8 },
    question: { size: 17, line: 27, weight: 500, tracking: 0 },
    timer:    { size: 18, line: 22, weight: 700, tracking: 0.4 }
  },
  space: { 0:0, 1:4, 2:8, 3:12, 4:16, 5:20, 6:24, 7:32, 8:40, 9:48, 10:56, 11:64, 12:80 },
  radius: { xs: 6, sm: 10, md: 12, lg: 16, xl: 24, sheet: 28, pill: 999 },
  size: { tapMin: 48, buttonHeight: 52, inputHeight: 52, appBar: 56, bottomNav: 68, iconSm: 18, icon: 22, iconLg: 28, phoneWidth: 390, phoneHeight: 844 },
  elevation: {
    light: {
      0: 'none',
      1: '0 1px 2px rgba(11,31,68,0.06), 0 1px 1px rgba(11,31,68,0.04)',
      2: '0 4px 12px -2px rgba(11,31,68,0.10), 0 2px 4px rgba(11,31,68,0.04)',
      3: '0 12px 28px -6px rgba(11,31,68,0.18), 0 4px 8px rgba(11,31,68,0.06)',
      4: '0 24px 48px -12px rgba(11,31,68,0.28)'
    },
    dark: {
      0: 'none',
      1: '0 1px 2px rgba(0,0,0,0.4)',
      2: '0 4px 12px -2px rgba(0,0,0,0.5)',
      3: '0 12px 28px -6px rgba(0,0,0,0.6)',
      4: '0 24px 48px -12px rgba(0,0,0,0.7)'
    }
  },
  motion: {
    duration: { instant: 100, fast: 200, base: 280, slow: 400, celebrate: 1200 },
    easing: {
      standard: 'cubic-bezier(0.2, 0, 0, 1)',
      out: 'cubic-bezier(0.16, 1, 0.3, 1)',
      in: 'cubic-bezier(0.4, 0, 1, 1)',
      emphasized: 'cubic-bezier(0.3, 0, 0, 1.15)'
    },
    stagger: 50,
    pressScale: 0.97,
    reduceMotion: 'When the OS reduce-motion setting is on: no transforms, no parallax, no confetti; fades only at duration.fast; timers/progress update without animation.'
  },
  zIndex: { base: 0, sticky: 10, nav: 20, sheet: 40, dialog: 50, toast: 60, tour: 70 },
  breakpoint: { sm: 640, md: 768, lg: 1024, xl: 1280 }
};

fs.writeFileSync(out, JSON.stringify(tokens, null, 2) + '\n');

// Contrast report
const checks = m => [
  ['text/bg', m.text, m.bg], ['text/surface', m.text, m.surface], ['textMuted/surface', m.textMuted, m.surface],
  ['textSubtle/surface', m.textSubtle, m.surface],
  ['onPrimary/primary', m.onPrimary, m.primary], ['onSecondary/secondary', m.onSecondary, m.secondary],
  ['onAccent/accent', m.onAccent, m.accent], ['link/surface', m.link, m.surface],
  ['onAccentSoft/accentSoft', m.onAccentSoft, m.accentSoft], ['onSecondarySoft/secondarySoft', m.onSecondarySoft, m.secondarySoft],
  ['success/surface', m.success, m.surface], ['warning/surface', m.warning, m.surface], ['error/surface', m.error, m.surface],
  ['onErrorSoft/errorSoft', m.onErrorSoft, m.errorSoft], ['onSuccessSoft/successSoft', m.onSuccessSoft, m.successSoft]
];
for (const [n,m] of [['LIGHT',light],['DARK',dark]]) {
  console.log(n); for (const [k,a,b] of checks(m)) { const r=cr(a,b); console.log(`  ${r>=4.5?'AA ':r>=3?'AA-L':'FAIL'} ${r.toString().padStart(5)}  ${k}`); }
}
console.log('gold on white', cr(gold[400], '#FFFFFF'));
