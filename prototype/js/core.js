/* Prototype runtime: screen registry, hash router, transitions, overlays, helpers. */
(function () {
  const ST = window.ST;
  ST.screens = {};
  ST.order = [];
  ST.state = {
    first: 'Tolu', name: 'Tolu Adeyemi', initials: 'TA', plan: 'free', aiLeft: 2, aiMax: 3, streak: 6,
    payFlavor: 'play', reg: '20261 0457 GH'
  };

  /** Register a screen. cfg: { title, group, tab?, navy?, render(params) -> html, mount?(el, params) } */
  ST.def = (id, cfg) => { ST.screens[id] = Object.assign({ id }, cfg); ST.order.push(id); };

  const BODIES = { JAMB: 'jamb.png', WAEC: 'waec.png', NECO: 'neco.png' };
  // Visible-content box of each owner-supplied PNG [x, y, w, h, imageW, imageH], measured from the alpha channel.
  // The files keep transparent margins; we crop on screen with CSS so the logo fills its slot. Files are never edited.
  const CROP = { JAMB: [69, 16, 115, 112, 246, 144], WAEC: [95, 18, 339, 329, 554, 361], NECO: [90, 41, 314, 314, 494, 404] };
  const cropStyle = body => {
    const [x, y, w, h, W] = CROP[body], m = Math.max(w, h);
    return `width:${(W / m * 100).toFixed(2)}%;left:${((-x + (m - w) / 2) / m * 100).toFixed(2)}%;top:${((-y + (m - h) / 2) / m * 100).toFixed(2)}%`;
  };
  /** Exam-body logo: always the real file from /brand/exam-bodies; a labelled empty slot if the file is missing. */
  ST.examLogo = (body, size = '') =>
    `<span class="exam-logo ${size}" data-file="${BODIES[body]}" data-short="${body}" title="${body}"><span class="crop"><img src="/brand/exam-bodies/${BODIES[body]}" alt="${body} logo" style="${cropStyle(body)}" onerror="this.closest('.exam-logo').classList.add('missing');this.parentNode.remove()"></span></span>`;
  /** SolutionTee mark (real files from /brand). mark-light = for light surfaces, mark-dark = for dark surfaces. */
  ST.mark = (h = 28) =>
    `<img class="mark-l" src="/brand/mark-light.png" alt="SolutionTee" style="height:${h}px;width:auto"><img class="mark-d" src="/brand/mark-dark.png" alt="SolutionTee" style="height:${h}px;width:auto">`;
  ST.icon = (n, fill) => `<i class="${fill ? 'ph-fill' : 'ph'} ph-${n}" aria-hidden="true"></i>`;
  ST.naira = n => '₦' + Number(n).toLocaleString('en-NG');
  ST.esc = s => String(s).replace(/[&<>"]/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));

  // ---------- Student images (AI question photos, profile photo) ----------
  /** Avatar: the student's photo if they added one, otherwise initials. */
  ST.avatar = (cls = '') => ST.state.avatar
    ? `<div class="avatar ${cls}"><img src="${ST.state.avatar}" alt="Your profile photo"></div>`
    : `<div class="avatar ${cls}">${ST.state.initials}</div>`;

  /** Downscale + re-encode on the phone before upload (data-light). Max 1280 px long side, WebP/JPEG ~0.72. */
  ST.compressImage = (file, maxSide = 1280, quality = 0.72) => new Promise((resolve, reject) => {
    if (!file || !/^image\//.test(file.type)) return reject(new Error('not-image'));
    const img = new Image(), url = URL.createObjectURL(file);
    img.onload = () => {
      const k = Math.min(1, maxSide / Math.max(img.naturalWidth, img.naturalHeight));
      const c = document.createElement('canvas');
      c.width = Math.round(img.naturalWidth * k); c.height = Math.round(img.naturalHeight * k);
      c.getContext('2d').drawImage(img, 0, 0, c.width, c.height);
      URL.revokeObjectURL(url);
      const done = blob => resolve({ url: URL.createObjectURL(blob), kb: Math.round(blob.size / 1024), origKb: Math.round(file.size / 1024), w: c.width, h: c.height });
      c.toBlob(b => b && b.type === 'image/webp' ? done(b) : c.toBlob(done, 'image/jpeg', quality), 'image/webp', quality);
    };
    img.onerror = () => { URL.revokeObjectURL(url); reject(new Error('unreadable')); };
    img.src = url;
  });

  /** Open the phone camera or gallery. Resolves with a compressed image, or null if cancelled. */
  ST.pickImage = ({ camera = false } = {}) => new Promise(resolve => {
    const inp = document.createElement('input');
    inp.type = 'file'; inp.accept = 'image/*';
    if (camera) inp.setAttribute('capture', 'environment');
    inp.onchange = () => {
      const f = inp.files && inp.files[0];
      if (!f) return resolve(null);
      if (f.size > 15 * 1024 * 1024) { ST.toast('That photo is too large. Pick one under 15 MB.', 'warning-circle'); return resolve(null); }
      ST.compressImage(f).then(resolve).catch(() => { ST.toast('That file is not a photo. Try a JPG or PNG.', 'warning-circle'); resolve(null); });
    };
    inp.click();
  });

  /** Prototype only: a sample "phone photo" of a handwritten exam question, for testing without a camera. */
  ST.samplePhoto = () => new Promise(resolve => {
    const c = document.createElement('canvas'), W = 960, H = 720; c.width = W; c.height = H;
    const g = c.getContext('2d');
    const grd = g.createLinearGradient(0, 0, W, H); grd.addColorStop(0, '#F7F3E8'); grd.addColorStop(1, '#E9E2D0');
    g.fillStyle = grd; g.fillRect(0, 0, W, H);
    g.strokeStyle = 'rgba(70,110,170,.35)'; g.lineWidth = 2;
    for (let y = 120; y < H; y += 56) { g.beginPath(); g.moveTo(0, y); g.lineTo(W, y); g.stroke(); }
    g.strokeStyle = 'rgba(200,60,60,.45)'; g.beginPath(); g.moveTo(96, 0); g.lineTo(96, H); g.stroke();
    g.fillStyle = '#1F2A44'; g.font = 'italic 38px Georgia, serif';
    ['Q14. A trader bought a phone for N24,000', 'and sold it for N30,000.', 'Find his percentage profit.', '(A) 20%   (B) 25%   (C) 30%   (D) 6%'].forEach((t, i) => g.fillText(t, 120, 162 + i * 112));
    g.fillStyle = 'rgba(0,0,0,.18)'; g.fillRect(0, 0, W, 18);
    c.toBlob(b => resolve({ url: URL.createObjectURL(b), kb: Math.round(b.size / 1024), origKb: 2870, w: W, h: H, sample: true }), 'image/jpeg', 0.72);
  });

  /** Full-screen image viewer. */
  ST.viewImage = (src, alt = 'Image') => ST.dialog(`<img src="${src}" alt="${ST.esc(alt)}" style="width:100%;border-radius:12px"><button class="btn btn-outline btn-block mt4" data-close>Close</button>`, { cls: 'img-dialog' });

  /** Render $...$ and $$...$$ inside el with a safe fallback (mirrors the planned Flutter MathText widget). */
  ST.math = el => {
    if (!window.renderMathInElement) return;
    renderMathInElement(el, {
      delimiters: [{ left: '$$', right: '$$', display: true }, { left: '$', right: '$', display: false }],
      throwOnError: false, errorColor: 'var(--c-error)', ignoredClasses: ['no-math'],
      errorCallback: (msg, err) => console.warn('MathText fallback', msg, err)
    });
  };
  ST.tex = (src, display) => {
    try { return katex.renderToString(src, { displayMode: !!display, throwOnError: true }); }
    catch (e) { return `<code class="math-fallback">${ST.esc(src)}</code>`; }
  };

  // ---------- Router ----------
  const host = () => document.getElementById('host');
  let stack = [];
  let current = null;
  const inFrame = () => !document.querySelector('.phone').classList.contains('real');

  function parseHash() {
    const h = location.hash.replace(/^#\/?/, '');
    const [id, qs] = h.split('?');
    return { id: id || 'splash', params: Object.fromEntries(new URLSearchParams(qs || '')) };
  }
  function toHash(id, params) {
    const qs = new URLSearchParams(params || {}).toString();
    return '#/' + id + (qs ? '?' + qs : '');
  }

  function statusBar() {
    return `<div class="statusbar"><span>10:24</span><span class="ic">${ST.icon('cell-signal-full', 1)}${ST.icon('wifi-high', 1)}${ST.icon('battery-high', 1)}</span></div>`;
  }

  function bottomNav(active) {
    const tabs = [['home', 'Home', 'house'], ['study', 'Study', 'book-open-text'], ['test', 'Test', 'exam'], ['ai', 'AI Tutor', 'sparkle'], ['profile', 'Me', 'user-circle']];
    return `<nav class="bnav" aria-label="Main">${tabs.map(([id, label, ic]) =>
      `<button data-tab="${id}" class="${active === id ? 'on' : ''}" ${active === id ? 'aria-current="page"' : ''}><span class="pill">${ST.icon(ic, active === id)}</span>${label}</button>`).join('')}</nav>`;
  }

  function render(id, params, mode) {
    const cfg = ST.screens[id] || ST.screens.error;
    ST.closeOverlay(true);
    const el = document.createElement('section');
    el.className = 'scr' + (cfg.navy ? ' on-navy' : '') + (cfg.cls ? ' ' + cfg.cls : '');
    el.dataset.screen = id;
    el.innerHTML = (cfg.noStatus ? '' : statusBar()) + cfg.render(params || {}) + (cfg.tab ? bottomNav(cfg.tab) : '');
    if (cfg.noStatus && inFrame()) el.style.paddingTop = '0';
    // stagger: number children of every .enter container
    el.querySelectorAll('.enter').forEach(c => [...c.children].forEach((k, i) => k.style.setProperty('--i', Math.min(i, 10))));
    const old = current;
    host().appendChild(el);
    const tIn = mode === 'back' ? 't-pop-in' : mode === 'fade' || !old ? 't-fade-in' : 't-push-in';
    const tOut = mode === 'back' ? 't-pop-out' : mode === 'fade' ? 't-fade-out' : 't-push-out';
    el.classList.add(tIn);
    if (old) {
      old.classList.add(tOut);
      const kill = () => old.remove();
      if (ST.reduceMotion()) kill(); else setTimeout(kill, 320);
    }
    el.addEventListener('animationend', () => el.classList.remove(tIn), { once: true });
    current = el;
    ST.math(el);
    if (cfg.mount) cfg.mount(el, params || {});
    document.title = (cfg.title || id) + ' · SolutionTee CBT prototype';
    document.querySelectorAll('.jump').forEach(j => j.classList.toggle('on', j.dataset.go === id));
    if (ST.onRoute) ST.onRoute(id);
  }

  ST.go = (id, params, opts = {}) => {
    const mode = opts.mode || (opts.tab ? 'fade' : 'push');
    if (opts.replace) stack[stack.length - 1] = { id, params }; else stack.push({ id, params });
    ST._silent = true;
    history.replaceState(null, '', toHash(id, params));
    render(id, params, mode);
  };
  ST.back = fallback => {
    if (ST.closeOverlay()) return;
    if (stack.length > 1) { stack.pop(); const p = stack[stack.length - 1]; history.replaceState(null, '', toHash(p.id, p.params)); render(p.id, p.params, 'back'); }
    else if (fallback) ST.go(fallback, null, { mode: 'back', replace: true });
  };
  ST.current = () => current;

  window.addEventListener('hashchange', () => { const { id, params } = parseHash(); stack.push({ id, params }); render(id, params, 'fade'); });

  // ---------- Overlays ----------
  const ov = () => document.getElementById('overlay');
  let overlayStack = [];
  ST.sheet = (html, opts = {}) => openOverlay(`<div class="sheet ${opts.cls || ''}" role="dialog" aria-modal="true"><div class="grab"></div><div class="sheet-body">${html}</div></div>`, opts);
  ST.dialog = (html, opts = {}) => openOverlay(`<div class="dialog ${opts.cls || ''}" role="alertdialog" aria-modal="true">${html}</div>`, opts);
  function openOverlay(inner, opts) {
    const wrap = document.createElement('div');
    wrap.style.cssText = 'position:absolute;inset:0;';
    wrap.innerHTML = `<div class="scrim"></div>${inner}`;
    ov().appendChild(wrap);
    if (!opts.sticky) wrap.querySelector('.scrim').addEventListener('click', () => ST.closeOverlay());
    wrap.querySelectorAll('.enter').forEach(c => [...c.children].forEach((k, i) => k.style.setProperty('--i', Math.min(i, 10))));
    ST.math(wrap);
    overlayStack.push(wrap);
    if (opts.mount) opts.mount(wrap);
    return wrap;
  }
  ST.closeOverlay = (instant) => {
    const w = overlayStack.pop();
    if (!w) return false;
    if (instant || ST.reduceMotion()) { w.remove(); return true; }
    w.querySelector('.scrim')?.classList.add('closing');
    w.querySelector('.sheet, .dialog')?.classList.add('closing');
    setTimeout(() => w.remove(), 210);
    return true;
  };
  ST.toast = (msg, icon = 'check-circle') => {
    const t = document.createElement('div');
    t.className = 'toast';
    t.innerHTML = `${ST.icon(icon, 1)}<span>${msg}</span>`;
    ov().appendChild(t);
    setTimeout(() => { t.style.transition = 'opacity .2s'; t.style.opacity = '0'; setTimeout(() => t.remove(), 220); }, 2200);
  };

  // ---------- Global click delegation ----------
  document.addEventListener('click', e => {
    const t = e.target.closest('[data-go],[data-back],[data-tab],[data-sheet],[data-close],[data-toast]');
    if (!t) return;
    if (t.dataset.go) { e.preventDefault(); const p = t.dataset.params ? Object.fromEntries(new URLSearchParams(t.dataset.params)) : null; ST.go(t.dataset.go, p, { mode: t.dataset.mode }); }
    else if (t.hasAttribute('data-back')) ST.back(t.dataset.back || 'home');
    else if (t.dataset.tab) { if (current?.dataset.screen !== t.dataset.tab) { stack = []; ST.go(t.dataset.tab, null, { tab: true }); } }
    else if (t.dataset.sheet) ST.openSheet(t.dataset.sheet, t.dataset);
    else if (t.hasAttribute('data-close')) ST.closeOverlay();
    else if (t.dataset.toast) ST.toast(t.dataset.toast);
  });
  ST.sheets = {};
  ST.openSheet = (name, data) => ST.sheets[name] && ST.sheets[name](data || {});

  // ---------- Fit phone to window ----------
  function fit() {
    const phone = document.querySelector('.phone');
    const real = matchMedia('(max-width: 560px)').matches;
    phone.classList.toggle('real', real);
    if (real) return;
    const s = Math.min(1, (innerHeight - 48) / 866, (document.querySelector('.stage').clientWidth - 40) / 412);
    phone.style.setProperty('--fit', s.toFixed(3));
  }
  addEventListener('resize', fit);

  ST.boot = () => {
    fit();
    const { id, params } = parseHash();
    stack = [{ id, params }];
    render(id, params);
  };
})();
