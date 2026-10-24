/* Reads /design/tokens.json and turns it into CSS custom properties.
   The same JSON will feed Flutter (ThemeData) and Next.js (Tailwind theme) later. */
(function () {
  const kebab = s => s.replace(/[A-Z]/g, m => '-' + m.toLowerCase());

  function roleVars(roles) {
    return Object.entries(roles).map(([k, v]) => `--c-${kebab(k)}:${v};`).join('');
  }
  function shadowVars(sh) {
    return Object.entries(sh).map(([k, v]) => `--shadow-${k}:${v};`).join('');
  }

  function build(t) {
    let base = '';
    for (const [name, scale] of Object.entries(t.color.palette))
      for (const [step, hex] of Object.entries(scale)) base += `--${name}-${step}:${hex};`;
    for (const [k, v] of Object.entries(t.space)) base += `--s-${k}:${v}px;`;
    for (const [k, v] of Object.entries(t.radius)) base += `--r-${k}:${v}px;`;
    for (const [k, v] of Object.entries(t.size)) base += `--size-${kebab(k)}:${v}px;`;
    for (const [k, v] of Object.entries(t.type))
      base += `--t-${kebab(k)}-size:${v.size}px;--t-${kebab(k)}-line:${v.line}px;--t-${kebab(k)}-weight:${v.weight};--t-${kebab(k)}-tracking:${v.tracking}px;`;
    for (const [k, v] of Object.entries(t.motion.duration)) base += `--dur-${k}:${v}ms;`;
    for (const [k, v] of Object.entries(t.motion.easing)) base += `--ease-${k}:${v};`;
    for (const [k, v] of Object.entries(t.zIndex)) base += `--z-${kebab(k)}:${v};`;
    base += `--stagger:${t.motion.stagger}ms;--press-scale:${t.motion.pressScale};`;
    base += `--font-sans:${t.font.family.sans};--font-mono:${t.font.family.mono};`;
    base += `--w-regular:${t.font.weight.regular};--w-bold:${t.font.weight.bold};`;

    const light = roleVars(t.color.light) + shadowVars(t.elevation.light);
    const dark = roleVars(t.color.dark) + shadowVars(t.elevation.dark);
    return `:root{${base}}
:root,:root[data-theme="light"]{${light}color-scheme:light;}
:root[data-theme="dark"]{${dark}color-scheme:dark;}
@media (prefers-color-scheme: dark){:root:not([data-theme="light"]){${dark}color-scheme:dark;}}`;
  }

  // Theme: 'system' | 'light' | 'dark' (per-viewer convenience only)
  function applyTheme(mode) {
    const m = mode || (safeGet('st-theme') || 'system');
    if (m === 'system') document.documentElement.removeAttribute('data-theme');
    else document.documentElement.setAttribute('data-theme', m);
  }
  function safeGet(k) { try { return localStorage.getItem(k); } catch (e) { return null; } }
  function safeSet(k, v) { try { localStorage.setItem(k, v); } catch (e) {} }

  window.ST = window.ST || {};
  ST.safeGet = safeGet; ST.safeSet = safeSet;
  ST.setTheme = m => { safeSet('st-theme', m); applyTheme(m); };
  ST.getTheme = () => safeGet('st-theme') || 'system';
  ST.isDark = () => {
    const a = document.documentElement.getAttribute('data-theme');
    return a ? a === 'dark' : matchMedia('(prefers-color-scheme: dark)').matches;
  };
  // Reduce motion: OS setting OR prototype toggle
  ST.reduceMotion = () => document.documentElement.classList.contains('rm') || matchMedia('(prefers-reduced-motion: reduce)').matches;
  ST.setReduceMotion = on => { safeSet('st-rm', on ? '1' : '0'); document.documentElement.classList.toggle('rm', on); };

  applyTheme();
  if (safeGet('st-rm') === '1') document.documentElement.classList.add('rm');

  ST.tokensReady = fetch('/design/tokens.json', { cache: 'no-cache' })
    .then(r => { if (!r.ok) throw new Error('tokens.json ' + r.status); return r.json(); })
    .then(t => {
      ST.tokens = t;
      const style = document.createElement('style');
      style.id = 'tokens';
      style.textContent = build(t);
      document.head.prepend(style);
      return t;
    })
    .catch(err => {
      document.body.insertAdjacentHTML('afterbegin',
        `<p style="padding:16px;font:14px system-ui;background:#FDEEEE;color:#921F1F">Could not load /design/tokens.json (${err.message}). Start the prototype with <b>node prototype/serve.mjs</b>, not by opening the file directly.</p>`);
      throw err;
    });
})();
