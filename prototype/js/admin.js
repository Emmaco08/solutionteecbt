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
        <div class="field"><label>Exams available on Free</label><div class="row g2 wrap">${['JAMB', 'WAEC', 'NECO', 'Post-UTME'].map((e, i) => `<button class="chip ${i ? '' : 'on'}">${e}</button>`).join('')}</div></div>
        <div class="field"><label>Free years</label><div class="row g2 wrap">${[2000, 2001, 2002, 2003, 2004].map((y, i) => `<button class="chip ${i < 3 ? 'on' : ''}">${y}</button>`).join('')}<button class="chip">${I('plus')} Add</button></div></div>
        <div class="field"><label>Study content on Free</label><div class="seg"><button class="on">Items marked free</button><button>Nothing</button><button>Everything</button></div></div>
        <label class="row between t-sm bold"><span>Offline downloads on Free (free content only)</span><span class="switch"><input type="checkbox" checked><span></span></span></label>
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

  // ---------- Router ----------
  const go = () => {
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
