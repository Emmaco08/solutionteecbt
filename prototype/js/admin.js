/* Admin CMS prototype screens (desktop width). */
(function () {
  const I = (n, f) => `<i class="${f ? 'ph-fill' : 'ph'} ph-${n}" aria-hidden="true"></i>`;
  const esc = s => String(s).replace(/[&<>"]/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));
  const naira = n => '₦' + Number(n).toLocaleString('en-NG');
  const math = el => window.renderMathInElement && renderMathInElement(el, { delimiters: [{ left: '$$', right: '$$', display: true }, { left: '$', right: '$', display: false }], throwOnError: false, ignoredClasses: ['no-math'] });
  /** Strict render used for validation: returns {ok, html} */
  const texCheck = src => {
    const parts = []; let ok = true;
    src.split(/(\$\$[^$]+\$\$|\$[^$]+\$)/g).forEach(p => {
      const m = p.match(/^\$\$([^$]+)\$\$$/) || p.match(/^\$([^$]+)\$$/);
      if (!m) { parts.push(esc(p)); return; }
      try { parts.push(katex.renderToString(m[1], { throwOnError: true, displayMode: p.startsWith('$$') })); }
      catch (e) { ok = false; parts.push(`<code class="math-fallback" style="color:var(--c-error)">${esc(p)}</code>`); }
    });
    if ((src.match(/\$/g) || []).length % 2) ok = false;
    return { ok, html: parts.join('') };
  };
  const toast = msg => { const t = document.createElement('div'); t.className = 'toast'; t.style.cssText = 'position:fixed;left:auto;right:24px;bottom:24px;width:360px'; t.innerHTML = `${I('check-circle', 1)}<span>${msg}</span>`; document.getElementById('overlay').appendChild(t); setTimeout(() => t.remove(), 2400); };

  const P = {};

  // ---------- Dashboard ----------
  P.dashboard = () => {
    const days = [142, 168, 155, 201, 238, 219, 264, 251, 289, 312, 297, 344, 361, 398];
    const W = 640, H = 200, bw = 30, gap = (W - 30 - days.length * bw) / (days.length - 1), max = 420;
    const bars = days.map((v, i) => { const h = v / max * (H - 30); return `<rect class="bar-r ${i === days.length - 1 ? 'hi' : ''}" x="${30 + i * (bw + gap)}" y="${H - 20 - h}" width="${bw}" height="${h}" rx="6" style="animation-delay:${i * 30}ms"/>`; }).join('');
    return `
    <div class="page-head"><div><h1 class="t-h1">Dashboard</h1><p class="muted mt2">Last 14 days · sample data</p></div>
      <div class="seg" style="width:280px"><button>7 days</button><button class="on">14 days</button><button>30 days</button></div></div>
    <div class="kpi-grid">
      ${[['Total students', '18,452', '+6.1%', 1, 'users-three'], ['New sign-ups', '3,404', '+12.4%', 1, 'user-plus'], ['Premium students', '1,287', '+3.2%', 1, 'crown-simple'], ['Revenue', naira(3912500), '-1.8%', 0, 'currency-ngn'],
         ['Tests taken', '41,068', '+9.7%', 1, 'exam'], ['AI prompts used', '57,331', '+21.0%', 1, 'sparkle'], ['Avg JAMB score', '231', '+4', 1, 'chart-line-up'], ['Active today', '2,918', '+2.3%', 1, 'pulse']].map(([l, v, d, up, ic]) => `
        <div class="card kpi-tile"><div class="row between"><span class="t-sm muted bold">${l}</span><span class="ic navy" style="width:32px;height:32px;border-radius:9px;display:grid;place-items:center;font-size:16px">${I(ic, 1)}</span></div><b>${v}</b><span class="delta ${up ? 'up' : 'down'}">${up ? '▲' : '▼'} ${d.replace(/^[+-]/, '')} vs previous</span></div>`).join('')}
    </div>
    <div class="two">
      <section class="card card-pad adm-chart"><div class="row between" style="margin-bottom:12px"><h2 class="t-h3">Daily sign-ups</h2><span class="t-cap muted">Gold = today</span></div>
        <svg viewBox="0 0 ${W} ${H}" role="img" aria-label="Daily sign-ups rising from 142 to 398">${[100, 200, 300, 400].map(v => { const y = H - 20 - v / max * (H - 30); return `<line class="gridline" x1="30" x2="${W}" y1="${y}" y2="${y}"/><text class="axis" x="0" y="${y + 4}">${v}</text>`; }).join('')}${bars}</svg></section>
      <section class="card card-pad stack g4"><h2 class="t-h3">Top subjects</h2>
        ${[['Use of English', 92], ['Mathematics', 81], ['Biology', 64], ['Chemistry', 58], ['Physics', 51]].map(([s, v]) => `<div class="stack g2"><div class="row between t-sm"><b>${s}</b><span class="muted tnum">${(v * 112).toLocaleString()} tests</span></div><div class="bar"><i style="width:${v}%"></i></div></div>`).join('')}</section>
    </div>
    <section class="card mt4" style="margin-top:16px"><div class="row between card-pad"><h2 class="t-h3">Recent admin actions</h2><a class="btn btn-ghost btn-sm" href="#">Open audit log</a></div>
      <table class="tbl"><thead><tr><th>When</th><th>Admin</th><th>Action</th><th>Target</th></tr></thead><tbody>
        ${[['10:02', 'Ada Okoye', 'Published year', 'JAMB 2026 Physics'], ['09:41', 'Musa Bello', 'Imported CSV (212 rows)', 'JAMB 2025 Chemistry'], ['Yesterday', 'Ada Okoye', 'Changed AI limit', 'Free: 3 per day'], ['Yesterday', 'Ngozi Eze', 'Granted Premium (30 days)', 'tolu.adeyemi@…']].map(r => `<tr>${r.map(c => `<td>${c}</td>`).join('')}</tr>`).join('')}
      </tbody></table></section>`;
  };

  // ---------- Question editor ----------
  P.editor = () => `
    <div class="page-head"><div><span class="t-sm muted">Questions / JAMB / Mathematics / 2001</span><h1 class="t-h1 mt2">Edit question</h1></div>
      <div class="row g2"><button class="btn btn-outline">${I('copy')} Duplicate</button><button class="btn btn-outline">Save draft</button><button class="btn btn-primary" id="pub">${I('check')} Publish</button></div></div>
    <div class="editor-grid">
      <div class="stack g5">
        <section class="card card-pad stack g4">
          <div class="grid3" style="grid-template-columns:repeat(4,1fr)">
            ${[['Exam', ['JAMB', 'WAEC', 'NECO']], ['Subject', ['Mathematics', 'Physics']], ['Year', ['2001', '2002']], ['Difficulty', ['Medium', 'Easy', 'Hard']]].map(([l, o]) => `<div class="field"><label>${l}</label><div class="input"><select>${o.map(x => `<option>${x}</option>`).join('')}</select><i class="ph ph-caret-down sel-caret"></i></div></div>`).join('')}
          </div>
          <div class="grid2"><div class="field"><label>Topic</label><div class="input"><select><option>Integration</option><option>Indices & logarithms</option></select><i class="ph ph-caret-down sel-caret"></i></div></div>
            <div class="field"><label>Comprehension passage</label><div class="input"><select><option>None</option><option>Passage 3: Mama Ronke's stall</option></select><i class="ph ph-caret-down sel-caret"></i></div></div></div>
          <div class="field"><label>Question</label><div class="rich"><div class="toolbar">${['text-b', 'text-italic', 'list-bullets', 'table', 'image', 'function', 'sigma'].map(i => `<button aria-label="${i}">${I(i)}</button>`).join('')}</div>
            <textarea id="qText">Evaluate $$\\int_0^2 (3x^2 + 1)\\,dx$$</textarea></div>
            <span class="help no-math">Use $...$ for inline maths and $$...$$ for display maths. Preview updates as you type.</span></div>
        </section>
        <section class="card card-pad stack g3"><div class="row between"><b>Options</b><span class="t-cap muted">Click the circle to mark the correct answer</span></div>
          ${['$8$', '$10$', '$12$', '$14$', ''].map((o, k) => `<div class="opt-edit ${k === 1 ? 'correct' : ''}" data-k="${k}"><button class="k" aria-label="Mark ${'ABCDE'[k]} correct">${'ABCDE'[k]}</button><div class="input"><input class="optIn" value="${esc(o)}" placeholder="${k === 4 ? 'Option E (optional)' : ''}"></div><button class="icon-btn" aria-label="Remove">${I('trash')}</button></div>`).join('')}
        </section>
        <section class="card card-pad stack g3"><b>Explanation</b>
          <div class="rich"><textarea id="eText">Integrate each term: $$\\Big[x^3 + x\\Big]_0^2 = 10$$ A common trap is forgetting $\\int 1\\,dx = x$.</textarea></div>
          <div class="field"><label>Image (optional)</label><div class="drop" style="padding:16px">${I('image')}<span class="t-sm muted grow">Drop a WebP or PNG, max 300 KB. It is compressed automatically.</span><button class="btn btn-outline btn-sm">Upload</button></div></div>
        </section>
      </div>
      <aside class="preview stack g3">
        <div class="row between"><b>Live preview</b><span class="badge badge-soft">As students see it</span></div>
        <div class="card card-pad stack g4" id="pv" style="border-radius:24px"></div>
        <div class="banner ok" id="texState">${I('check-circle', 1)}<span>All maths renders correctly.</span></div>
      </aside>
    </div>`;
  P.editor.mount = el => {
    const q = el.querySelector('#qText'), e = el.querySelector('#eText'), pv = el.querySelector('#pv'), st = el.querySelector('#texState');
    const draw = () => {
      const opts = [...el.querySelectorAll('.opt-edit')];
      const qc = texCheck(q.value), ec = texCheck(e.value), oc = opts.map(o => texCheck(o.querySelector('input').value));
      const ok = qc.ok && ec.ok && oc.every(x => x.ok);
      pv.innerHTML = `<div class="row g2"><span class="badge badge-soft">Integration</span><span class="badge badge-neutral">Medium</span></div>
        <div style="font-size:17px;line-height:27px">${qc.html}</div>
        <div class="stack g2">${opts.filter(o => o.querySelector('input').value).map((o, i) => `<div class="opt ${o.classList.contains('correct') ? 'right' : ''}" style="min-height:48px"><span class="key">${'ABCDE'[+o.dataset.k]}</span><span>${oc[+o.dataset.k].html}</span></div>`).join('')}</div>
        <div class="explain"><b>Explanation</b><div class="mt2">${ec.html}</div></div>`;
      st.className = 'banner ' + (ok ? 'ok' : 'err');
      st.innerHTML = ok ? `${I('check-circle', 1)}<span>All maths renders correctly.</span>` : `${I('warning-circle', 1)}<span>Some maths cannot render. Fix the red part before publishing.</span>`;
      el.querySelector('#pub').disabled = !ok;
    };
    el.addEventListener('input', draw);
    el.querySelectorAll('.opt-edit .k').forEach(b => b.onclick = () => { el.querySelectorAll('.opt-edit').forEach(o => o.classList.toggle('correct', o === b.parentNode)); draw(); });
    el.querySelector('#pub').onclick = () => toast('Published. Students see it on their next sync.');
    draw();
  };

  // ---------- CSV import ----------
  const ROWS = [
    { exam: 'JAMB', year: 2025, subject: 'Chemistry', q: 'What is the oxidation number of Mn in $\\text{KMnO}_4$?', o: ['$+2$', '$+4$', '$+6$', '$+7$'], ans: 'D', topic: 'Redox' },
    { exam: 'JAMB', year: 2025, subject: 'Chemistry', q: 'Calculate the mass of $0.5\\,\\text{mol}$ of $\\text{NaCl}$. $(\\text{Na}=23, \\text{Cl}=35.5)$', o: ['$29.25\\,\\text{g}$', '$58.5\\,\\text{g}$', '$117\\,\\text{g}$', '$11.7\\,\\text{g}$'], ans: 'A', topic: 'Mole concept' },
    { exam: 'JAMB', year: 2025, subject: 'Chemistry', q: 'The rate constant $k$ has units of $\\text{s}^{-1$ for a first-order reaction.', o: ['True', 'False', '', ''], ans: 'A', topic: 'Kinetics', err: { q: 'LaTeX error: missing } in $\\text{s}^{-1$' } },
    { exam: 'JAMB', year: 2025, subject: 'Chemistry', q: 'Which gas turns lime water milky?', o: ['$\\text{O}_2$', '$\\text{CO}_2$', '$\\text{N}_2$', '$\\text{H}_2$'], ans: 'F', topic: 'Gases', err: { ans: 'Answer must be A, B, C, D or E' } },
    { exam: 'JAMB', year: 2025, subject: 'Chemestry', q: 'An element with atomic number 11 belongs to group', o: ['1', '2', '7', '0'], ans: 'A', topic: 'Periodic table', err: { subject: 'Unknown subject "Chemestry". Did you mean Chemistry?' } },
    { exam: 'JAMB', year: 2025, subject: 'Chemistry', q: 'Calculate the mass of $0.5\\,\\text{mol}$ of $\\text{NaCl}$. $(\\text{Na}=23, \\text{Cl}=35.5)$', o: ['$29.25\\,\\text{g}$', '$58.5\\,\\text{g}$', '$117\\,\\text{g}$', '$11.7\\,\\text{g}$'], ans: 'A', topic: 'Mole concept', warn: 'Possible duplicate of row 2' },
    { exam: 'JAMB', year: 2025, subject: 'Chemistry', q: 'The pH of $0.01\\,\\text{mol dm}^{-3}$ HCl is', o: ['$1$', '$2$', '$12$', '$13$'], ans: 'B', topic: 'Acids and bases' }
  ];
  P.csv = () => {
    const errs = ROWS.filter(r => r.err).length, warns = ROWS.filter(r => r.warn).length;
    return `
    <div class="page-head"><div><span class="t-sm muted">Questions / Import</span><h1 class="t-h1 mt2">CSV bulk import</h1></div>
      <div class="row g2"><button class="btn btn-outline">${I('download-simple')} Download template</button><button class="btn btn-outline">${I('clock-counter-clockwise')} Import history</button></div></div>
    <div class="stepper"><div class="done"><span>${I('check', 1)}</span>Upload</div><div class="done"><span>${I('check', 1)}</span>Map columns</div><div class="on"><span>3</span>Validate</div><div><span>4</span>Commit</div></div>
    <div class="drop" style="margin-bottom:16px">${I('file-csv', 1).replace('class="', 'style="font-size:36px;color:var(--c-success)" class="')}<div class="grow"><b>jamb-2025-chemistry.csv</b><div class="t-sm muted">UTF-8 · 212 rows · 15 columns mapped · uploaded 2 minutes ago</div></div><button class="btn btn-ghost btn-sm">Replace file</button></div>
    <div class="row g3 wrap" style="margin-bottom:16px">
      <span class="badge badge-success" style="height:32px;padding:0 12px;font-size:13px">${I('check-circle', 1)} 205 ready</span>
      <span class="badge badge-error" style="height:32px;padding:0 12px;font-size:13px">${I('x-circle', 1)} ${errs} errors</span>
      <span class="badge badge-warning" style="height:32px;padding:0 12px;font-size:13px">${I('warning', 1)} ${warns} warning</span>
      <span class="grow"></span>
      <div class="seg" style="width:300px"><button class="on">All rows</button><button>Errors only</button><button>Warnings</button></div>
    </div>
    <div class="tbl-wrap"><table class="tbl"><thead><tr><th>Row</th><th>Subject</th><th>Question (LaTeX preview)</th><th>Options</th><th>Answer</th><th>Topic</th><th>Status</th></tr></thead><tbody>
      ${ROWS.map((r, i) => {
        const qc = texCheck(r.q);
        const status = r.err ? `<span class="cell-err">${Object.values(r.err)[0]}</span>` : r.warn ? `<span style="color:var(--c-on-warning-soft);font-weight:700">${r.warn}</span>` : `<span class="up bold">${I('check-circle', 1)} OK</span>`;
        return `<tr class="${r.err ? 'bad' : r.warn ? 'warn' : ''}"><td class="tnum bold">${i + 2}</td>
          <td class="${r.err?.subject ? 'cell-err' : ''}">${esc(r.subject)}</td>
          <td style="max-width:340px;font-size:14px;line-height:21px">${qc.html}</td>
          <td style="font-size:13px">${r.o.filter(Boolean).map((o, k) => `<div><b>${'ABCDE'[k]}.</b> ${texCheck(o).html}</div>`).join('')}</td>
          <td class="${r.err?.ans ? 'cell-err' : 'bold'}">${r.ans}</td><td>${r.topic}</td><td style="max-width:220px">${status}</td></tr>`;
      }).join('')}
      <tr><td colspan="7" class="muted t-sm" style="text-align:center;padding:14px">205 more valid rows not shown</td></tr>
    </tbody></table></div>
    <div class="card card-pad row g4 wrap" style="margin-top:16px">
      <div class="grow"><b>Dry run result</b><p class="t-sm muted">Commit will add <b>205</b> questions to JAMB 2025 Chemistry as <b>drafts</b>. Rows with errors are skipped. You can undo this import for 7 days.</p></div>
      <button class="btn btn-outline" id="dry">${I('play')} Run dry run again</button>
      <button class="btn btn-primary" id="commit">Commit 205 rows</button>
    </div>`;
  };
  P.csv.mount = el => {
    el.querySelector('#dry').onclick = e => { const b = e.currentTarget; b.classList.add('is-loading'); setTimeout(() => { b.classList.remove('is-loading'); toast('Dry run finished: 205 valid, 3 errors, 1 warning.'); }, 900); };
    el.querySelector('#commit').onclick = () => { el.querySelectorAll('.stepper div')[2].className = 'done'; el.querySelectorAll('.stepper div')[3].className = 'on'; toast('Imported 205 questions as drafts. Undo available in Import history.'); };
  };

  // ---------- Tabs manager ----------
  const TABS = [
    { key: 'home', title: 'Home', icon: 'house', type: 'home', on: 1 }, { key: 'study', title: 'Study', icon: 'book-open-text', type: 'study', on: 1 },
    { key: 'test', title: 'Test', icon: 'exam', type: 'test', on: 1 }, { key: 'ai', title: 'AI Tutor', icon: 'sparkle', type: 'ai_chat', on: 1 },
    { key: 'profile', title: 'Me', icon: 'user-circle', type: 'profile', on: 1 }, { key: 'classes', title: 'Classes', icon: 'video-camera', type: 'webview', on: 1, prem: 1 },
    { key: 'news', title: 'News', icon: 'newspaper', type: 'content_list', on: 0 }
  ];
  P.tabs = () => `
    <div class="page-head"><div><span class="t-sm muted">App control</span><h1 class="t-h1 mt2">Tabs manager</h1><p class="muted mt2">Drag to reorder. The first 5 enabled tabs show in the bar; the rest go into "More". Changes reach phones on next launch.</p></div>
      <div class="row g2"><button class="btn btn-outline">${I('plus')} Add tab</button><button class="btn btn-primary" id="saveTabs">Save changes</button></div></div>
    <div class="two" style="grid-template-columns:1fr 340px;margin-top:0">
      <section class="card" style="overflow:hidden"><div class="tab-row t-cap muted bold" style="background:var(--c-surface-alt)"><span></span><span>Icon</span><span>Title</span><span>Type</span><span>Premium only</span><span>Enabled</span><span></span></div>
        <div id="tabList"></div></section>
      <aside class="stack g3"><b>Phone preview</b><div class="mini-phone"><div class="body"><div class="sk" style="height:18px;width:60%"></div><div class="sk mt3" style="height:70px;border-radius:12px"></div><div class="sk mt3" style="height:40px;border-radius:12px"></div></div><div class="mini-nav" id="miniNav"></div></div>
        <div class="banner info">${I('info', 1)}<span>Min app version for new tab types: <b>1.0.0</b></span></div></aside>
    </div>`;
  P.tabs.mount = el => {
    const list = el.querySelector('#tabList'), nav = el.querySelector('#miniNav');
    const draw = () => {
      list.innerHTML = TABS.map((t, i) => `<div class="tab-row ${t.on ? '' : 'off'}" draggable="true" data-i="${i}"><span class="handle">${I('dots-six-vertical')}</span><span class="tic">${I(t.icon, 1)}</span>
        <div class="input" style="min-height:40px"><input value="${t.title}" style="min-height:40px" data-title="${i}"></div><span class="badge badge-neutral" style="justify-self:start">${t.type}</span>
        <span class="switch"><input type="checkbox" ${t.prem ? 'checked' : ''} data-prem="${i}"><span></span></span><span class="switch"><input type="checkbox" ${t.on ? 'checked' : ''} data-on="${i}"><span></span></span>
        <button class="icon-btn" aria-label="More">${I('dots-three')}</button></div>`).join('');
      const vis = TABS.filter(t => t.on), shown = vis.length > 5 ? [...vis.slice(0, 4), { title: 'More', icon: 'dots-three-circle' }] : vis;
      nav.style.gridTemplateColumns = `repeat(${shown.length},1fr)`;
      nav.innerHTML = shown.map(t => `<span>${I(t.icon, 1)}${t.title}</span>`).join('');
      let from = null;
      list.querySelectorAll('.tab-row').forEach(r => {
        r.addEventListener('dragstart', () => { from = +r.dataset.i; r.classList.add('dragging'); });
        r.addEventListener('dragend', () => r.classList.remove('dragging'));
        r.addEventListener('dragover', e => { e.preventDefault(); r.classList.add('over'); });
        r.addEventListener('dragleave', () => r.classList.remove('over'));
        r.addEventListener('drop', e => { e.preventDefault(); const to = +r.dataset.i; const [m] = TABS.splice(from, 1); TABS.splice(to, 0, m); draw(); });
      });
      list.querySelectorAll('[data-on]').forEach(c => c.onchange = () => { TABS[+c.dataset.on].on = c.checked ? 1 : 0; draw(); });
      list.querySelectorAll('[data-title]').forEach(c => c.oninput = () => { TABS[+c.dataset.title].title = c.value; const vis = TABS.filter(t => t.on); nav.querySelectorAll('span').forEach((s, k) => { if (vis[k] && !(vis.length > 5 && k === 4)) s.lastChild.textContent = vis[k].title; }); });
    };
    draw();
    el.querySelector('#saveTabs').onclick = () => toast('Tabs saved. Logged in audit log.');
  };

  // ---------- Plans & limits ----------
  P.plans = () => `
    <div class="page-head"><div><span class="t-sm muted">App control</span><h1 class="t-h1 mt2">Plans & limits</h1><p class="muted mt2">Everything here is enforced on the server. Nothing is hardcoded in the app.</p></div>
      <button class="btn btn-primary" id="savePl">Save changes</button></div>
    <section class="card" style="overflow:hidden">
      <div class="row between card-pad"><div class="row g3"><h2 class="t-h3">Plans</h2><span class="badge badge-sample">SAMPLE PRICES</span></div><button class="btn btn-outline btn-sm">${I('plus')} Add plan</button></div>
      <table class="tbl"><thead><tr><th>Plan</th><th>Price (Paystack)</th><th>Duration</th><th>Google Play product ID</th><th>Active</th></tr></thead><tbody>
        ${[['Monthly', 1500, '30 days', 'premium_monthly'], ['3 Months', 3500, '90 days', 'premium_quarter'], ['Exam Season', 6000, 'Until 31 Jul 2027', 'premium_season_2027']].map(([n, p, d, id]) => `
          <tr><td class="bold" style="vertical-align:middle">${n}</td><td><div class="input" style="min-height:40px;width:140px"><span class="lead-ic" style="font-weight:700">₦</span><input value="${p.toLocaleString()}" style="min-height:40px"></div></td>
          <td style="vertical-align:middle">${d}</td><td><div class="input" style="min-height:40px"><input value="${id}" style="min-height:40px;font-family:var(--font-mono);font-size:13px"></div></td>
          <td style="vertical-align:middle"><span class="switch"><input type="checkbox" checked><span></span></span></td></tr>`).join('')}
      </tbody></table>
      <div class="card-pad"><div class="banner warn">${I('warning', 1)}<span><b>Reminder:</b> when you change a price here, also update it in Google Play Console for the matching product ID. Play Store users see the Play price.</span></div></div>
    </section>
    <div class="two" style="grid-template-columns:1fr 1fr">
      <section class="card card-pad stack g4"><h2 class="t-h3">Free access rules</h2>
        <p class="t-sm muted">Years, study features, syllabuses and AI limits for Free and Premium are now set on one page.</p>
        <a class="btn btn-tonal" href="#access">${I('sliders-horizontal')} Open Free vs Premium</a>
      </section>
      <section class="card card-pad stack g4"><h2 class="t-h3">AI tutor</h2>
        <div class="grid2"><div class="field"><label>Free prompts per day</label><div class="input num-input"><input type="number" value="3"></div></div>
          <div class="field"><label>Premium prompts per day</label><div class="input num-input"><input type="number" value="100"></div></div></div>
        <div class="field"><label>Daily reset</label><div class="input"><input value="00:00 · Africa/Lagos" readonly></div></div>
        <div class="field"><label>Model ID (NVIDIA NIM)</label><div class="input"><input value="" placeholder="Paste the model id from build.nvidia.com" style="font-family:var(--font-mono);font-size:13px"></div><span class="help">Fallback models are tried in order if this one is busy.</span></div>
        <label class="row between t-sm bold"><span>Allow photo questions (students attach an image)</span><span class="switch"><input type="checkbox" checked><span></span></span></label>
        <div class="field"><label>Vision model ID (reads photos)</label><div class="input"><input value="" placeholder="A vision-capable model id from build.nvidia.com" style="font-family:var(--font-mono);font-size:13px"></div><span class="help">Photo questions need a model that accepts images. Leave empty to turn photo questions off.</span></div>
        <div class="grid2"><div class="field"><label>Max photo size after shrinking</label><div class="input"><input type="number" value="300"><span class="t-sm muted" style="padding-right:12px">KB</span></div></div>
          <div class="field"><label>Delete photos after</label><div class="input"><input type="number" value="30"><span class="t-sm muted" style="padding-right:12px">days</span></div></div></div>
        <div class="grid2"><div class="field"><label>Temperature</label><div class="input"><input type="number" step="0.1" value="0.3"></div></div><div class="field"><label>Max tokens</label><div class="input"><input type="number" value="900"></div></div></div>
        <div class="field"><div class="row between"><label>System prompt</label><span class="badge badge-neutral">v1 · draft</span></div><div class="rich"><textarea style="min-height:130px">You are SolutionTee AI, a patient Nigerian secondary-school teacher. Explain step by step, aligned to the JAMB, WAEC and NECO syllabuses. Write all maths in LaTeX using $...$. Use simple English and Nigerian examples. Never invent which exam year a question came from...</textarea></div></div>
      </section>
    </div>`;
  P.plans.mount = el => {
    el.querySelectorAll('.chip').forEach(c => c.onclick = () => c.classList.toggle('on'));
    el.querySelectorAll('.seg button').forEach(b => b.onclick = () => b.parentNode.querySelectorAll('button').forEach(x => x.classList.toggle('on', x === b)));
    el.querySelector('#savePl').onclick = () => toast('Saved. Limits apply immediately. Logged in audit log.');
  };

  // ---------- Redeem codes ----------
  const PLAN_NAMES = { m: 'Monthly', q: '3 Months', e: 'Exam Season' };
  const PLAN_PRICES = { m: 1500, q: 3500, e: 6000 };
  const CODE_ALPHABET = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';   // no 0/O, 1/I/L: easy to read out and type
  const randBlock = n => { const a = new Uint32Array(n); crypto.getRandomValues(a); return [...a].map(x => CODE_ALPHABET[x % CODE_ALPHABET.length]).join(''); };
  const CODE_ROWS = [
    { code: 'LOYOLA20', type: 'pct', value: 20, plans: ['m', 'q', 'e'], used: 128, max: 300, ends: '2026-12-31', status: 'active', note: 'Loyola College partnership', by: 'Ada Okoye' },
    { code: 'WELCOME500', type: 'amt', value: 500, plans: ['q', 'e'], used: 412, max: null, ends: '2027-03-31', status: 'active', note: 'New-student offer', by: 'Ada Okoye', newOnly: true },
    { code: 'EXAM25', type: 'pct', value: 25, plans: ['e'], used: 57, max: 500, ends: '2027-07-31', status: 'active', note: 'Exam season push', by: 'Musa Bello' },
    { code: 'FREEWEEK', type: 'days', value: 7, plans: [], used: 89, max: 200, ends: '2026-11-30', status: 'active', note: 'Teacher giveaway', by: 'Ngozi Eze' },
    { code: 'STEE-····-····', batch: 50, type: 'pct', value: 30, plans: ['m', 'q', 'e'], used: 31, max: 50, ends: '2026-12-15', status: 'active', note: 'Unique codes for class reps', by: 'Ada Okoye' },
    { code: 'EXPIRED10', type: 'pct', value: 10, plans: ['m', 'q', 'e'], used: 240, max: 250, ends: '2026-09-30', status: 'expired', note: 'Back-to-school', by: 'Musa Bello' }
  ];
  const valueText = r => r.type === 'pct' ? `${r.value}% off` : r.type === 'amt' ? `${naira(r.value)} off` : `${r.value} free Premium days`;
  const fmtDate = d => d ? new Date(d + 'T00:00:00').toLocaleDateString('en-GB', { day: 'numeric', month: 'short', year: 'numeric' }) : 'No end date';
  const statusBadge = s => ({ active: '<span class="badge badge-success">Active</span>', paused: '<span class="badge badge-warning">Paused</span>', expired: '<span class="badge badge-neutral">Expired</span>' }[s]);

  P.codes = () => `
    <div class="page-head"><div><span class="t-sm muted">People & money</span><h1 class="t-h1 mt2">Redeem codes</h1><p class="muted mt2">Give students a discount or free Premium days. Every code is checked on the server when it is used.</p></div>
      <span class="badge badge-sample">SAMPLE DATA</span></div>
    <div class="kpi-grid">
      ${[['Active codes', '5', 'ticket'], ['Used this month', '438', 'check-circle'], ['Discount given', naira(184500), 'currency-ngn'], ['Paid by code users', naira(1262000), 'trend-up']].map(([l, v, ic]) => `
        <div class="card kpi-tile"><div class="row between"><span class="t-sm muted bold">${l}</span><span class="ic navy" style="width:32px;height:32px;border-radius:9px;display:grid;place-items:center;font-size:16px">${I(ic, 1)}</span></div><b>${v}</b></div>`).join('')}
    </div>
    <div class="banner info" style="margin-top:16px">${I('google-play-logo', 1)}<span><b>Where codes work:</b> discount codes apply to Paystack payments (website and direct APK). In the Play Store app, Google only allows Google Play promo codes for discounts; create those in Play Console. Free-day codes are redeemed in the app under Me, then Redeem a code.</span></div>

    <div class="two" style="grid-template-columns:1.25fr 1fr">
      <section class="card card-pad stack g4" id="gen">
        <h2 class="t-h3">Create codes</h2>
        <div class="field"><label>The code gives</label><div class="seg" id="gType"><button class="on" data-t="pct">% off</button><button data-t="amt">₦ off</button><button data-t="days">Free Premium days</button></div></div>
        <div class="grid2">
          <div class="field" id="fVal"><label for="gVal" id="gValLabel">Percentage off</label><div class="input"><span class="lead-ic bold" id="gPre" style="display:none">₦</span><input id="gVal" type="number" min="1" value="20"><span class="t-sm muted" id="gSuf" style="padding-right:12px">%</span></div></div>
          <div class="field" id="fPlans"><label>Works on plans</label><div class="row g2 wrap" id="gPlans">${Object.entries(PLAN_NAMES).map(([id, n]) => `<button class="chip on" data-plan="${id}">${n}</button>`).join('')}</div></div>
        </div>
        <div class="field"><label>Code style</label><div class="seg" id="gStyle"><button class="on" data-s="shared">One shared code</button><button data-s="unique">Unique codes (one per student)</button></div>
          <span class="help" id="gStyleHelp">One code many students can use, e.g. for a school or a WhatsApp group.</span></div>
        <div class="grid2" id="sharedBox">
          <div class="field" id="fCode"><label for="gCode">Code</label><div class="row g2"><div class="input grow"><input id="gCode" class="code-input" value="ADEOLA15" maxlength="20" autocomplete="off"></div><button class="btn btn-outline" id="gRand" title="Random code">${I('shuffle')}</button></div>
            <span class="help">Letters and numbers only, 4 to 20 characters. Not case sensitive.</span></div>
          <div class="field"><label for="gMax">Total uses allowed</label><div class="input"><input id="gMax" type="number" min="1" placeholder="No limit" value="200"></div><span class="help">Leave empty for no limit.</span></div>
        </div>
        <div class="grid2 hidden" id="uniqueBox">
          <div class="field"><label for="gPrefix">Prefix</label><div class="input"><input id="gPrefix" class="code-input" value="STEE" maxlength="8"></div><span class="help">Codes look like <span class="code-input" id="gSample">STEE-7K3P-Q9XD</span></span></div>
          <div class="field" id="fCount"><label for="gCount">How many codes</label><div class="input"><input id="gCount" type="number" min="1" max="1000" value="50"></div><span class="help">Up to 1,000 at a time. Each works once.</span></div>
        </div>
        <div class="grid2">
          <div class="field"><label for="gFrom">Starts</label><div class="input"><input id="gFrom" type="date" value="2026-10-25"></div></div>
          <div class="field" id="fEnd"><label for="gEnd">Ends</label><div class="input"><input id="gEnd" type="date" value="2026-12-31"></div></div>
        </div>
        <div class="stack g3">
          <label class="row between t-sm bold"><span>One use per student</span><span class="switch"><input type="checkbox" id="gOnce" checked><span></span></span></label>
          <label class="row between t-sm bold"><span>New students only (first payment)</span><span class="switch"><input type="checkbox" id="gNew"><span></span></span></label>
        </div>
        <div class="field"><label for="gNote">Internal note (students do not see this)</label><div class="input"><input id="gNote" placeholder="e.g. Adeola High School, SS3 class" value=""></div></div>
        <div class="row g3"><button class="btn btn-primary" id="gGo">${I('ticket', 1)} Create code</button><span class="t-cap muted">Logged in the audit log.</span></div>
      </section>

      <aside class="stack g4">
        <section class="card card-pad stack g3"><div class="row between"><b>Student sees at checkout</b><span class="badge badge-soft">Preview</span></div>
          <div id="gPreview"></div></section>
        <section class="card card-pad stack g3 hidden" id="gResult"></section>
      </aside>
    </div>

    <section class="card" style="margin-top:16px;overflow:hidden">
      <div class="row between card-pad wrap g3"><h2 class="t-h3">All codes</h2>
        <div class="row g3 wrap"><div class="input" style="min-height:40px;width:220px"><i class="ph ph-magnifying-glass lead-ic"></i><input id="cSearch" placeholder="Search code or note" style="min-height:40px"></div>
          <div class="seg" id="cFilter" style="width:300px"><button class="on" data-f="all">All</button><button data-f="active">Active</button><button data-f="paused">Paused</button><button data-f="expired">Expired</button></div>
          <button class="btn btn-outline btn-sm" id="cCsv">${I('download-simple')} Export CSV</button></div></div>
      <div style="overflow:auto"><table class="tbl"><thead><tr><th>Code</th><th>Gives</th><th>Plans</th><th style="width:170px">Used</th><th>Ends</th><th>Status</th><th>Note</th><th></th></tr></thead><tbody id="cRows"></tbody></table></div>
    </section>`;

  P.codes.mount = el => {
    const $ = s => el.querySelector(s);
    let type = 'pct', style = 'shared', filter = 'all';
    const plans = () => [...el.querySelectorAll('#gPlans .chip.on')].map(c => c.dataset.plan);
    const err = (fieldId, msg) => { const f = $(fieldId); f.classList.add('has-error'); f.insertAdjacentHTML('beforeend', `<span class="err">${I('warning-circle', 1)} ${msg}</span>`); };
    const clearErrs = () => el.querySelectorAll('#gen .field').forEach(f => { f.classList.remove('has-error'); f.querySelector('.err')?.remove(); });

    const preview = () => {
      const v = +$('#gVal').value || 0, ps = plans(), code = style === 'shared' ? ($('#gCode').value || 'CODE') : `${$('#gPrefix').value || 'STEE'}-7K3P-Q9XD`;
      if (type === 'days') {
        $('#gPreview').innerHTML = `<div class="code-ok" style="border-style:solid">${I('gift', 1)}<span class="grow"><b class="t-sm">${v} days of Premium added!</b><br><span class="t-cap">Redeemed with <span class="code-input">${code}</span> in Me, then Redeem a code</span></span></div>`;
        return;
      }
      const pid = ps.includes('q') ? 'q' : ps[0] || 'q', price = PLAN_PRICES[pid];
      const off = type === 'pct' ? Math.round(price * Math.min(v, 100) / 100) : Math.min(v, price);
      $('#gPreview').innerHTML = `<div class="stack g2 t-sm">
        <div class="row between"><span class="muted">SolutionTee Premium · ${PLAN_NAMES[pid]}</span><span class="tnum">${naira(price)}</span></div>
        <div class="row between" style="color:var(--c-success)"><span class="row g1">${I('ticket', 1)} <span class="code-input">${code}</span> · ${type === 'pct' ? v + '% off' : naira(v) + ' off'}</span><b class="tnum">−${naira(off)}</b></div>
        <hr class="divider"><div class="row between"><b>Total</b><b class="t-h3 tnum">${naira(price - off)}</b></div>
        ${ps.length < 3 ? `<p class="t-cap muted">Only works on: ${ps.map(id => PLAN_NAMES[id]).join(', ') || 'no plan selected'}.</p>` : ''}</div>`;
    };

    $('#gType').querySelectorAll('button').forEach(b => b.onclick = () => {
      type = b.dataset.t; $('#gType').querySelectorAll('button').forEach(x => x.classList.toggle('on', x === b));
      $('#gValLabel').textContent = { pct: 'Percentage off', amt: 'Amount off', days: 'Number of free days' }[type];
      $('#gPre').style.display = type === 'amt' ? '' : 'none';
      $('#gSuf').textContent = type === 'pct' ? '%' : type === 'days' ? 'days' : '';
      $('#gVal').value = { pct: 20, amt: 500, days: 7 }[type];
      $('#fPlans').classList.toggle('hidden', type === 'days');
      clearErrs(); preview();
    });
    $('#gStyle').querySelectorAll('button').forEach(b => b.onclick = () => {
      style = b.dataset.s; $('#gStyle').querySelectorAll('button').forEach(x => x.classList.toggle('on', x === b));
      $('#sharedBox').classList.toggle('hidden', style !== 'shared'); $('#uniqueBox').classList.toggle('hidden', style === 'shared');
      $('#gStyleHelp').textContent = style === 'shared' ? 'One code many students can use, e.g. for a school or a WhatsApp group.' : 'A list of different codes, each usable once. Good for giving one code to each student.';
      clearErrs(); preview();
    });
    el.querySelectorAll('#gPlans .chip').forEach(c => c.onclick = () => { c.classList.toggle('on'); preview(); });
    $('#gRand').onclick = () => { $('#gCode').value = randBlock(8); clearErrs(); preview(); };
    $('#gCode').oninput = () => { $('#gCode').value = $('#gCode').value.toUpperCase().replace(/[^A-Z0-9]/g, ''); clearErrs(); preview(); };
    $('#gPrefix').oninput = () => { $('#gPrefix').value = $('#gPrefix').value.toUpperCase().replace(/[^A-Z0-9]/g, ''); $('#gSample').textContent = `${$('#gPrefix').value || 'STEE'}-7K3P-Q9XD`; preview(); };
    $('#gVal').oninput = () => { clearErrs(); preview(); };

    const drawRows = () => {
      const q = $('#cSearch').value.trim().toUpperCase();
      const rows = CODE_ROWS.filter(r => (filter === 'all' || r.status === filter) && (!q || r.code.includes(q) || (r.note || '').toUpperCase().includes(q)));
      $('#cRows').innerHTML = rows.map(r => {
        const pct = r.max ? Math.min(100, Math.round(r.used / r.max * 100)) : 0;
        return `<tr><td><b class="code-input">${r.code}</b>${r.batch ? `<div class="t-cap muted">${r.batch} unique codes</div>` : ''}${r.newOnly ? '<div class="t-cap muted">New students only</div>' : ''}</td>
          <td>${valueText(r)}</td><td class="t-cap">${r.type === 'days' ? '<span class="muted">Not for checkout</span>' : r.plans.map(id => PLAN_NAMES[id]).join(', ')}</td>
          <td><div class="row between t-cap"><b class="tnum">${r.used.toLocaleString()}</b><span class="muted">${r.max ? 'of ' + r.max.toLocaleString() : 'no limit'}</span></div>${r.max ? `<div class="bar mt2" style="height:6px"><i style="width:${pct}%"></i></div>` : ''}</td>
          <td class="t-cap">${fmtDate(r.ends)}</td><td>${statusBadge(r.status)}</td><td class="t-cap muted" style="max-width:180px">${r.note || ''}</td>
          <td><div class="row g1"><button class="icon-btn" data-copy="${r.code}" aria-label="Copy code" ${r.batch ? 'disabled' : ''}>${I('copy')}</button>
            ${r.status === 'expired' ? '' : `<button class="icon-btn" data-toggle="${r.code}" aria-label="${r.status === 'active' ? 'Pause' : 'Resume'} code" title="${r.status === 'active' ? 'Pause' : 'Resume'}">${I(r.status === 'active' ? 'pause-circle' : 'play-circle')}</button>`}</div></td></tr>`;
      }).join('') || `<tr><td colspan="8" class="muted" style="text-align:center;padding:24px">No codes match.</td></tr>`;
      el.querySelectorAll('[data-copy]').forEach(b => b.onclick = () => { navigator.clipboard?.writeText(b.dataset.copy).catch(() => {}); toast(`Copied ${b.dataset.copy}`); });
      el.querySelectorAll('[data-toggle]').forEach(b => b.onclick = () => { const r = CODE_ROWS.find(x => x.code === b.dataset.toggle); r.status = r.status === 'active' ? 'paused' : 'active'; drawRows(); toast(`${r.code} ${r.status === 'paused' ? 'paused. Students cannot use it until you resume it.' : 'is active again.'}`); });
    };
    $('#cSearch').oninput = drawRows;
    $('#cFilter').querySelectorAll('button').forEach(b => b.onclick = () => { filter = b.dataset.f; $('#cFilter').querySelectorAll('button').forEach(x => x.classList.toggle('on', x === b)); drawRows(); });

    const csv = (rows, name) => {
      const head = 'code,gives,plans,used,max_uses,ends,status,note';
      const body = rows.map(r => [r.code, valueText(r), r.type === 'days' ? '' : r.plans.map(id => PLAN_NAMES[id]).join(' / '), r.used ?? 0, r.max ?? '', r.ends || '', r.status || 'active', (r.note || '').replace(/"/g, "'")].map(x => `"${x}"`).join(','));
      const url = URL.createObjectURL(new Blob([[head, ...body].join('\n')], { type: 'text/csv' }));
      const a = document.createElement('a'); a.href = url; a.download = name; a.click(); setTimeout(() => URL.revokeObjectURL(url), 1000);
    };
    $('#cCsv').onclick = () => csv(CODE_ROWS, 'solutiontee-redeem-codes.csv');

    $('#gGo').onclick = () => {
      clearErrs();
      const v = +$('#gVal').value, ps = plans(), ends = $('#gEnd').value, from = $('#gFrom').value;
      let bad = false;
      if (type === 'pct' && !(v >= 1 && v <= 100)) { err('#fVal', 'Enter a percentage from 1 to 100.'); bad = true; }
      if (type === 'amt' && !(v >= 50)) { err('#fVal', 'Enter at least ₦50.'); bad = true; }
      if (type === 'amt' && ps.some(id => v >= PLAN_PRICES[id])) { err('#fVal', 'That is more than a selected plan costs. Use Free Premium days instead.'); bad = true; }
      if (type === 'days' && !(v >= 1 && v <= 365)) { err('#fVal', 'Enter 1 to 365 days.'); bad = true; }
      if (type !== 'days' && !ps.length) { err('#fPlans', 'Pick at least one plan.'); bad = true; }
      if (ends && from && ends < from) { err('#fEnd', 'The end date is before the start date.'); bad = true; }
      let codes = [];
      if (style === 'shared') {
        const c = $('#gCode').value;
        if (c.length < 4) { err('#fCode', 'Use at least 4 letters or numbers.'); bad = true; }
        else if (CODE_ROWS.some(r => r.code === c)) { err('#fCode', 'That code already exists. Try another.'); bad = true; }
        codes = [c];
      } else {
        const n = +$('#gCount').value;
        if (!(n >= 1 && n <= 1000)) { err('#fCount', 'Choose 1 to 1,000 codes.'); bad = true; }
        const set = new Set(); while (!bad && set.size < n) set.add(`${$('#gPrefix').value || 'STEE'}-${randBlock(4)}-${randBlock(4)}`);
        codes = [...set];
      }
      if (bad) return;
      const b = $('#gGo'); b.classList.add('is-loading'); b.textContent = '';
      setTimeout(() => {
        b.classList.remove('is-loading'); b.innerHTML = `${I('ticket', 1)} Create code`;
        const base = { type, value: v, plans: type === 'days' ? [] : ps, used: 0, ends, status: 'active', note: $('#gNote').value, by: 'Ada Okoye', newOnly: $('#gNew').checked };
        const row = style === 'shared' ? { ...base, code: codes[0], max: +$('#gMax').value || null } : { ...base, code: `${$('#gPrefix').value || 'STEE'}-····-····`, batch: codes.length, max: codes.length };
        CODE_ROWS.unshift(row); drawRows();
        const list = codes.slice(0, 8).map(c => `<div class="row between gen-code"><span class="code-input bold">${c}</span><button class="icon-btn" data-c="${c}" aria-label="Copy">${I('copy')}</button></div>`).join('');
        $('#gResult').classList.remove('hidden');
        $('#gResult').innerHTML = `<div class="row between"><b>${codes.length === 1 ? 'Code created' : codes.length + ' codes created'}</b><span class="badge badge-success">${I('check', 1)} Active</span></div>
          <p class="t-sm muted">${valueText(row)}${type === 'days' ? '' : ' on ' + ps.map(id => PLAN_NAMES[id]).join(', ')} · ends ${fmtDate(ends)}</p>
          <div class="stack">${list}</div>${codes.length > 8 ? `<p class="t-cap muted">and ${codes.length - 8} more in the CSV.</p>` : ''}
          <div class="row g2"><button class="btn btn-outline btn-sm" id="gCopyAll">${I('copy')} Copy all</button><button class="btn btn-outline btn-sm" id="gDl">${I('download-simple')} Download CSV</button></div>`;
        $('#gResult').querySelectorAll('[data-c]').forEach(x => x.onclick = () => { navigator.clipboard?.writeText(x.dataset.c).catch(() => {}); toast(`Copied ${x.dataset.c}`); });
        $('#gCopyAll').onclick = () => { navigator.clipboard?.writeText(codes.join('\n')).catch(() => {}); toast(`Copied ${codes.length} code${codes.length > 1 ? 's' : ''}`); };
        $('#gDl').onclick = () => csv(codes.map(c => ({ ...row, code: c, used: 0, max: 1 })), `codes-${codes[0].split('-')[0].toLowerCase()}.csv`);
        $('#gResult').classList.remove('pop'); void $('#gResult').offsetWidth; $('#gResult').classList.add('pop');
        toast(`${codes.length === 1 ? codes[0] + ' is' : codes.length + ' codes are'} ready. Logged in audit log.`);
        if (style === 'shared') $('#gCode').value = randBlock(8);
        preview();
      }, 700);
    };
    preview(); drawRows();
  };

  // ---------- News (post with cover image) ----------
  const NEWS_CATS = ['JAMB registration', 'New questions', 'Classes', 'Exam tips', 'WAEC', 'NECO', 'Scholarships'];
  const storeGet = (k, d) => { try { return JSON.parse(localStorage.getItem(k) || JSON.stringify(d)); } catch (e) { return d; } };
  const storeSet = (k, v) => { try { localStorage.setItem(k, JSON.stringify(v)); return true; } catch (e) { return false; } };
  /** Shrink an uploaded cover to max 1200 px wide, JPEG/WebP ~0.75, before "upload" (data-light for students). */
  const shrink = file => new Promise((res, rej) => {
    if (!/^image\//.test(file.type)) return rej(new Error('not-image'));
    const img = new Image(), url = URL.createObjectURL(file);
    img.onload = () => { const k = Math.min(1, 1200 / img.naturalWidth), c = document.createElement('canvas'); c.width = Math.round(img.naturalWidth * k); c.height = Math.round(img.naturalHeight * k);
      c.getContext('2d').drawImage(img, 0, 0, c.width, c.height); URL.revokeObjectURL(url); const d = c.toDataURL('image/jpeg', 0.75); res({ data: d, kb: Math.round(d.length * 0.75 / 1024), w: c.width, h: c.height }); };
    img.onerror = () => rej(new Error('bad'));
    img.src = url;
  });

  P.news = () => {
    const posted = storeGet('st-news', []);
    return `
    <div class="page-head"><div><span class="t-sm muted">Content</span><h1 class="t-h1 mt2">News</h1><p class="muted mt2">Post updates students see on Home and in the News tab: JAMB registration, new questions, classes, tips.</p></div>
      <span class="badge badge-sample">PROTOTYPE: posts save in this browser only</span></div>
    <div class="editor-grid">
      <section class="card card-pad stack g4" id="nForm">
        <div class="field" id="nfTitle"><label for="nTitle">Headline</label><div class="input"><input id="nTitle" maxlength="90" placeholder="e.g. JAMB 2027 registration opens on 6 January" value="JAMB 2027 mock exam: date and centres announced"></div><span class="help"><span id="nCount">0</span>/90 characters. Keep it short and clear.</span></div>
        <div class="grid2">
          <div class="field"><label for="nCat">Category</label><div class="input"><select id="nCat">${NEWS_CATS.map(c => `<option>${c}</option>`).join('')}</select><i class="ph ph-caret-down sel-caret"></i></div></div>
          <div class="field"><label for="nWhen">Publish</label><div class="input"><select id="nWhen"><option value="now">Now</option><option value="later">Schedule for later</option></select><i class="ph ph-caret-down sel-caret"></i></div></div>
        </div>
        <div class="field" id="nfImg"><label>Cover image</label>
          <label class="drop" style="cursor:pointer" id="nDrop">${I('image', 1).replace('class="', 'style="font-size:32px;color:var(--c-secondary)" class="')}<span class="grow"><b class="t-sm">Upload a cover image</b><br><span class="t-cap muted">JPG, PNG or WebP. Wide images (16:9) look best. We shrink it to save students' data.</span></span><span class="btn btn-outline btn-sm">Choose image</span><input type="file" id="nImg" accept="image/*" class="sr"></label>
          <div id="nImgInfo" class="hidden row g3"></div></div>
        <div class="field" id="nfSum"><label for="nSum">Short summary</label><div class="input"><textarea id="nSum" rows="2" maxlength="160" style="min-height:64px">Mock exam holds in March 2027. Check your centre and what to bring.</textarea></div><span class="help">Shown under the headline on cards (160 characters).</span></div>
        <div class="field"><label for="nBody">Full story</label><div class="rich"><div class="toolbar">${['text-b', 'text-italic', 'list-bullets', 'list-numbers', 'link', 'image'].map(i => `<button aria-label="${i}">${I(i)}</button>`).join('')}</div>
          <textarea id="nBody" style="font-family:var(--font-sans);font-size:14px;min-height:140px">JAMB will hold the optional mock examination in March 2027 for candidates who chose it during registration.

Print your mock exam slip 7 days before the date. Bring the slip and arrive 1 hour early.</textarea></div><span class="help">Leave a blank line between paragraphs.</span></div>
        <div class="grid2"><div class="field"><label for="nBtn">Button text (optional)</label><div class="input"><input id="nBtn" value="Practise a full JAMB mock"></div></div>
          <div class="field"><label for="nLink">Button opens</label><div class="input"><select id="nLink"><option value="test-setup">JAMB practice in the app</option><option value="doc">JAMB brochure in Study</option><option value="url">A website link</option></select><i class="ph ph-caret-down sel-caret"></i></div></div></div>
        <div class="stack g3">
          <label class="row between t-sm bold"><span>Pin to the top of News</span><span class="switch"><input type="checkbox" id="nPin"><span></span></span></label>
          <label class="row between t-sm bold"><span>Send a push notification to students</span><span class="switch"><input type="checkbox" id="nPush" checked><span></span></span></label>
        </div>
        <div class="row g3"><button class="btn btn-primary" id="nGo">${I('paper-plane-tilt', 1)} Publish</button><button class="btn btn-outline" id="nDraft">Save draft</button><span class="t-cap muted">Logged in the audit log.</span></div>
      </section>
      <aside class="preview stack g3">
        <div class="row between"><b>Student preview</b><div class="seg" id="pvSeg" style="width:190px"><button class="on" data-v="card">Card</button><button data-v="story">Story</button></div></div>
        <div class="mini-phone" style="width:100%;max-width:340px"><div id="nPv" style="height:520px;overflow:auto;background:var(--c-bg)"></div></div>
      </aside>
    </div>
    <section class="card" style="margin-top:16px;overflow:hidden">
      <div class="row between card-pad"><h2 class="t-h3">Published posts</h2><span class="t-cap muted">${posted.length + 4} posts</span></div>
      <table class="tbl"><thead><tr><th>Headline</th><th>Category</th><th>Published</th><th>Views</th><th></th></tr></thead><tbody id="nRows">
        ${[...posted.map(n => [n.title, n.cat, n.date, 0, n.id]), ['JAMB 2027 UTME registration: dates, fees and what to bring', 'JAMB registration', '24 Oct 2026', 12408], ['JAMB 2026 Physics is now available', 'New questions', '22 Oct 2026', 8311], ['Free Maths revision class this Saturday', 'Classes', '21 Oct 2026', 5120], ['7 habits of students who score 300+ in JAMB', 'Exam tips', '18 Oct 2026', 9876]]
          .map(([t, c, d, v, id]) => `<tr><td class="bold">${esc(t)}</td><td>${c}</td><td>${d}</td><td class="tnum">${Number(v).toLocaleString()}</td><td>${id ? `<button class="btn btn-ghost btn-sm" data-del="${id}">Delete</button>` : ''}</td></tr>`).join('')}
      </tbody></table></section>`;
  };
  P.news.mount = el => {
    const $ = s => el.querySelector(s);
    let cover = null, view = 'card';
    const paras = t => esc(t).split(/\n\s*\n/).map(x => `<p>${x.replace(/\n/g, '<br>')}</p>`).join('');
    const coverHtml = (ratio) => cover
      ? `<div style="aspect-ratio:${ratio};overflow:hidden"><img src="${cover.data}" alt="" style="width:100%;height:100%;object-fit:cover"></div>`
      : `<div style="aspect-ratio:${ratio};display:grid;place-items:center;background:linear-gradient(135deg,var(--navy-900),var(--blue-700));color:#fff;font-size:48px">${I('image', 1)}</div>`;
    const preview = () => {
      $('#nCount').textContent = $('#nTitle').value.length;
      const t = esc($('#nTitle').value || 'Your headline'), cat = $('#nCat').value, sum = esc($('#nSum').value);
      $('#nPv').innerHTML = view === 'card'
        ? `<div style="padding:16px"><b class="t-sm muted">Home · News</b><div class="news-tile mt3">${coverHtml('16/8')}<span class="nt-body"><span class="row g2"><span class="badge badge-soft">${cat}</span>${$('#nPin').checked ? `<span class="badge badge-gold">${I('push-pin', 1)} Pinned</span>` : ''}</span><b class="nt-title">${t}</b><span class="t-cap muted">Today · 1 min read</span></span></div></div>`
        : `${coverHtml('16/10')}<div class="note-body" style="padding:16px"><span class="badge badge-soft">${cat}</span><h1 class="t-h2 mt2">${t}</h1><p class="muted">${sum}</p>${paras($('#nBody').value)}${$('#nBtn').value ? `<button class="btn btn-primary btn-block">${esc($('#nBtn').value)}</button>` : ''}</div>`;
    };
    el.querySelectorAll('#nForm input, #nForm textarea, #nForm select').forEach(x => x.addEventListener('input', preview));
    $('#pvSeg').querySelectorAll('button').forEach(b => b.onclick = () => { view = b.dataset.v; $('#pvSeg').querySelectorAll('button').forEach(x => x.classList.toggle('on', x === b)); preview(); });
    $('#nImg').onchange = async () => {
      const f = $('#nImg').files[0]; if (!f) return;
      $('#nfImg').classList.remove('has-error'); $('#nfImg').querySelector('.err')?.remove();
      try {
        cover = await shrink(f);
        $('#nImgInfo').classList.remove('hidden');
        $('#nImgInfo').innerHTML = `<img src="${cover.data}" alt="" style="width:96px;height:54px;object-fit:cover;border-radius:8px"><span class="grow t-cap"><b>${esc(f.name)}</b><br>${cover.w}×${cover.h} · ${cover.kb} KB (was ${Math.round(f.size / 1024)} KB)</span><button class="btn btn-ghost btn-sm" id="nImgX">Remove</button>`;
        $('#nImgX').onclick = () => { cover = null; $('#nImg').value = ''; $('#nImgInfo').classList.add('hidden'); preview(); };
      } catch (e) { $('#nfImg').classList.add('has-error'); $('#nfImg').insertAdjacentHTML('beforeend', `<span class="err">${I('warning-circle', 1)} That file is not an image. Choose a JPG, PNG or WebP.</span>`); }
      preview();
    };
    const go = { 'test-setup': ['test-setup', 'body=JAMB&mode=full'], doc: ['doc', ''], url: [null, ''] };
    $('#nGo').onclick = () => {
      el.querySelectorAll('#nForm .field').forEach(f => { if (f.id !== 'nfImg') { f.classList.remove('has-error'); f.querySelector('.err')?.remove(); } });
      let bad = false;
      if ($('#nTitle').value.trim().length < 10) { $('#nfTitle').classList.add('has-error'); $('#nfTitle').insertAdjacentHTML('beforeend', `<span class="err">${I('warning-circle', 1)} Write a headline of at least 10 characters.</span>`); bad = true; }
      if ($('#nSum').value.trim().length < 10) { $('#nfSum').classList.add('has-error'); $('#nfSum').insertAdjacentHTML('beforeend', `<span class="err">${I('warning-circle', 1)} Add a short summary.</span>`); bad = true; }
      if (bad) return;
      const [gTo, gParams] = go[$('#nLink').value];
      const post = {
        id: 'p' + Date.now(), cat: $('#nCat').value, pinned: $('#nPin').checked, date: 'Today', read: Math.max(1, Math.round($('#nBody').value.split(/\s+/).length / 200)),
        cover: cover ? { img: cover.data } : { g: 'c-navy', icon: 'megaphone', logo: /JAMB/.test($('#nCat').value + $('#nTitle').value) ? 'JAMB' : null },
        title: $('#nTitle').value.trim(), summary: $('#nSum').value.trim(), body: paras($('#nBody').value),
        cta: $('#nBtn').value ? (gTo ? { label: $('#nBtn').value, go: gTo, params: gParams } : { label: $('#nBtn').value, url: 'jamb.gov.ng' }) : null
      };
      const list = storeGet('st-news', []); list.unshift(post);
      if (!storeSet('st-news', list.slice(0, 5))) { toast('Could not save: the image is too large for this browser demo. Try a smaller image.'); return; }
      toast(`Published${$('#nPush').checked ? ' and push notification sent' : ''}. Students see it now on Home and in News.`);
      setTimeout(() => { location.hash = '#news'; go_(); }, 600);
    };
    $('#nDraft').onclick = () => toast('Draft saved.');
    el.querySelectorAll('[data-del]').forEach(b => b.onclick = () => { storeSet('st-news', storeGet('st-news', []).filter(n => n.id !== b.dataset.del)); toast('Post deleted.'); go_(); });
    preview();
  };

  // ---------- Leaderboard settings ----------
  P.leaderboard = () => {
    const set = Object.assign({ on: true, years: { 2027: true, 2026: true, 2025: false }, names: 'first-initial', minTests: 3 }, storeGet('st-lb', {}));
    return `
    <div class="page-head"><div><span class="t-sm muted">App control</span><h1 class="t-h1 mt2">Leaderboard</h1><p class="muted mt2">Decide if students can see leaderboards, for which JAMB years, and how names are shown.</p></div>
      <button class="btn btn-primary" id="lbSave">Save changes</button></div>
    <div class="two" style="grid-template-columns:1fr 1fr;margin-top:0">
      <section class="card card-pad stack g4">
        <label class="row between"><span><b>Show leaderboards to students</b><br><span class="t-cap muted">When off, students do not see the leaderboard anywhere in the app.</span></span><span class="switch"><input type="checkbox" id="lbOn" ${set.on ? 'checked' : ''}><span></span></span></label>
        <hr class="divider">
        <div class="field"><label>JAMB years students can see</label>
          <div class="stack g2">${Object.keys(set.years).sort((a, b) => b - a).map(y => `<label class="row between t-sm"><span class="row g2"><b>JAMB ${y}</b>${y === '2027' ? '<span class="badge badge-success">Current season</span>' : '<span class="badge badge-neutral">Past year: shows the best student</span>'}</span><span class="switch"><input type="checkbox" data-year="${y}" ${set.years[y] ? 'checked' : ''}><span></span></span></label>`).join('')}</div></div>
      </section>
      <section class="card card-pad stack g4">
        <div class="field"><label for="lbNames">How names appear</label><div class="input"><select id="lbNames"><option value="first-initial" ${set.names === 'first-initial' ? 'selected' : ''}>First name + initial (Chiamaka O.)</option><option value="first" ${set.names === 'first' ? 'selected' : ''}>First name only</option></select><i class="ph ph-caret-down sel-caret"></i></div><span class="help">Many students are under 18, so full names are never shown.</span></div>
        <div class="field"><label for="lbMin">Full mocks needed to appear</label><div class="input num-input"><input id="lbMin" type="number" min="1" max="20" value="${set.minTests}"></div></div>
        <div class="field"><label>Ranked by</label><div class="seg"><button class="on">Best full mock score</button><button>Average score</button></div></div>
        <div class="banner info">${I('shield-check', 1)}<span>Students can hide themselves in Settings. Suspicious scores (too fast, too perfect) are held for review before they appear.</span></div>
      </section>
    </div>`;
  };
  P.leaderboard.mount = el => {
    el.querySelector('#lbSave').onclick = () => {
      const years = {}; el.querySelectorAll('[data-year]').forEach(c => years[c.dataset.year] = c.checked);
      const ok = storeSet('st-lb', { on: el.querySelector('#lbOn').checked, years, names: el.querySelector('#lbNames').value, minTests: +el.querySelector('#lbMin').value || 3 });
      toast(ok ? (el.querySelector('#lbOn').checked ? 'Saved. Students can see the leaderboard.' : 'Saved. Leaderboards are hidden from students.') : 'Could not save in this browser.');
    };
  };

  // ---------- Free vs Premium (access rules) ----------
  const ACC_ROWS = [
    ['Exams (years open in CBT practice)', null],
    ['jamb', 'JAMB', 'years'], ['waec', 'WAEC', 'years'], ['neco', 'NECO', 'years'],
    ['Study', null],
    ['pq', 'Past questions with answers (study mode)', 'years'], ['videos', 'Video solutions', 'bool'], ['lessons', 'Topic video lessons', 'bool'],
    ['notes', 'Lesson notes', 'bool'], ['novels', 'Novels', 'bool'], ['syllabus', 'Syllabuses and brochure', 'count'],
    ['Other', null],
    ['ai', 'AI tutor prompts per day', 'num'], ['offline', 'Offline downloads', 'bool'], ['compete', 'Challenges and events', 'bool']
  ];
  const accCell = (plan, key, kind, v) => {
    if (kind === 'bool') return `<span class="switch"><input type="checkbox" data-k="${plan}.${key}" ${v ? 'checked' : ''}><span></span></span>`;
    if (kind === 'num') return `<div class="input num-input" style="min-height:40px"><input type="number" min="0" data-k="${plan}.${key}" value="${v}" style="min-height:40px"></div>`;
    const all = v === 'all';
    return `<div class="row g2"><div class="input num-input" style="min-height:40px;width:84px"><input type="number" min="0" max="26" data-k="${plan}.${key}" value="${all ? '' : v}" placeholder="All" ${all ? 'disabled' : ''} style="min-height:40px"></div>
      <label class="row g1 t-cap bold"><input type="checkbox" data-all="${plan}.${key}" ${all ? 'checked' : ''} style="width:18px;height:18px;accent-color:var(--c-secondary)">All</label></div>`;
  };
  P.access = () => {
    const A = ST.access();
    return `
    <div class="page-head"><div><span class="t-sm muted">App control</span><h1 class="t-h1 mt2">Free vs Premium</h1><p class="muted mt2">Choose exactly what each plan gets. Changes apply to students straight away and are enforced on the server.</p></div>
      <div class="row g2"><button class="btn btn-outline" id="accReset">Reset to default</button><button class="btn btn-primary" id="accSave">Save changes</button></div></div>
    <div class="banner info" style="margin-bottom:16px">${I('info', 1)}<span>Years: type how many years are open, tick <b>All</b> for every year, or type <b>0</b> to close that exam. Free years are the
      <select id="accWhich" style="font:inherit;font-weight:700;border:0;background:transparent;color:var(--c-link)"><option value="oldest" ${A.free.which === 'oldest' ? 'selected' : ''}>oldest</option><option value="newest" ${A.free.which === 'newest' ? 'selected' : ''}>newest</option></select> years (e.g. 2000 to 2002).</span></div>
    <section class="card" style="overflow:hidden"><table class="tbl acc-tbl"><thead><tr><th>Feature</th><th style="width:240px">Free</th><th style="width:240px">${I('crown-simple', 1)} Premium</th></tr></thead><tbody>
      ${ACC_ROWS.map(([key, label, kind]) => !label ? `<tr class="acc-grp"><td colspan="3">${key}</td></tr>`
        : `<tr><td class="bold" style="vertical-align:middle">${label}</td><td>${accCell('free', key, kind, A.free[key])}</td><td>${accCell('premium', key, kind, A.premium[key])}</td></tr>`).join('')}
    </tbody></table></section>
    <section class="card card-pad stack g3" style="margin-top:16px"><b>What students will see on the paywall</b><div class="stack g2" id="accPreview"></div></section>`;
  };
  P.access.mount = el => {
    const read = () => {
      const out = { free: {}, premium: {} };
      el.querySelectorAll('[data-k]').forEach(x => {
        const [plan, key] = x.dataset.k.split('.'), allBox = el.querySelector(`[data-all="${plan}.${key}"]`);
        out[plan][key] = x.type === 'checkbox' ? x.checked : allBox && allBox.checked ? 'all' : Math.max(0, +x.value || 0);
      });
      out.free.which = out.premium.which = el.querySelector('#accWhich').value;
      return out;
    };
    const preview = () => {
      const saved = localStorage.getItem('st-access');
      try { localStorage.setItem('st-access', JSON.stringify(read())); } catch (e) {}
      el.querySelector('#accPreview').innerHTML = (ST.premiumBenefits ? ST.premiumBenefits() : []).map(b => `<div class="benefit">${I('check-circle', 1)}<span>${b}</span></div>`).join('') || '<span class="muted t-sm">Free and Premium are the same.</span>';
      try { saved === null ? localStorage.removeItem('st-access') : localStorage.setItem('st-access', saved); } catch (e) {}
    };
    el.querySelectorAll('[data-all]').forEach(b => b.onchange = () => { const inp = el.querySelector(`[data-k="${b.dataset.all}"]`); inp.disabled = b.checked; if (!b.checked && !inp.value) inp.value = 3; preview(); });
    el.addEventListener('input', preview); el.addEventListener('change', preview);
    el.querySelector('#accSave').onclick = () => {
      const r = read();
      if (r.free.ai > r.premium.ai) { toast('Free cannot have more AI prompts than Premium.'); return; }
      try { localStorage.setItem('st-access', JSON.stringify(r)); toast('Saved. Students see the new limits now. Logged in audit log.'); } catch (e) { toast('Could not save in this browser.'); }
    };
    el.querySelector('#accReset').onclick = () => { try { localStorage.removeItem('st-access'); } catch (e) {} go_(); toast('Back to the default Free and Premium rules.'); };
    preview();
  };

  // ---------- Challenges & events ----------
  P.challenges = () => `
    <div class="page-head"><div><span class="t-sm muted">Content</span><h1 class="t-h1 mt2">Challenges & events</h1><p class="muted mt2">Post question sets any time: weekly cash challenges, events with or without rewards, free or paid entry. Open to Free and Premium.</p></div>
      <span class="badge badge-sample">SAMPLE DATA</span></div>
    <div class="kpi-grid">
      ${[['Live now', '2', 'broadcast'], ['Entries this week', '1,696', 'users-three'], ['Prizes to pay', naira(35000), 'currency-ngn'], ['Disqualified this week', '23', 'shield-warning']].map(([l, v, ic]) => `
        <div class="card kpi-tile"><div class="row between"><span class="t-sm muted bold">${l}</span><span class="ic navy" style="width:32px;height:32px;border-radius:9px;display:grid;place-items:center;font-size:16px">${I(ic, 1)}</span></div><b>${v}</b></div>`).join('')}
    </div>
    <div class="two" style="grid-template-columns:1.3fr 1fr">
      <section class="card card-pad stack g4" id="cForm">
        <h2 class="t-h3">Create a challenge or event</h2>
        <div class="field"><label>Type</label><div class="seg" id="cType"><button class="on" data-t="cash">Cash challenge</button><button data-t="event">Event</button><button data-t="practice">Practice (no reward)</button></div></div>
        <div class="field" id="cfTitle"><label for="cTitle">Title</label><div class="input"><input id="cTitle" value="Weekly Challenge #45"></div></div>
        <div class="field"><label>Questions</label><div class="row g2 wrap"><button class="btn btn-outline btn-sm">${I('plus')} Write new</button><button class="btn btn-outline btn-sm">${I('database')} Pick from bank</button><button class="btn btn-outline btn-sm">${I('file-csv')} Import CSV</button><span class="badge badge-success" style="height:32px">${I('check', 1)} 10 new questions added</span></div>
          <span class="help">Use new questions for cash challenges. Past questions can be searched online.</span></div>
        <div class="grid3"><div class="field"><label for="cStart">Starts</label><div class="input"><input id="cStart" type="datetime-local" value="2026-11-01T18:00"></div></div>
          <div class="field"><label for="cEnd">Closes</label><div class="input"><input id="cEnd" type="datetime-local" value="2026-11-01T21:00"></div></div>
          <div class="field"><label for="cPer">Seconds per question</label><div class="input"><input id="cPer" type="number" value="30" min="10" max="180"></div></div></div>
        <div class="field"><label>Entry</label><div class="seg" id="cEntry"><button class="on" data-e="free">Free</button><button data-e="paid">Paid entry</button></div></div>
        <div class="field hidden" id="cFeeF"><label for="cFee">Entry fee (₦)</label><div class="input num-input"><input id="cFee" type="number" value="200"></div><span class="help">Paid with Paystack. Not available in the Play Store build until approved (see note).</span></div>
        <div class="field" id="cRewardF"><label>Reward</label><div class="seg" id="cReward"><button class="on" data-r="cash">Cash</button><button data-r="premium">Premium days</button><button data-r="badge">Badge only</button><button data-r="none">None</button></div></div>
        <div class="grid3" id="cPrizes"><div class="field"><label>1st (₦)</label><div class="input"><input type="number" value="20000"></div></div><div class="field"><label>2nd (₦)</label><div class="input"><input type="number" value="10000"></div></div><div class="field"><label>3rd (₦)</label><div class="input"><input type="number" value="5000"></div></div></div>
        <div class="field"><label>Winner rule (same for every challenge)</label><div class="card card-pad t-sm" style="background:var(--c-surface-alt)"><b>1.</b> Best score &nbsp; <b>2.</b> Fastest time &nbsp; <b>3.</b> Started earlier<br><span class="t-cap muted">Winners are announced automatically the moment it closes. Each student can take a challenge only once.</span></div></div>
        <section class="card card-pad stack g3" style="background:var(--c-success-soft);border-color:transparent">
          <b class="row g2" style="color:var(--c-on-success-soft)">${I('shield-check', 1)} Fair play (anti-cheat)</b>
          ${[['Leaving the app, split screen or floating apps submits and disqualifies', true], ['Block screenshots, screen recording and copying', true], ['One question at a time, no going back', true], ['Shuffle questions and options per student', true], ['Flag too-fast or unusual answer patterns for review', true], ['Block rooted phones and emulators (Play Integrity)', true], ['One entry per person, phone and NIN', true], ['Winners must verify identity (guardian for under-18)', true]].map(([t, on]) => `<label class="row between t-sm"><span>${t}</span><span class="switch"><input type="checkbox" ${on ? 'checked' : ''}><span></span></span></label>`).join('')}
          <div class="row g3 t-sm"><span class="grow">App switches allowed before disqualification</span><div class="input num-input" style="min-height:40px;width:80px"><input type="number" value="0" min="0" max="3" style="min-height:40px"></div></div>
        </section>
        <label class="row between t-sm bold"><span>Send a push notification when it goes live</span><span class="switch"><input type="checkbox" checked><span></span></span></label>
        <div class="row g3"><button class="btn btn-primary" id="cGo">${I('paper-plane-tilt', 1)} Schedule</button><span class="t-cap muted">Logged in the audit log.</span></div>
      </section>
      <aside class="stack g4">
        <section class="card card-pad stack g3"><div class="row between"><b>Fair-play review</b><span class="badge badge-warning">3 to check</span></div>
          ${[['Tolu A.', 'Left the app at 1:12 (switched to Chrome)', 'Auto-disqualified'], ['Precious E.', 'Answered 10 in 0:41, 4s each', 'Flagged: too fast'], ['Emeka O.', 'Same phone as another winner', 'Flagged: duplicate device']].map(([n, r, s]) => `
          <div class="stack g2 dq-row"><div class="row between"><b class="t-sm">${n}</b><span class="badge ${s.startsWith('Auto') ? 'badge-error' : 'badge-warning'}">${s}</span></div><span class="t-cap muted">${r} · Weekly Challenge #44</span>
            <div class="row g2"><button class="btn btn-outline btn-sm" data-dq="keep">Keep disqualified</button><button class="btn btn-ghost btn-sm" data-dq="ok">Reinstate</button></div></div>`).join('')}
        </section>
        <section class="card card-pad stack g3"><b>Winners to pay</b>
          ${[['Ifeoma N.', '#1 · Challenge #43', 20000, 'Verified'], ['Mubarak I.', '#2 · Challenge #43', 10000, 'Verified'], ['Zainab Y. (guardian)', '#3 · Challenge #43', 5000, 'Waiting for guardian']].map(([n, d, a, s]) => `
          <div class="stack g2 pay-row" data-name="${n}" data-amt="${a}" data-place="${d}"><div class="row g3"><span class="grow"><b class="t-sm">${n}</b><br><span class="t-cap muted">${d} · ${s}</span></span><b class="tnum">${naira(a)}</b><button class="btn btn-sm ${s === 'Verified' ? 'btn-primary' : 'btn-outline'}" ${s === 'Verified' ? 'data-pay' : 'disabled'}>Pay</button></div><div class="proof-box hidden"></div></div>`).join('')}
          <p class="t-cap muted">Payouts go by Paystack Transfer to the verified account. Two admins must approve payouts above ${naira(50000)}.</p>
        </section>
      </aside>
    </div>
    <section class="card" style="margin-top:16px;overflow:hidden"><div class="card-pad"><h2 class="t-h3">All challenges and events</h2></div>
      <table class="tbl"><thead><tr><th>Title</th><th>Type</th><th>Entry</th><th>Reward</th><th>Entries</th><th>Status</th><th></th></tr></thead><tbody>
        ${[['Weekly Challenge #44', 'Cash', 'Free', `${naira(20000)} / ${naira(10000)} / ${naira(5000)}`, '1,284', 'Live'], ['Physics Practice Night', 'Practice', 'Free', 'None', '96', 'Live'], ['Maths Sprint Cup', 'Event', naira(200), `${naira(50000)} top prize`, '412', 'Scheduled'], ['Use of English Bee', 'Event', 'Free', '30 days Premium (top 10)', '230', 'Scheduled'], ['Weekly Challenge #43', 'Cash', 'Free', `${naira(20000)} / ${naira(10000)} / ${naira(5000)}`, '1,532', 'Paying out']]
          .map(r => `<tr>${r.map((c, i) => `<td>${i === 5 ? `<span class="badge ${c === 'Live' ? 'badge-error' : c === 'Scheduled' ? 'badge-soft' : 'badge-warning'}">${c}</span>` : i === 0 ? `<b>${c}</b>` : c}</td>`).join('')}<td>${r[5] === 'Live' ? `<button class="btn btn-outline btn-sm" data-close-ch="${{ 'Weekly Challenge #44': 'wk44', 'Physics Practice Night': 'night' }[r[0]]}">Close now</button>` : ''}</td></tr>`).join('')}
      </tbody></table></section>
    <div class="banner warn" style="margin-top:16px">${I('scales', 1)}<span><b>Legal check needed before launch:</b> cash prizes, and especially paid entry, may need a licence (e.g. lottery/gaming rules) and Google Play's real-money contest rules may apply. Many players are minors. Confirm with a lawyer before turning on paid entry.</span></div>`;
  P.challenges.mount = el => {
    const seg = (id, cb) => el.querySelectorAll(`#${id} button`).forEach(b => b.onclick = () => { el.querySelectorAll(`#${id} button`).forEach(x => x.classList.toggle('on', x === b)); cb(b); });
    seg('cType', b => { const t = b.dataset.t; el.querySelector('#cRewardF').classList.toggle('hidden', t === 'practice'); el.querySelector('#cPrizes').classList.toggle('hidden', t !== 'cash' && el.querySelector('#cReward .on').dataset.r !== 'cash' || t === 'practice'); el.querySelector('#cTitle').value = { cash: 'Weekly Challenge #45', event: 'Biology Blitz', practice: 'Chemistry Practice Night' }[t]; });
    seg('cEntry', b => el.querySelector('#cFeeF').classList.toggle('hidden', b.dataset.e !== 'paid'));
    seg('cReward', b => el.querySelector('#cPrizes').classList.toggle('hidden', b.dataset.r !== 'cash'));
    el.querySelectorAll('[data-dq]').forEach(b => b.onclick = () => { const row = b.closest('.dq-row'); row.style.opacity = .5; row.querySelectorAll('button').forEach(x => x.disabled = true); toast(b.dataset.dq === 'ok' ? 'Entry reinstated. The student is told.' : 'Disqualification kept. The student is told.'); });
    // Pay → then upload proof of payment and publish it to the Winners wall
    el.querySelectorAll('[data-pay]').forEach(b => b.onclick = () => {
      b.classList.add('is-loading'); b.textContent = '';
      setTimeout(() => {
        b.classList.remove('is-loading'); b.textContent = 'Paid'; b.disabled = true;
        const row = b.closest('.pay-row'), box = row.querySelector('.proof-box');
        box.classList.remove('hidden');
        box.innerHTML = `<div class="card card-pad stack g3" style="background:var(--c-surface-alt)">
          <b class="t-sm">${I('seal-check', 1)} Post proof of payment</b>
          <label class="drop" style="cursor:pointer;padding:12px">${I('image', 1)}<span class="grow t-cap">Upload the transfer receipt (screenshot or PDF image)</span><span class="btn btn-outline btn-sm">Choose</span><input type="file" accept="image/*" class="sr" data-proof-file></label>
          <div class="hidden" data-proof-prev></div>
          <label class="check"><input type="checkbox" data-proof-mask> <span>I have hidden the full account number, balance and any other private details.</span></label>
          <div class="field"><label>Winner's message (optional, with their permission)</label><div class="input"><input data-proof-note placeholder="e.g. I did not believe it until the alert came!"></div></div>
          <label class="row between t-sm"><span>Show on the Winners wall</span><span class="switch"><input type="checkbox" checked data-proof-wall><span></span></span></label>
          <label class="row between t-sm"><span>Also post in News</span><span class="switch"><input type="checkbox" data-proof-news><span></span></span></label>
          <button class="btn btn-primary btn-sm" data-proof-go>Publish proof</button></div>`;
        let img = null;
        box.querySelector('[data-proof-file]').onchange = async e => {
          const f = e.target.files[0]; if (!f) return;
          try { img = await shrink(f); const pv = box.querySelector('[data-proof-prev]'); pv.classList.remove('hidden'); pv.innerHTML = `<img src="${img.data}" alt="" style="max-height:140px;border-radius:8px">`; }
          catch (err) { toast('That file is not an image.'); }
        };
        box.querySelector('[data-proof-go]').onclick = () => {
          if (!img) { toast('Upload the receipt first.'); return; }
          if (!box.querySelector('[data-proof-mask]').checked) { toast('Hide the private details and tick the box first.'); return; }
          const proof = { name: row.dataset.name.replace(' (guardian)', ''), state: '', ch: row.dataset.place.split('·')[1]?.trim() || 'Weekly challenge', place: row.dataset.place.split('·')[0].trim(), amt: +row.dataset.amt, date: 'Today', img: img.data, note: box.querySelector('[data-proof-note]').value.trim() };
          if (box.querySelector('[data-proof-wall]').checked) { try { const list = JSON.parse(localStorage.getItem('st-proofs') || '[]'); list.unshift(proof); localStorage.setItem('st-proofs', JSON.stringify(list.slice(0, 5))); } catch (err) { toast('Image too large for this browser demo.'); return; } }
          box.innerHTML = `<span class="badge badge-success">${I('check', 1)} Proof published${box.querySelector('[data-proof-news]')?.checked ? ' and posted in News' : ''}</span>`;
          toast('Proof of payment is live on the Winners wall.');
        };
        toast('Transfer sent. Now post the proof of payment.');
      }, 900);
    });
    el.querySelectorAll('[data-close-ch]').forEach(b => b.onclick = () => {
      try { const ids = JSON.parse(localStorage.getItem('st-closed') || '[]'); if (!ids.includes(b.dataset.closeCh)) ids.push(b.dataset.closeCh); localStorage.setItem('st-closed', JSON.stringify(ids)); } catch (err) {}
      b.outerHTML = '<span class="badge badge-success">Closed · winners announced</span>';
      toast('Closed. Winners announced and notified with the claim form.');
    });
    el.querySelector('#cGo').onclick = () => toast(`"${el.querySelector('#cTitle').value}" scheduled. Students get a push when it goes live.`);
  };

  // ---------- Referrals ----------
  P.referrals = () => {
    const R = ST.refRules();
    return `
    <div class="page-head"><div><span class="t-sm muted">People & money</span><h1 class="t-h1 mt2">Referrals</h1><p class="muted mt2">Set the rewards. Every reward is checked by the fraud rules before it is given.</p></div>
      <button class="btn btn-primary" id="refSave">Save changes</button></div>
    <div class="kpi-grid">
      ${[['Successful referrals', '2,418', 'users-three'], ['Discount codes given', '1,903', 'ticket'], ['Free Premium earned', '97', 'crown-simple'], ['Blocked as fraud', '312', 'prohibit']].map(([l, v, ic]) => `
        <div class="card kpi-tile"><div class="row between"><span class="t-sm muted bold">${l}</span><span class="ic navy" style="width:32px;height:32px;border-radius:9px;display:grid;place-items:center;font-size:16px">${I(ic, 1)}</span></div><b>${v}</b></div>`).join('')}
    </div>
    <div class="two" style="grid-template-columns:1fr 1fr">
      <section class="card card-pad stack g4">
        <h2 class="t-h3">Rewards</h2>
        <div class="grid2"><div class="field"><label for="rStep">Discount per successful friend</label><div class="input"><input id="rStep" type="number" min="1" max="100" value="${R.step}"><span class="t-sm muted" style="padding-right:12px">%</span></div></div>
          <div class="field"><label for="rFree">Friends for 100% off (Premium free)</label><div class="input"><input id="rFree" type="number" min="1" value="${R.freeAt}"></div></div></div>
        <div class="field"><label for="rPlan">Free Premium plan given at 100%</label><div class="input"><select id="rPlan">${['Monthly', '3 Months', 'Exam Season'].map(x => `<option ${x === R.freePlan ? 'selected' : ''}>${x}</option>`).join('')}</select><i class="ph ph-caret-down sel-caret"></i></div></div>
        <div class="grid2"><div class="field"><label for="rCashAt">Friends for a cash reward</label><div class="input"><input id="rCashAt" type="number" min="1" value="${R.cashAt}"></div></div>
          <div class="field"><label for="rCash">Cash reward (₦)</label><div class="input"><input id="rCash" type="number" min="0" value="${R.cashAmount}"></div></div></div>
        <div class="field"><label for="rSuccess">A friend counts when they</label><div class="input"><select id="rSuccess">
          <option value="verify" ${R.success === 'verify' ? 'selected' : ''}>Sign up and verify email and phone</option>
          <option value="test" ${R.success === 'test' ? 'selected' : ''}>Verify phone and finish one practice test (recommended)</option>
          <option value="pay" ${R.success === 'pay' ? 'selected' : ''}>Buy Premium</option></select><i class="ph ph-caret-down sel-caret"></i></div></div>
        <div class="field"><label for="rCap">Most rewards one student can earn per month</label><div class="input num-input"><input id="rCap" type="number" min="1" value="${R.monthlyCap}"></div></div>
        <div class="card card-pad t-sm" id="rPreview" style="background:var(--c-surface-alt)"></div>
      </section>
      <section class="card card-pad stack g3"><div class="row between"><h2 class="t-h3">Cash rewards due</h2><span class="badge badge-warning">2 to pay</span></div>
        ${[['Chukwuemeka O.', 'Imo', 30, 'Paid · proof posted'], ['Halima S.', 'FCT Abuja', 30, 'Verified'], ['Kelechi U.', 'Rivers', 31, 'Verified'], ['Seyi A.', 'Lagos', 34, 'Flagged: 9 friends share 2 phones']].map(([n, st, c, s]) => `
          <div class="row g3 t-sm"><span class="grow"><b>${n}</b> <span class="muted">${st}</span><br><span class="t-cap muted">${c} successful friends · ${s}</span></span>${s === 'Verified' ? `<button class="btn btn-primary btn-sm" data-rpay>Pay ${naira(R.cashAmount)}</button>` : s.startsWith('Flagged') ? `<a class="btn btn-outline btn-sm" href="#fraud">Review</a>` : `<span class="badge badge-success">Paid</span>`}</div>`).join('')}
        <hr class="divider"><h2 class="t-h3">Top referrers this month</h2>
        <table class="tbl"><thead><tr><th>Student</th><th>Successful</th><th>Blocked</th><th>Reward</th></tr></thead><tbody>
          ${[['Seyi A.', 34, 11, 'On hold'], ['Kelechi U.', 31, 0, 'Cash due'], ['Halima S.', 30, 1, 'Cash due'], ['Tolu A.', 12, 1, 'Premium free'], ['Bola F.', 7, 0, '70% code']].map(r => `<tr>${r.map((x, i) => `<td class="${i ? 'tnum' : 'bold'}">${x}</td>`).join('')}</tr>`).join('')}
        </tbody></table>
      </section>
    </div>`;
  };
  P.referrals.mount = el => {
    const $ = s => el.querySelector(s);
    const read = () => ({ step: +$('#rStep').value || 10, freeAt: +$('#rFree').value || 10, freePlan: $('#rPlan').value, cashAt: +$('#rCashAt').value || 30, cashAmount: +$('#rCash').value || 0, success: $('#rSuccess').value, monthlyCap: +$('#rCap').value || 50 });
    const pv = () => { const r = read(); $('#rPreview').innerHTML = `<b>Students see:</b> “${r.step}% off for every friend. ${r.freeAt} friends = Premium free (${r.freePlan}). ${r.cashAt} friends = ${naira(r.cashAmount)} cash.”${r.step * r.freeAt < 100 ? `<br><span style="color:var(--c-warning)">Note: ${r.freeAt} × ${r.step}% is only ${r.step * r.freeAt}%, so they never reach 100% off.</span>` : ''}`; };
    el.addEventListener('input', pv); el.addEventListener('change', pv); pv();
    $('#refSave').onclick = () => { try { localStorage.setItem('st-ref', JSON.stringify(read())); toast('Saved. Students see the new referral rewards now.'); } catch (e) { toast('Could not save in this browser.'); } };
    el.querySelectorAll('[data-rpay]').forEach(b => b.onclick = () => { b.classList.add('is-loading'); b.textContent = ''; setTimeout(() => { b.outerHTML = '<span class="badge badge-success">Paid</span>'; toast('Transfer sent. Upload the proof in Challenges & events → Winners to pay.'); }, 900); });
  };

  // ---------- Fraud & bans (one account per person) ----------
  P.fraud = () => `
    <div class="page-head"><div><span class="t-sm muted">People & money</span><h1 class="t-h1 mt2">Fraud & bans</h1><p class="muted mt2">One person, one account. Find multiple accounts, app cloners and fake referrals, then ban every linked account.</p></div></div>
    <div class="kpi-grid">
      ${[['Sign-ups blocked (phone already used)', '1,206', 'device-mobile'], ['App cloners blocked', '842', 'copy-simple'], ['Linked groups to review', '6', 'graph'], ['Banned accounts', '388', 'prohibit']].map(([l, v, ic]) => `
        <div class="card kpi-tile"><div class="row between"><span class="t-sm muted bold">${l}</span><span class="ic navy" style="width:32px;height:32px;border-radius:9px;display:grid;place-items:center;font-size:16px">${I(ic, 1)}</span></div><b>${v}</b></div>`).join('')}
    </div>
    <div class="two" style="grid-template-columns:1.2fr 1fr">
      <section class="card card-pad stack g3"><div class="row between"><h2 class="t-h3">Linked accounts to review</h2><span class="badge badge-warning">6 groups</span></div>
        ${[['Device ••a91f (Tecno Spark 10)', ['seyi.a@…', 'seyi.ad@…', 'adeseyi2@…', 'sy.ade@…'], 'Same phone, 4 accounts · 9 referrals to the same code · same Wi-Fi IP', 'high'],
           ['Bank account GTBank ••••0373', ['halima.s@…', 'h.sani@…'], 'Two accounts asked prizes to the same bank account', 'high'],
           ['App cloner: Parallel Space', ['tunde99@…'], 'Second copy of the app detected inside Parallel Space', 'med'],
           ['Signup burst · IP 102.89.•.•', ['ola1@…', 'ola2@…', 'ola3@…'], '3 sign-ups in 6 minutes, similar emails, all used code OLA-5TQ2', 'med']].map(([g, accts, why, lvl], i) => `
          <div class="stack g2 dq-row" data-grp="${i}"><div class="row between"><b class="t-sm">${g}</b><span class="badge ${lvl === 'high' ? 'badge-error' : 'badge-warning'}">${lvl === 'high' ? 'High risk' : 'Medium risk'}</span></div>
            <span class="t-cap muted">${why}</span><div class="row g2 wrap">${accts.map(a => `<span class="chip" style="min-height:28px;cursor:default">${I('user')} ${a}</span>`).join('')}</div>
            <div class="row g2"><button class="btn btn-danger btn-sm" data-ban>${I('prohibit', 1)} Ban all ${accts.length} and this device</button><button class="btn btn-ghost btn-sm" data-dismiss>Not fraud</button></div></div>`).join('')}
      </section>
      <aside class="stack g4">
        <section class="card card-pad stack g3"><h2 class="t-h3">Protection rules</h2>
          ${[['One account per phone (device ID + Play Integrity)', true], ['Block app cloners, dual apps and work-profile copies', true], ['Block rooted phones and emulators', true], ['Phone number OTP before any reward or prize', true], ['One phone number, one NIN and one bank account per person', true], ['Block disposable email addresses', true], ['Referral only counts on a different phone, IP and payment method', true], ['Hold rewards when a group is flagged', true]].map(([t, on]) => `<label class="row between t-sm"><span>${t}</span><span class="switch"><input type="checkbox" ${on ? 'checked' : ''}><span></span></span></label>`).join('')}
        </section>
        <section class="card card-pad stack g2"><h2 class="t-h3">Cloners blocked this month</h2>
          ${[['Parallel Space', 402], ['Dual Space', 188], ['Phone "Dual apps" / "Clone apps"', 151], ['App Cloner', 63], ['Work profile (Island, Shelter)', 38]].map(([n, v]) => `<div class="stack g1"><div class="row between t-sm"><span>${n}</span><b class="tnum">${v}</b></div><div class="bar" style="height:6px"><i style="width:${Math.round(v / 4.02)}%"></i></div></div>`).join('')}
        </section>
        <section class="card card-pad stack g2"><h2 class="t-h3">Recently banned</h2>
          ${[['adeseyi2@…', 'Multiple accounts on one phone', '25 Oct'], ['kemi.k@…', 'Cheating in Weekly Challenge #42 (appeal rejected)', '21 Oct']].map(([a, r, d]) => `<div class="row g3 t-sm"><span class="grow"><b>${a}</b><br><span class="t-cap muted">${r} · ${d}</span></span><button class="btn btn-ghost btn-sm" data-unban>Unban</button></div>`).join('')}
        </section>
      </aside>
    </div>`;
  P.fraud.mount = el => {
    el.querySelectorAll('[data-ban]').forEach(b => b.onclick = () => { if (!b.dataset.sure) { b.dataset.sure = '1'; b.innerHTML = 'Tap again to ban all and cancel their rewards'; return; } const row = b.closest('.dq-row'); row.style.opacity = .5; row.querySelectorAll('button').forEach(x => x.disabled = true); toast('Group banned. Rewards cancelled. Logged in the audit log.'); });
    el.querySelectorAll('[data-dismiss]').forEach(b => b.onclick = () => { b.closest('.dq-row').remove(); toast('Marked as not fraud. Rewards released.'); });
    el.querySelectorAll('[data-unban]').forEach(b => b.onclick = () => { b.textContent = 'Unbanned'; b.disabled = true; toast('Account unbanned. Logged in the audit log.'); });
  };

  // ---------- Router ----------
  const go = () => go_();
  const go_ = () => {
    const id = (location.hash.slice(1) || 'dashboard');
    const fn = P[id] || P.dashboard;
    const page = document.getElementById('page');
    page.innerHTML = `<div class="page">${fn()}</div>`;
    math(page);
    fn.mount && fn.mount(page);
    document.querySelectorAll('.side a[data-p]').forEach(a => a.classList.toggle('on', a.dataset.p === id));
    document.title = (document.querySelector('.page h1')?.textContent || 'Admin') + ' · SolutionTee Admin';
  };
  ST.tokensReady.then(() => {
    addEventListener('hashchange', go); go();
    const sync = () => document.querySelectorAll('#theme button').forEach(b => b.classList.toggle('on', b.dataset.t === ST.getTheme()));
    document.querySelectorAll('#theme button').forEach(b => b.onclick = () => { ST.setTheme(b.dataset.t); sync(); });
    sync();
  });
})();
