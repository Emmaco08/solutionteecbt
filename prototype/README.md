# SolutionTee CBT · Phase 1 prototype

Plain HTML/CSS/vanilla JS. No build step and no `node_modules`. All libraries are vendored in `vendor/`, so it works on the LAN without internet.

## Run
```bash
node prototype/serve.mjs
```
- Laptop: http://localhost:5173/
- Phone (same Wi-Fi): `http://<laptop-LAN-IP>:5173/` (the server prints it)
- Stop: `Ctrl+C`

Open it through the server, not by double-clicking the HTML, because the pages fetch `/design/tokens.json` and `/brand/*`.

## Structure
| Path | What |
|---|---|
| `index.html` | Inventory of every screen |
| `app.html` | Phone frame (390×844) with hash routes `#/<screen>`. On a phone it goes full-screen |
| `admin.html` | Admin CMS screens (desktop) |
| `js/tokens.js` | Reads `/design/tokens.json` and writes CSS custom properties for light and dark |
| `js/core.js` | Router, page transitions, sheets, dialogs, toasts, exam-logo slot, KaTeX helper |
| `js/screens-*.js` | Screen definitions (`ST.def(id, {title, group, tab, render, mount})`) |
| `css/base.css` | Shared components (buttons, inputs, chips, cards, progress, skeleton, states, motion) |
| `css/app.css` | Phone shell and screen layouts |
| `css/admin.css` | Admin layout |
| `vendor/` | KaTeX 0.16.22, Phosphor Icons 2.1.1, lottie-web 5.12.2 (light), Plus Jakarta Sans 500/700 |

## Rules this prototype follows
- Colours, type, spacing, radius, shadows and motion all come from `design/tokens.json`. Regenerate it with `node design/scripts/gen-tokens.mjs design/tokens.json`.
- Logos come only from `/brand`. Exam-body logos load from `/brand/exam-bodies/{jamb,waec,neco}.png`. A missing file shows a grey slot labelled with its name; nothing is redrawn.
- Reduce motion follows the OS setting, or the toggle in the side panel / Settings.
