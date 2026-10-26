/* Admin shell: navigation, breadcrumbs, command palette, menus, drawer, theme,
   and the remaining CMS pages (dashboard, question bank, study, exams, users,
   payments, onboarding & home, feature flags, audit log). */
(function () {
  const { P, I, naira, esc, toast, math, render } = window.ADMIN;
  const $ = s => document.querySelector(s);

  // ---------- Navigation model ----------
  const NAV = [
    ['Overview', [['dashboard', 'Dashboard', 'squares-four']]],
    ['Content', [['questions', 'Question bank', 'database'], ['csv', 'CSV import', 'file-csv'], ['study', 'Study content', 'books'], ['exams', 'Exams & years', 'exam'], ['news', 'News', 'newspaper'], ['challenges', 'Challenges & events', 'trophy', '3', 'warn']]],
    ['Students', [['users', 'Users', 'users'], ['referrals', 'Referrals', 'gift', '2'], ['fraud', 'Fraud & bans', 'shield-warning', '6', 'error']]],
    ['Money', [['payments', 'Payments', 'receipt'], ['codes', 'Redeem codes', 'ticket'], ['plans', 'Plans & AI limits', 'sliders-horizontal']]],
    ['App control', [['access', 'Free vs Premium', 'scales'], ['onboarding', 'Onboarding & home', 'device-mobile'], ['tabs', 'Tabs manager', 'layout'], ['leaderboard', 'Leaderboard', 'ranking'], ['flags', 'Feature flags & app', 'toggle-right']]],
    ['System', [['audit', 'Audit log', 'list-checks']]]
  ];
  const PARENT = { editor: ['questions', 'Edit question'] };
  const find = id => { for (const [g, items] of NAV) for (const it of items) if (it[0] === id) return { group: g, item: it }; return null; };

  $('#nav').innerHTML = NAV.map(([g, items]) => `<div class="nav-grp"><span class="nav-label">${g}</span>${items.map(([id, label, ic, badge, tone]) =>
    `<a href="#${id}" data-p="${id}"><i class="ph ph-${ic}"></i><span class="grow">${label}</span>${badge ? `<span class="nav-badge ${tone || ''}">${badge}</span>` : ''}</a>`).join('')}</div>`).join('');

  ADMIN.afterRender = id => {
    const parent = PARENT[id], f = find(parent ? parent[0] : id) || find('dashboard');
    document.querySelectorAll('#nav a').forEach(a => a.classList.toggle('on', a.dataset.p === (parent ? parent[0] : id)));
    $('#crumbs').innerHTML = `<span class="muted">${f.group}</span>${I('caret-right')}${parent ? `<a href="#${parent[0]}">${f.item[1]}</a>${I('caret-right')}<b>${parent[1]}</b>` : `<b>${f.item[1]}</b>`}`;
    closeSide(); $('#page').scrollTop = 0; window.scrollTo(0, 0);
  };

  // ---------- Sidebar (mobile), menus, theme ----------
  const openSide = () => { $('#adm').classList.add('side-open'); };
  const closeSide = () => { $('#adm').classList.remove('side-open'); };
  $('#menuBtn').onclick = openSide; $('#scrimSide').onclick = closeSide;

  const ALERTS = [['shield-warning', 'error', '3 entries to review', 'Weekly Challenge #44 fair-play queue', 'challenges'], ['currency-ngn', 'warn', `${naira(35000)} in prizes to pay`, 'Challenge #43 winners verified', 'challenges'],
    ['users-three', 'error', '6 linked-account groups', 'Possible multiple accounts', 'fraud'], ['file-csv', 'warn', '3 rows failed in last import', 'jamb-2025-chemistry.csv', 'csv']];
  $('#alertsMenu').innerHTML = `<div class="menu-head"><b>Needs attention</b><span>${ALERTS.length} items</span></div>${ALERTS.map(([ic, tone, t, d, go]) => `<a href="#${go}" class="alert-item"><span class="al-ic ${tone}">${I(ic, 1)}</span><span><b>${t}</b><small>${d}</small></span></a>`).join('')}`;
  const toggleMenu = (btn, menu) => { btn.onclick = e => { e.stopPropagation(); const was = !$(menu).classList.contains('hidden'); document.querySelectorAll('.menu').forEach(m => m.classList.add('hidden')); if (!was) $(menu).classList.remove('hidden'); }; };
  toggleMenu($('#alertsBtn'), '#alertsMenu'); toggleMenu($('#meBtn'), '#meMenu');
  document.addEventListener('click', e => { if (!e.target.closest('.menu-wrap')) document.querySelectorAll('.menu').forEach(m => m.classList.add('hidden')); if (e.target.closest('.menu a, .menu button')) document.querySelectorAll('.menu').forEach(m => m.classList.add('hidden')); });
  document.addEventListener('click', e => { const t = e.target.closest('[data-toast]'); if (t && !t.closest('#page .scr')) toast(t.dataset.toast); });

  const THEMES = [['system', 'circle-half', 'Theme follows your device'], ['light', 'sun', 'Light theme'], ['dark', 'moon', 'Dark theme']];
  const syncTheme = () => { const t = THEMES.find(x => x[0] === ST.getTheme()) || THEMES[0]; $('#themeBtn').innerHTML = I(t[1]); $('#themeBtn').setAttribute('aria-label', t[2]); };
  $('#themeBtn').onclick = () => { const i = THEMES.findIndex(x => x[0] === ST.getTheme()); const n = THEMES[(i + 1) % 3]; ST.setTheme(n[0]); syncTheme(); toast(n[2]); };
  syncTheme();

  // ---------- Drawer ----------
  ADMIN.drawer = (html, mount) => {
    const d = $('#drawer');
    d.innerHTML = `<div class="drawer-scrim" data-dclose></div><aside class="drawer-panel"><button class="icon-btn drawer-x" data-dclose aria-label="Close">${I('x')}</button>${html}</aside>`;
    d.classList.remove('hidden'); math(d); mount && mount(d);
    d.querySelectorAll('[data-dclose]').forEach(x => x.onclick = ADMIN.closeDrawer);
  };
  ADMIN.closeDrawer = () => { $('#drawer').classList.add('hidden'); $('#drawer').innerHTML = ''; };

  // ---------- Command palette (Ctrl/Cmd + K) ----------
  const ACTIONS = [['New question', 'editor', 'plus-circle'], ['Import questions from CSV', 'csv', 'file-csv'], ['Post news', 'news', 'newspaper'], ['Create a challenge', 'challenges', 'trophy'],
    ['Create a redeem code', 'codes', 'ticket'], ['Find student: Tolu Adeyemi', 'users?u=tolu', 'user'], ['Change Free vs Premium', 'access', 'scales'], ['Turn on maintenance mode', 'flags', 'wrench']];
  const items = () => [...NAV.flatMap(([g, its]) => its.map(([id, label, ic]) => [label, id, ic, g])), ...ACTIONS.map(([l, id, ic]) => [l, id, ic, 'Action'])];
  const openPalette = () => {
    const w = $('#palette');
    w.innerHTML = `<div class="pal-scrim"></div><div class="pal-box"><div class="pal-input">${I('magnifying-glass')}<input id="palIn" placeholder="Search pages and actions" autocomplete="off"><kbd>Esc</kbd></div><div class="pal-list" id="palList"></div></div>`;
    w.classList.remove('hidden');
    let sel = 0;
    const draw = () => {
      const q = $('#palIn').value.trim().toLowerCase(), list = items().filter(x => !q || (x[0] + ' ' + x[3]).toLowerCase().includes(q)).slice(0, 9);
      sel = Math.min(sel, Math.max(0, list.length - 1));
      $('#palList').innerHTML = list.length ? list.map(([l, id, ic, g], i) => `<a href="#${id}" class="pal-item ${i === sel ? 'sel' : ''}">${I(ic)}<span class="grow">${l}</span><small>${g}</small></a>`).join('') : `<p class="muted t-sm" style="padding:16px">No match.</p>`;
      return list;
    };
    let list = draw();
    const inp = $('#palIn'); inp.focus();
    inp.oninput = () => { sel = 0; list = draw(); };
    inp.onkeydown = e => {
      if (e.key === 'ArrowDown') { sel = Math.min(sel + 1, list.length - 1); list = draw(); e.preventDefault(); }
      if (e.key === 'ArrowUp') { sel = Math.max(sel - 1, 0); list = draw(); e.preventDefault(); }
      if (e.key === 'Enter' && list[sel]) { location.hash = '#' + list[sel][1]; closePalette(); }
    };
    w.querySelector('.pal-scrim').onclick = closePalette;
    w.querySelector('#palList').onclick = e => { if (e.target.closest('a')) closePalette(); };
  };
  const closePalette = () => { $('#palette').classList.add('hidden'); $('#palette').innerHTML = ''; };
  $('#sideSearch').onclick = openPalette;
  document.addEventListener('keydown', e => {
    if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === 'k') { e.preventDefault(); openPalette(); }
    if (e.key === 'Escape') { closePalette(); ADMIN.closeDrawer(); document.querySelectorAll('.menu').forEach(m => m.classList.add('hidden')); closeSide(); }
  });

  // ---------- Small helpers ----------
  const spark = (pts, tone = 'var(--c-secondary)') => { const max = Math.max(...pts), min = Math.min(...pts), W = 96, H = 30; const xy = pts.map((v, i) => `${(i / (pts.length - 1) * W).toFixed(1)},${(H - 3 - (v - min) / (max - min || 1) * (H - 6)).toFixed(1)}`).join(' ');
    return `<svg class="spark" viewBox="0 0 ${W} ${H}" aria-hidden="true"><polyline points="${xy}" fill="none" stroke="${tone}" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/></svg>`; };
  const pill = (txt, tone) => `<span class="pill ${tone}">${txt}</span>`;
  const head = (title, desc, actions = '') => `<div class="page-head"><div><h1 class="t-h1">${title}</h1>${desc ? `<p class="muted mt2">${desc}</p>` : ''}</div><div class="row g2 wrap">${actions}</div></div>`;
  const card = (title, body, actions = '', cls = '') => `<section class="card panel ${cls}">${title ? `<div class="panel-head"><h2 class="t-h3">${title}</h2><div class="row g2">${actions}</div></div>` : ''}<div class="panel-body">${body}</div></section>`;
  const greeting = () => { const h = new Date().getHours(); return h < 12 ? 'Good morning' : h < 17 ? 'Good afternoon' : 'Good evening'; };

  // ---------- Dashboard ----------
  P.dashboard = () => {
    const rev = [182, 205, 196, 240, 228, 265, 251, 290, 276, 310, 298, 335, 352, 391].map(x => x * 1000);
    const W = 640, H = 220, pad = 34, max = 420000;
    const xy = rev.map((v, i) => [pad + i * (W - pad - 8) / (rev.length - 1), H - 26 - v / max * (H - 46)]);
    const line = xy.map(p => p.map(n => n.toFixed(1)).join(',')).join(' ');
    const mix = [['Free', 16810, 'var(--neutral-300)'], ['Monthly', 512, 'var(--blue-400)'], ['3 Months', 604, 'var(--blue-700)'], ['Exam Season', 171, 'var(--gold-400)']];
    const paid = mix.slice(1).reduce((t, x) => t + x[1], 0); let acc = 0;
    const donut = mix.slice(1).map(([, v, col]) => { const f = v / paid, a0 = acc * 2 * Math.PI, a1 = (acc + f) * 2 * Math.PI; acc += f; const r = 52, cx = 64, cy = 64, large = f > .5 ? 1 : 0;
      return `<path d="M ${cx + r * Math.sin(a0)} ${cy - r * Math.cos(a0)} A ${r} ${r} 0 ${large} 1 ${cx + r * Math.sin(a1)} ${cy - r * Math.cos(a1)}" stroke="${col}" stroke-width="18" fill="none"/>`; }).join('');
    return `
    <div class="dash-hero"><div><span class="t-sm muted">${new Date().toLocaleDateString('en-GB', { weekday: 'long', day: 'numeric', month: 'long' })}</span><h1 class="t-h1 mt2">${greeting()}, Ada</h1><p class="muted mt2">Here is what is happening on SolutionTee today.</p></div>
      <div class="row g2 wrap"><a class="btn btn-outline btn-sm" href="#editor">${I('plus')} New question</a><a class="btn btn-outline btn-sm" href="#news">${I('newspaper')} Post news</a><a class="btn btn-primary btn-sm" href="#challenges">${I('trophy', 1)} Create challenge</a></div></div>
    <div class="attention">${ALERTS.map(([ic, tone, t, d, go]) => `<a class="att-card" href="#${go}"><span class="al-ic ${tone}">${I(ic, 1)}</span><span class="grow"><b>${t}</b><small>${d}</small></span>${I('arrow-right')}</a>`).join('')}</div>
    <div class="kpi-grid">
      ${[['Students', '18,452', '+6.1%', [12, 13, 13, 14, 15, 15, 16, 17, 18]], ['Premium students', '1,287', '+3.2%', [9, 9, 10, 10, 11, 11, 12, 12, 13]], ['Revenue (14 days)', naira(3912500), '+11.8%', rev.map(x => x / 1000)], ['Tests taken', '41,068', '+9.7%', [30, 32, 31, 35, 36, 38, 37, 40, 41]]]
        .map(([l, v, d, s]) => `<div class="card kpi-tile"><span class="t-sm muted bold">${l}</span><div class="row between" style="align-items:flex-end"><b>${v}</b>${spark(s)}</div><span class="delta-pill up">${I('trend-up', 1)} ${d} <span class="muted" style="font-weight:500">vs last period</span></span></div>`).join('')}
    </div>
    <div class="dash-grid">
      ${card('Revenue', `<div class="adm-chart"><svg viewBox="0 0 ${W} ${H}" role="img" aria-label="Revenue rising over 14 days">
          <defs><linearGradient id="revg" x1="0" x2="0" y1="0" y2="1"><stop offset="0" stop-color="var(--c-secondary)" stop-opacity=".22"/><stop offset="1" stop-color="var(--c-secondary)" stop-opacity="0"/></linearGradient></defs>
          ${[100000, 200000, 300000, 400000].map(v => { const y = H - 26 - v / max * (H - 46); return `<line class="gridline" x1="${pad}" x2="${W - 8}" y1="${y}" y2="${y}"/><text class="axis" x="0" y="${y + 4}">${v / 1000}k</text>`; }).join('')}
          <polygon points="${xy[0][0]},${H - 26} ${line} ${xy[xy.length - 1][0]},${H - 26}" fill="url(#revg)"/>
          <polyline class="rev-line" points="${line}"/>
          ${xy.map((p, i) => i === xy.length - 1 ? `<circle cx="${p[0]}" cy="${p[1]}" r="5" fill="var(--c-accent)" stroke="var(--c-surface)" stroke-width="2"/>` : '').join('')}
          ${[0, 6, 13].map(i => `<text class="axis" x="${xy[i][0] - 14}" y="${H - 6}">${['13 Oct', '19 Oct', '26 Oct'][[0, 6, 13].indexOf(i)]}</text>`).join('')}</svg></div>`,
        `<div class="seg" style="width:220px"><button>7 days</button><button class="on">14 days</button><button>30 days</button></div>`, 'span-2')}
      ${card('Plan mix', `<div class="row g4" style="align-items:center"><svg viewBox="0 0 128 128" width="128" height="128" style="transform:rotate(0)" aria-label="Paid plan mix">${donut}<text x="64" y="62" text-anchor="middle" class="axis" style="font-size:22px;font-weight:700;fill:var(--c-text)">7.0%</text><text x="64" y="80" text-anchor="middle" class="axis">paid</text></svg>
          <div class="stack g2 grow">${mix.map(([n, v, col]) => `<div class="row between t-sm"><span class="row g2"><i class="legend-dot" style="background:${col}"></i>${n}</span><b class="tnum">${v.toLocaleString()}</b></div>`).join('')}</div></div>`)}
      ${card('Live challenge', `<div class="stack g3"><div class="row between"><b>Weekly Challenge #44</b><span class="live-pill"><span class="live-dot" aria-hidden="true"></span><span class="lp-txt">Live</span></span></div>
          <div class="grid3 mini-stats"><div><b class="tnum">1,284</b><span>joined</span></div><div><b class="tnum">23</b><span>disqualified</span></div><div><b class="tnum">2h 10m</b><span>to close</span></div></div>
          <div class="stack g1 t-sm">${[['Chiamaka O.', '10/10 · 2:51'], ['Ifeoma N.', '10/10 · 2:51'], ['Abdullahi M.', '10/10 · 3:30']].map(([n, s], i) => `<div class="row g2"><span class="lb-rank tnum">${i + 1}</span><span class="grow">${n}</span><span class="tnum muted">${s}</span></div>`).join('')}</div>
          <a class="btn btn-outline btn-sm" href="#challenges">Manage challenge</a></div>`)}
      ${card('Top subjects', `<div class="stack g3">${[['Use of English', 92], ['Mathematics', 81], ['Biology', 64], ['Chemistry', 58], ['Physics', 51]].map(([s, v]) => `<div class="stack g1"><div class="row between t-sm"><b>${s}</b><span class="muted tnum">${(v * 112).toLocaleString()} tests</span></div><div class="bar" style="height:6px"><i style="width:${v}%"></i></div></div>`).join('')}</div>`)}
      ${card('AI tutor today', `<div class="stack g3"><div class="row between"><b class="tnum" style="font-size:28px">4,812</b><span class="pill ok">Healthy</span></div><span class="t-sm muted">prompts answered · 1.9 s average reply</span>
          <div class="stack g1"><div class="row between t-cap"><span>NVIDIA free-tier rate limit</span><b>61%</b></div><div class="bar" style="height:6px"><i style="width:61%;background:var(--c-warning)"></i></div></div>
          <a class="btn btn-ghost btn-sm" href="#plans" style="align-self:flex-start;padding:0">AI settings ${I('arrow-right')}</a></div>`)}
      ${card('Recent activity', `<div class="activity">${AUDIT.slice(0, 5).map(a => `<div class="act-row"><span class="avatar" style="width:30px;height:30px;font-size:11px">${a[1].split(' ').map(x => x[0]).join('')}</span><span class="grow t-sm"><b>${a[1]}</b> ${a[2].toLowerCase()} <span class="muted">${a[3]}</span></span><span class="t-cap muted">${a[0]}</span></div>`).join('')}</div>`, `<a class="btn btn-ghost btn-sm" href="#audit">View all</a>`, 'span-2')}
    </div>`;
  };

  // ---------- Question bank ----------
  const QB = [['If $\\log_{10} 2 = 0.3010$, evaluate $\\log_{10} 4.5$', 'JAMB', 2001, 'Mathematics', 'Logarithms', 'Medium', 'Published'], ['Evaluate $\\int_0^2 (3x^2+1)\\,dx$', 'JAMB', 2025, 'Mathematics', 'Integration', 'Hard', 'Published'],
    ['The SI unit of force is the', 'WAEC', 2024, 'Physics', 'Mechanics', 'Easy', 'Published'], ['How many moles are in $4.4\\,\\text{g}$ of $\\text{CO}_2$?', 'JAMB', 2002, 'Chemistry', 'Mole concept', 'Medium', 'Needs review'],
    ['Neither the teacher nor the students ____ in the hall.', 'NECO', 2023, 'English', 'Concord', 'Easy', 'Draft'], ['Find the next number: $2, 6, 18, 54, \\ldots$', 'JAMB', 2025, 'Mathematics', 'Sequences', 'Easy', 'Published'],
    ['Which gas turns lime water milky?', 'JAMB', 2025, 'Chemistry', 'Gases', 'Easy', 'Duplicate?'], ['The basic unit of life is the', 'WAEC', 2022, 'Biology', 'Cell biology', 'Easy', 'Published']];
  const qTone = s => ({ Published: 'ok', Draft: 'neutral', 'Needs review': 'warn', 'Duplicate?': 'error' }[s]);
  P.questions = () => `
    ${head('Question bank', '12,480 questions across JAMB, WAEC and NECO. Locked years are only sent to students whose plan allows them.', `<a class="btn btn-outline btn-sm" href="#csv">${I('file-csv')} Import CSV</a><a class="btn btn-primary btn-sm" href="#editor">${I('plus', 1)} New question</a>`)}
    <div class="tabs-line">${[['All', '12,480'], ['Published', '11,906'], ['Drafts', '412'], ['Needs review', '141'], ['Possible duplicates', '21']].map(([t, n], i) => `<button class="${i ? '' : 'on'}" data-qt="${t}">${t} <span>${n}</span></button>`).join('')}</div>
    <div class="filter-bar"><div class="input" style="min-height:40px;flex:1;min-width:200px"><i class="ph ph-magnifying-glass lead-ic"></i><input id="qbSearch" placeholder="Search question text or topic" style="min-height:40px"></div>
      ${['All exams|JAMB|WAEC|NECO', 'All subjects|Mathematics|English|Physics|Chemistry|Biology', 'All years|2025|2024|2023|2002|2001'].map(o => `<div class="input" style="min-height:40px"><select style="min-height:40px">${o.split('|').map(x => `<option>${x}</option>`).join('')}</select><i class="ph ph-caret-down sel-caret"></i></div>`).join('')}</div>
    <div class="bulk-bar hidden" id="bulk"><b id="bulkN">0 selected</b><button class="btn btn-sm btn-primary" data-toast="Published. Students see them on next sync.">Publish</button><button class="btn btn-sm btn-outline" data-toast="Moved">Move to…</button><button class="btn btn-sm btn-outline" data-toast="Marked for review">Mark for review</button><button class="btn btn-sm btn-ghost" style="color:var(--c-error)" data-toast="Deleted (can be undone for 7 days)">Delete</button></div>
    <section class="card" style="overflow:hidden"><div style="overflow:auto"><table class="tbl hover"><thead><tr><th style="width:36px"><input type="checkbox" id="qbAll" aria-label="Select all"></th><th>Question</th><th>Exam</th><th>Subject · topic</th><th>Level</th><th>Status</th><th></th></tr></thead><tbody id="qbRows">
      ${QB.map((r, i) => `<tr data-row="${i}"><td><input type="checkbox" class="qb-ck" aria-label="Select"></td><td class="q-cell">${r[0]}</td><td><b>${r[1]}</b> <span class="muted">${r[2]}</span></td><td>${r[3]}<div class="t-cap muted">${r[4]}</div></td><td>${r[5]}</td><td>${pill(r[6], qTone(r[6]))}</td><td><a class="icon-btn" href="#editor" aria-label="Edit">${I('pencil-simple')}</a></td></tr>`).join('')}
    </tbody></table></div>
    <div class="table-foot"><span class="t-sm muted">Showing 1 to 8 of 12,480</span><div class="row g1"><button class="icon-btn" aria-label="Previous page" disabled>${I('caret-left')}</button><span class="t-sm">Page 1 of 1,560</span><button class="icon-btn" aria-label="Next page" data-toast="Next page">${I('caret-right')}</button></div></div></section>`;
  P.questions.mount = el => {
    const sync = () => { const n = el.querySelectorAll('.qb-ck:checked').length; el.querySelector('#bulk').classList.toggle('hidden', !n); el.querySelector('#bulkN').textContent = `${n} selected`; };
    el.querySelectorAll('.qb-ck').forEach(c => c.onchange = sync);
    el.querySelector('#qbAll').onchange = e => { el.querySelectorAll('.qb-ck').forEach(c => c.checked = e.target.checked); sync(); };
    el.querySelectorAll('[data-qt]').forEach(b => b.onclick = () => { el.querySelectorAll('[data-qt]').forEach(x => x.classList.toggle('on', x === b)); const t = b.dataset.qt; el.querySelectorAll('#qbRows tr').forEach((tr, i) => { const st = QB[i][6]; tr.classList.toggle('hidden', !(t === 'All' || (t === 'Published' && st === 'Published') || (t === 'Drafts' && st === 'Draft') || (t === 'Needs review' && st === 'Needs review') || (t === 'Possible duplicates' && st === 'Duplicate?'))); }); });
    el.querySelector('#qbSearch').oninput = e => { const q = e.target.value.toLowerCase(); el.querySelectorAll('#qbRows tr').forEach((tr, i) => tr.classList.toggle('hidden', !!q && !(QB[i][0] + QB[i][3] + QB[i][4]).toLowerCase().includes(q))); };
    el.querySelectorAll('#qbRows tr').forEach(tr => tr.addEventListener('click', e => { if (!e.target.closest('input,a')) location.hash = '#editor'; }));
  };

  // ---------- Study content ----------
  const SECTIONS = [['Past questions', 'exam', 12480, 'Free + Premium', true], ['Video solutions', 'play-circle', 842, 'Premium', true], ['Topic lessons', 'chalkboard-teacher', 316, 'Premium', true], ['Lesson notes', 'note', 228, 'Premium', true], ['Novels', 'books', 3, 'Premium', true], ['Syllabus & brochure', 'file-pdf', 34, '2 free', true], ['Exam tips (custom)', 'lightbulb', 12, 'Free', false]];
  const ITEMS = [['Quadratic equations', 'Lesson note', 'Mathematics', 'Premium', 'Published', ''], ['Indices and logarithms', 'Lesson note', 'Mathematics', 'Free', 'Published', ''], ['Organic chemistry basics', 'Lesson note', 'Chemistry', 'Premium', 'Scheduled', '1 Nov, 08:00'], ['Waves and sound', 'Topic lesson (video)', 'Physics', 'Premium', 'Published', ''], ['Concord made easy', 'Lesson note', 'English', 'Premium', 'Draft', '']];
  P.study = () => `
    ${head('Study content', 'Sections students see in the Study tab. Drag to reorder, hide or add your own.', `<button class="btn btn-outline btn-sm" data-toast="New section added at the bottom">${I('plus')} Add section</button><button class="btn btn-primary btn-sm" data-toast="Opens the lesson editor (rich text, LaTeX, images, PDF)">${I('plus', 1)} New lesson</button>`)}
    <div class="study-grid">
      ${card('Sections', `<div class="sec-list">${SECTIONS.map(([n, ic, c, acc, vis], i) => `<div class="sec-row ${i === 3 ? 'on' : ''} ${vis ? '' : 'off'}" data-sec="${i}"><span class="handle">${I('dots-six-vertical')}</span><span class="ic navy">${I(ic, 1)}</span><span class="grow"><b class="t-sm">${n}</b><small class="muted">${c.toLocaleString()} items · ${acc}</small></span><span class="switch"><input type="checkbox" ${vis ? 'checked' : ''} aria-label="Visible"><span></span></span></div>`).join('')}</div>`)}
      ${card('Lesson notes', `<table class="tbl hover"><thead><tr><th>Title</th><th>Type</th><th>Subject</th><th>Access</th><th>Status</th></tr></thead><tbody>
        ${ITEMS.map(([t, ty, s, a, st, when]) => `<tr><td><b>${t}</b></td><td class="muted">${ty}</td><td>${s}</td><td>${pill(a, a === 'Free' ? 'ok' : 'gold')}</td><td>${pill(st, st === 'Published' ? 'ok' : st === 'Scheduled' ? 'info' : 'neutral')}${when ? `<div class="t-cap muted">${when}</div>` : ''}</td></tr>`).join('')}
      </tbody></table>`, `<div class="input" style="min-height:36px"><select style="min-height:36px"><option>All subjects</option><option>Mathematics</option></select><i class="ph ph-caret-down sel-caret"></i></div>`, 'span-2')}
    </div>`;
  P.study.mount = el => el.querySelectorAll('.sec-row').forEach(r => r.addEventListener('click', e => { if (e.target.closest('.switch')) return; el.querySelectorAll('.sec-row').forEach(x => x.classList.toggle('on', x === r)); el.querySelectorAll('.panel-head h2')[1].textContent = SECTIONS[+r.dataset.sec][0]; }));

  // ---------- Exams & years ----------
  P.exams = () => `
    ${head('Exams & years', 'Exam rules, subjects and which years students can see. Publishing a year makes it appear in the app straight away.', `<button class="btn btn-outline btn-sm" data-toast="New exam body added (e.g. Post-UTME)">${I('plus')} Add exam</button>`)}
    <div class="exam-tabs">${['JAMB', 'WAEC', 'NECO'].map((b, i) => `<button class="${i ? '' : 'on'}" data-ex="${b}"><span class="exam-logo sm" data-file="${b.toLowerCase()}.png" data-short="${b}"><span class="crop"><img src="/brand/exam-bodies/${b.toLowerCase()}.png" alt="" style="width:100%;height:auto"></span></span>${b}</button>`).join('')}<button class="add" data-toast="Add Post-UTME or another exam">${I('plus')} Add</button></div>
    <div class="dash-grid" style="grid-template-columns:1fr 1.4fr">
      ${card('Exam rules (exam_configs)', `<div class="stack g3">${[['Subjects per candidate', '4 (Use of English compulsory)'], ['Questions', 'English 60, others 40 (180 total)'], ['Time', '120 minutes'], ['Score scale', 'Each subject /100, total /400'], ['Options per question', 'A to D (E allowed)']].map(([k, v]) => `<div class="row between t-sm" style="padding:8px 0;border-bottom:1px solid var(--c-border)"><span class="muted">${k}</span><b>${v}</b></div>`).join('')}
        <button class="btn btn-outline btn-sm" style="align-self:flex-start" data-toast="Opens the rules editor">${I('pencil-simple')} Edit rules</button></div>`)}
      ${card('Years', `<div class="year-admin">${Array.from({ length: 27 }, (_, k) => 2000 + k).map(y => { const st = y === 2026 ? 'draft' : y > 2026 ? 'empty' : 'pub'; return `<button class="ya ${st}" data-y="${y}"><b>${y}</b><small>${st === 'pub' ? '180 Q' : st === 'draft' ? '96 Q · draft' : 'empty'}</small></button>`; }).join('')}</div>
        <p class="t-cap muted mt3">${pill('Published', 'ok')} ${pill('Draft', 'warn')} ${pill('No questions', 'neutral')} · Free students see the years set in Free vs Premium.</p>`)}
    </div>`;
  P.exams.mount = el => {
    el.querySelectorAll('[data-ex]').forEach(b => b.onclick = () => el.querySelectorAll('[data-ex]').forEach(x => x.classList.toggle('on', x === b)));
    el.querySelectorAll('.ya').forEach(b => b.onclick = () => {
      const y = b.dataset.y;
      if (b.classList.contains('empty')) { toast(`JAMB ${y} has no questions yet. Import a CSV first.`); return; }
      const pub = b.classList.contains('pub');
      ADMIN.drawer(`<h2 class="t-h2">JAMB ${y}</h2><p class="muted mt2">${pub ? 'Published. Students can practise this year.' : 'Draft. Students cannot see it yet.'}</p>
        <div class="stack g2 mt4">${['Use of English · 60', 'Mathematics · 40', 'Physics · 40', 'Chemistry · 40', 'Biology · 40'].map(s => `<div class="row between card card-pad t-sm"><b>${s.split(' · ')[0]}</b><span class="muted">${s.split(' · ')[1]} questions</span></div>`).join('')}</div>
        <button class="btn ${pub ? 'btn-outline' : 'btn-primary'} btn-block mt4" id="pubY">${pub ? 'Unpublish this year' : `Publish JAMB ${y}`}</button>
        <p class="t-cap muted mt2">${pub ? '' : 'A push "JAMB ' + y + ' is now available" is sent to students.'}</p>`, d => d.querySelector('#pubY').onclick = () => { b.classList.toggle('pub', !pub); b.classList.toggle('draft', pub); b.querySelector('small').textContent = pub ? 'draft' : '180 Q'; ADMIN.closeDrawer(); toast(pub ? `JAMB ${y} unpublished.` : `JAMB ${y} published. Students see it now.`); });
    });
  };

  // ---------- Users ----------
  const USERS = [['Tolu Adeyemi', 'to••••@gmail.com', 'Free', 'Oyo', '12 Sep 2026', '2 min ago', 24, ''], ['Chiamaka Okafor', 'ch••••@yahoo.com', '3 Months', 'Anambra', '3 Aug 2026', '1 h ago', 61, ''], ['Abdullahi Musa', 'ab••••@gmail.com', 'Exam Season', 'Kano', '29 Jul 2026', 'Today', 48, ''],
    ['Seyi Adebayo', 'se••••@gmail.com', 'Free', 'Lagos', '1 Oct 2026', '3 days ago', 9, 'Flagged'], ['Ifeoma Nwosu', 'if••••@gmail.com', 'Monthly', 'Enugu', '17 Sep 2026', 'Yesterday', 33, ''], ['kemi.k', 'ke••••@gmail.com', 'Free', 'Ogun', '2 Oct 2026', '21 Oct', 4, 'Banned']];
  const planPill = p => pill(p, p === 'Free' ? 'neutral' : 'gold');
  P.users = () => `
    ${head('Users', '18,452 students. Click a student to see their activity, plan, device and payments.', `<button class="btn btn-outline btn-sm" data-toast="Export started. We email you the CSV.">${I('download-simple')} Export</button>`)}
    <div class="filter-bar"><div class="input" style="min-height:40px;flex:1;min-width:220px"><i class="ph ph-magnifying-glass lead-ic"></i><input id="uSearch" placeholder="Search name, email or phone" style="min-height:40px"></div>
      ${['All plans|Free|Premium', 'All states|Lagos|Oyo|Kano|Anambra', 'Any status|Active|Flagged|Banned'].map(o => `<div class="input" style="min-height:40px"><select style="min-height:40px">${o.split('|').map(x => `<option>${x}</option>`).join('')}</select><i class="ph ph-caret-down sel-caret"></i></div>`).join('')}</div>
    <section class="card" style="overflow:hidden"><div style="overflow:auto"><table class="tbl hover"><thead><tr><th>Student</th><th>Plan</th><th>State</th><th>Joined</th><th>Last active</th><th>Tests</th><th></th></tr></thead><tbody id="uRows">
      ${USERS.map((u, i) => `<tr data-u="${i}" class="click"><td><div class="row g3"><span class="avatar" style="width:34px;height:34px;font-size:12px">${u[0].split(/[ .]/).map(x => x[0]).join('').toUpperCase().slice(0, 2)}</span><span><b>${u[0]}</b><div class="t-cap muted">${u[1]}</div></span></div></td><td>${planPill(u[2])}</td><td>${u[3]}</td><td class="muted">${u[4]}</td><td class="muted">${u[5]}</td><td class="tnum">${u[6]}</td><td>${u[7] ? pill(u[7], u[7] === 'Banned' ? 'error' : 'warn') : ''}</td></tr>`).join('')}
    </tbody></table></div><div class="table-foot"><span class="t-sm muted">Showing 6 of 18,452</span><button class="btn btn-ghost btn-sm" data-toast="Loading more">Load more</button></div></section>`;
  const userDrawer = i => {
    const u = USERS[i];
    ADMIN.drawer(`
      <div class="row g3"><span class="avatar" style="width:56px;height:56px;font-size:18px">${u[0].split(/[ .]/).map(x => x[0]).join('').toUpperCase().slice(0, 2)}</span><div><h2 class="t-h2">${u[0]}</h2><span class="muted t-sm">${u[1]} · ${u[3]}</span><div class="row g2 mt2">${planPill(u[2])}${u[7] ? pill(u[7], u[7] === 'Banned' ? 'error' : 'warn') : pill('Active', 'ok')}</div></div></div>
      <div class="grid3 mini-stats mt4"><div><b class="tnum">${u[6]}</b><span>tests</span></div><div><b class="tnum">${200 + u[6]}</b><span>best JAMB</span></div><div><b class="tnum">3</b><span>referrals</span></div></div>
      <h3 class="t-label mt5">Premium</h3><div class="row g2 mt2"><div class="input" style="min-height:40px;flex:1"><select id="grant" style="min-height:40px"><option>Add 7 days</option><option>Add 30 days</option><option>Add 90 days</option></select><i class="ph ph-caret-down sel-caret"></i></div><button class="btn btn-primary btn-sm" id="grantGo">Grant</button></div>
      <p class="t-cap muted mt2">Manual grants are logged with your name and a reason.</p>
      <h3 class="t-label mt5">Device</h3><div class="card card-pad stack g1 mt2 t-sm"><div class="row between"><span>Tecno Spark 10 · Android 13</span>${pill('1 account', 'ok')}</div><span class="t-cap muted">Play Integrity: passed · app genuine · not rooted</span></div>
      <h3 class="t-label mt5">Recent activity</h3><div class="activity mt2">${[['JAMB UTME Mock', '287/400', 'Today'], ['Weekly Challenge #44', '9/10 · #6', 'Today'], ['AI tutor', '3 prompts', 'Yesterday']].map(([a, b, c]) => `<div class="act-row"><span class="grow t-sm"><b>${a}</b> <span class="muted">${b}</span></span><span class="t-cap muted">${c}</span></div>`).join('')}</div>
      <h3 class="t-label mt5">Payments</h3><div class="activity mt2">${u[2] === 'Free' ? '<p class="t-sm muted">No payments yet.</p>' : `<div class="act-row"><span class="grow t-sm"><b>${u[2]}</b> · Paystack</span><b class="tnum">${naira(3500)}</b></div>`}</div>
      <div class="row g2 mt5 wrap"><button class="btn btn-outline btn-sm" data-toast="Password reset email sent">${I('key')} Reset password</button><button class="btn btn-outline btn-sm" data-toast="Data export prepared (NDPA request)">${I('download-simple')} Export data</button><button class="btn btn-danger btn-sm" id="banU">${I('prohibit', 1)} Ban</button></div>`, d => {
      d.querySelector('#grantGo').onclick = () => toast(`${d.querySelector('#grant').value.replace('Add', 'Added')} of Premium for ${u[0]}. Logged.`);
      const ban = d.querySelector('#banU'); ban.onclick = () => { if (!ban.dataset.sure) { ban.dataset.sure = 1; ban.textContent = 'Tap again to ban'; return; } ADMIN.closeDrawer(); toast(`${u[0]} banned. Device blocked. Logged.`); };
    });
  };
  P.users.mount = el => {
    el.querySelectorAll('[data-u]').forEach(tr => tr.onclick = () => userDrawer(+tr.dataset.u));
    el.querySelector('#uSearch').oninput = e => { const q = e.target.value.toLowerCase(); el.querySelectorAll('[data-u]').forEach(tr => tr.classList.toggle('hidden', !!q && !USERS[+tr.dataset.u].join(' ').toLowerCase().includes(q))); };
    if (location.hash.includes('u=tolu')) userDrawer(0);
  };

  // ---------- Payments ----------
  const PAYS = [['T_8KQ2X1', 'Chiamaka Okafor', '3 Months', 3500, 'Paystack · card', 'Success', '26 Oct, 13:02'], ['GPA.3391-7710', 'Abdullahi Musa', 'Exam Season', 6000, 'Google Play', 'Success', '26 Oct, 11:47'],
    ['T_3MZ7P0', 'Ifeoma Nwosu', 'Monthly', 1500, 'Paystack · transfer', 'Success', '26 Oct, 09:15'], ['T_9WQ1L4', 'Bisi Kolawole', '3 Months', 2800, 'Paystack · USSD · LOYOLA20', 'Pending', '26 Oct, 08:58'],
    ['T_5RT0K2', 'Musa Ibrahim', 'Monthly', 1500, 'Paystack · card', 'Failed', '25 Oct, 22:10'], ['GPA.1182-0047', 'Ngozi Eze', 'Monthly', 1500, 'Google Play', 'Refunded', '25 Oct, 16:31']];
  const payTone = s => ({ Success: 'ok', Pending: 'warn', Failed: 'error', Refunded: 'neutral' }[s]);
  P.payments = () => `
    ${head('Payments', 'Every Paystack and Google Play payment, checked on the server before Premium is given.', `<button class="btn btn-outline btn-sm" data-toast="Reconciliation started: comparing Paystack, Play and our records">${I('arrows-clockwise')} Reconcile</button><button class="btn btn-outline btn-sm" data-toast="Export started">${I('download-simple')} Export</button>`)}
    <div class="kpi-grid">${[['Revenue today', naira(184500)], ['Successful', '96'], ['Pending', '4'], ['Refunds this month', naira(9000)]].map(([l, v]) => `<div class="card kpi-tile"><span class="t-sm muted bold">${l}</span><b>${v}</b></div>`).join('')}</div>
    <div class="tabs-line mt4">${['All', 'Paystack', 'Google Play', 'Pending', 'Failed', 'Refunded'].map((t, i) => `<button class="${i ? '' : 'on'}" data-pt="${t}">${t}</button>`).join('')}</div>
    <section class="card" style="overflow:hidden"><div style="overflow:auto"><table class="tbl hover"><thead><tr><th>Reference</th><th>Student</th><th>Plan</th><th>Amount</th><th>Channel</th><th>Status</th><th>Date</th></tr></thead><tbody>
      ${PAYS.map((p, i) => `<tr class="click" data-pay-row="${i}"><td class="tnum" style="font-family:var(--font-mono);font-size:12px">${p[0]}</td><td><b>${p[1]}</b></td><td>${p[2]}</td><td class="tnum"><b>${naira(p[3])}</b></td><td class="muted">${p[4]}</td><td>${pill(p[5], payTone(p[5]))}</td><td class="muted">${p[6]}</td></tr>`).join('')}
    </tbody></table></div></section>`;
  P.payments.mount = el => {
    el.querySelectorAll('[data-pt]').forEach(b => b.onclick = () => { el.querySelectorAll('[data-pt]').forEach(x => x.classList.toggle('on', x === b)); const t = b.dataset.pt; el.querySelectorAll('[data-pay-row]').forEach(tr => { const p = PAYS[+tr.dataset.payRow]; tr.classList.toggle('hidden', !(t === 'All' || p[4].startsWith(t) || p[5] === t)); }); });
    el.querySelectorAll('[data-pay-row]').forEach(tr => tr.onclick = () => {
      const p = PAYS[+tr.dataset.payRow];
      const steps = p[5] === 'Failed' ? [['Started', true], ['Card declined by bank', false]] : p[5] === 'Pending' ? [['Started', true], ['Waiting for bank confirmation', false]] : [['Started', true], [p[4].startsWith('Google') ? 'Google Play purchase verified' : 'Webhook signature verified', true], ['Paystack verify call: success', !p[4].startsWith('Google')], ['Premium given', true], ...(p[5] === 'Refunded' ? [['Refunded, Premium removed', true]] : [])].filter(s => s[1] !== false || true);
      ADMIN.drawer(`<span class="t-cap muted" style="font-family:var(--font-mono)">${p[0]}</span><h2 class="t-h2 mt2">${naira(p[3])}</h2><div class="row g2 mt2">${pill(p[5], payTone(p[5]))}<span class="muted t-sm">${p[6]}</span></div>
        <div class="stack g2 mt4 t-sm">${[['Student', p[1]], ['Plan', p[2]], ['Channel', p[4]]].map(([k, v]) => `<div class="row between" style="padding:8px 0;border-bottom:1px solid var(--c-border)"><span class="muted">${k}</span><b>${v}</b></div>`).join('')}</div>
        <h3 class="t-label mt5">Timeline</h3><div class="timeline mt2">${steps.map(([s, ok]) => `<div class="tl ${ok ? 'ok' : 'wait'}"><span></span>${s}</div>`).join('')}</div>
        <div class="row g2 mt5">${p[5] === 'Success' ? `<button class="btn btn-outline btn-sm" id="refund">${I('arrow-u-up-left')} Refund</button>` : ''}<button class="btn btn-ghost btn-sm" data-toast="Receipt emailed to the student">${I('envelope-simple')} Resend receipt</button></div>`, d => {
        const r = d.querySelector('#refund'); if (r) r.onclick = () => { if (!r.dataset.sure) { r.dataset.sure = 1; r.textContent = 'Tap again: refund and remove Premium'; return; } ADMIN.closeDrawer(); toast('Refund started. Premium will be removed when it completes.'); };
      });
    });
  };

  // ---------- Onboarding & home ----------
  const SLIDES = ['A real CBT experience', 'Win cash prizes every week', 'Past questions, videos and notes', 'SolutionTee AI tutor', 'See your progress', 'Join live JAMB classes'];
  P.onboarding = () => `
    ${head('Onboarding & home', 'The slides new students see, and what shows on the Home screen.', `<button class="btn btn-primary btn-sm" data-toast="Saved. New installs see the new slides.">Save changes</button>`)}
    <div class="dash-grid" style="grid-template-columns:1.3fr 1fr">
      ${card('Onboarding slides', `<div class="sec-list">${SLIDES.map((t, i) => `<div class="sec-row ${i === 1 ? 'on' : ''}" data-sl="${i}"><span class="handle">${I('dots-six-vertical')}</span><span class="lb-rank tnum">${i + 1}</span><span class="grow"><b class="t-sm">${t}</b><small class="muted">${i === 1 ? 'Animated: trophy, prize, live ranking' : 'Animated illustration'}</small></span><span class="switch"><input type="checkbox" checked aria-label="Show"><span></span></span></div>`).join('')}</div>
        <div class="field mt4"><label for="slT">Title</label><div class="input"><input id="slT" value="${SLIDES[1]}"></div></div>
        <div class="field mt3"><label for="slD">Text</label><div class="input"><textarea id="slD" rows="2" style="min-height:64px">Answer our weekly challenge fast and right to win money. Free and Premium students can join, and play is fair for everyone.</textarea></div></div>`)}
      ${card('Home screen', `<div class="stack g3">${[['Challenges & events section', true], ['Question of the day', true], ['News carousel', true], ['Leaderboard tile', true], ['Invite friends tile', true], ['Upgrade banner (Free only)', true], ['Next live class tile', false]].map(([t, on]) => `<label class="row between t-sm"><span>${t}</span><span class="switch"><input type="checkbox" ${on ? 'checked' : ''}><span></span></span></label>`).join('')}
        <div class="field mt2"><label>Disclaimer (onboarding, About, store)</label><div class="input"><textarea rows="3" style="min-height:80px">SolutionTee CBT is an independent exam-practice platform and is not affiliated with or endorsed by JAMB, WAEC or NECO.</textarea></div></div></div>`)}
    </div>`;
  P.onboarding.mount = el => el.querySelectorAll('[data-sl]').forEach(r => r.addEventListener('click', e => { if (e.target.closest('.switch')) return; el.querySelectorAll('[data-sl]').forEach(x => x.classList.toggle('on', x === r)); el.querySelector('#slT').value = SLIDES[+r.dataset.sl]; }));

  // ---------- Feature flags & app ----------
  const FLAGS = [['challenges_enabled', 'Challenges & events', 'Show challenges, prizes and the Winners wall.', true], ['referrals_enabled', 'Referral programme', 'Invite friends, discount codes and cash rewards.', true],
    ['ai_photo_questions', 'AI photo questions', 'Students can attach a photo to the AI tutor (needs a vision model).', true], ['paystack_in_play_build', 'Paystack in the Play Store app', 'Keep OFF until Google’s billing-choice programme covers Nigeria and we enrol.', false],
    ['paid_events_in_play_build', 'Paid entry in the Play Store app', 'Keep OFF until a lawyer confirms paid contests are allowed.', false], ['leaderboard_enabled', 'Leaderboards', 'Also controlled in Leaderboard settings.', true]];
  P.flags = () => `
    ${head('Feature flags & app', 'Turn features on or off without an app update. Every change is logged.', '')}
    <div class="dash-grid" style="grid-template-columns:1.4fr 1fr">
      ${card('Features', `<div class="flag-list">${FLAGS.map(([k, t, d, on]) => `<label class="flag-row"><span class="grow"><b class="t-sm">${t}</b><small class="muted">${d}</small><code>${k}</code></span><span class="switch"><input type="checkbox" data-flag="${k}" ${on ? 'checked' : ''}><span></span></span></label>`).join('')}</div>`)}
      <div class="stack g4">
        ${card('App version', `<div class="stack g3"><div class="field"><label for="minV">Minimum app version</label><div class="input"><input id="minV" value="1.0.0" style="font-family:var(--font-mono)"></div><span class="help">Older versions are asked to update before they can continue.</span></div>
          <label class="row between t-sm"><span>Force update (block older versions)</span><span class="switch"><input type="checkbox"><span></span></span></label></div>`)}
        ${card('Maintenance mode', `<div class="stack g3"><label class="row between t-sm"><span><b>Maintenance mode</b><br><span class="muted">Students see a friendly message. Downloaded tests still work offline.</span></span><span class="switch"><input type="checkbox" id="maint"><span></span></span></label>
          <div class="field"><label for="maintMsg">Message</label><div class="input"><input id="maintMsg" value="We are improving SolutionTee. Back in 30 minutes."></div></div></div>`)}
      </div>
    </div>`;
  P.flags.mount = el => {
    el.querySelectorAll('[data-flag]').forEach(c => c.onchange = () => toast(`${c.dataset.flag} turned ${c.checked ? 'ON' : 'OFF'}. Logged in the audit log.`));
    el.querySelector('#maint').onchange = e => toast(e.target.checked ? 'Maintenance mode is ON. Students see your message.' : 'Maintenance mode is OFF.');
  };

  // ---------- Audit log ----------
  const AUDIT = [['10:02', 'Ada Okoye', 'Published year', 'JAMB 2026 Physics', 'content'], ['09:58', 'Ada Okoye', 'Paid winner', 'Ifeoma N. · ₦20,000', 'money'], ['09:41', 'Musa Bello', 'Imported CSV (205 rows)', 'JAMB 2025 Chemistry', 'content'],
    ['09:12', 'Ngozi Eze', 'Banned account group', 'Device ••a91f (4 accounts)', 'security'], ['Yesterday', 'Ada Okoye', 'Changed AI limit', 'Free: 3 per day', 'settings'], ['Yesterday', 'Ngozi Eze', 'Granted Premium (30 days)', 'tolu.adeyemi@…', 'money'],
    ['Yesterday', 'Musa Bello', 'Created challenge', 'Weekly Challenge #44', 'content'], ['24 Oct', 'Ada Okoye', 'Turned OFF flag', 'paid_events_in_play_build', 'settings']];
  P.audit = () => `
    ${head('Audit log', 'Every admin action, who did it and when. Kept for 2 years.', `<button class="btn btn-outline btn-sm" data-toast="Export started">${I('download-simple')} Export CSV</button>`)}
    <div class="tabs-line">${['All', 'Content', 'Money', 'Security', 'Settings'].map((t, i) => `<button class="${i ? '' : 'on'}" data-at="${t.toLowerCase()}">${t}</button>`).join('')}</div>
    <section class="card" style="overflow:hidden"><table class="tbl hover"><thead><tr><th>When</th><th>Admin</th><th>Action</th><th>Target</th><th>Area</th></tr></thead><tbody>
      ${AUDIT.map((a, i) => `<tr class="click" data-au="${i}" data-area="${a[4]}"><td class="muted">${a[0]}</td><td><b>${a[1]}</b></td><td>${a[2]}</td><td>${a[3]}</td><td>${pill(a[4], { content: 'info', money: 'gold', security: 'error', settings: 'neutral' }[a[4]])}</td></tr>`).join('')}
    </tbody></table></section>`;
  P.audit.mount = el => {
    el.querySelectorAll('[data-at]').forEach(b => b.onclick = () => { el.querySelectorAll('[data-at]').forEach(x => x.classList.toggle('on', x === b)); el.querySelectorAll('[data-au]').forEach(tr => tr.classList.toggle('hidden', b.dataset.at !== 'all' && tr.dataset.area !== b.dataset.at)); });
    el.querySelectorAll('[data-au]').forEach(tr => tr.onclick = () => { const a = AUDIT[+tr.dataset.au]; ADMIN.drawer(`<h2 class="t-h2">${a[2]}</h2><p class="muted mt2">${a[1]} · ${a[0]} · IP 102.89.••.14</p><h3 class="t-label mt5">Change</h3><pre class="diff"><span class="rm">- before: ${a[2].includes('AI') ? 'Free: 5 per day' : '…'}</span>\n<span class="add">+ after: ${esc(a[3])}</span></pre>`); });
  };

  // ---------- Start ----------
  ST.tokensReady.then(() => { addEventListener('hashchange', render); render(); });
})();
