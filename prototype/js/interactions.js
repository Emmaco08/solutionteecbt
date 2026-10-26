/* Shared interactions used by many screens (opt-in with data attributes):
   data-search · .chips.filter + data-subj · data-download · data-bookmark · .seg[data-tabs] + data-panel
   data-remove-row · data-textsize · data-quality. */
(function () {
  const I = ST.icon;

  // ---------- Global search (questions, notes, videos, news, help) ----------
  const INDEX = [
    ['JAMB 2001 Maths Q7: logarithms', 'Past question', 'pq-study', 'year=2001', null, 'exam'],
    ['Quadratic equations', 'Lesson note', 'note', '', 'notes', 'note'],
    ['JAMB 2002 Chemistry Q14: mole concept', 'Video solution', 'video', '', 'videos', 'play-circle'],
    ['Integration', 'Topic drill', 'test-setup', 'body=JAMB&mode=topic&subj=mth&topic=Integration', null, 'target'],
    ['JAMB 2027 registration: dates and fees', 'News', 'news-detail', 'id=reg', null, 'newspaper'],
    ['JAMB syllabus: Mathematics', 'Syllabus', 'docs', '', null, 'file-pdf'],
    ['Weekly Challenge #44', 'Challenge', 'challenge', 'id=wk44', 'compete', 'trophy'],
    ['How is my JAMB score calculated?', 'Help', 'help', '', null, 'question'],
    ['Organic chemistry', 'Topic drill', 'test-setup', 'body=JAMB&mode=topic&subj=chm&topic=Organic%20chemistry', null, 'target'],
    ['Waves and sound', 'Topic video lesson', 'videos', 'kind=lessons', 'lessons', 'chalkboard-teacher']
  ];
  ST.openSearch = () => ST.sheet(`
    <div class="input"><i class="ph ph-magnifying-glass lead-ic"></i><input id="sq" type="search" placeholder="Search questions, topics, notes, news" autocomplete="off" aria-label="Search"></div>
    <div class="chips mt3" id="sRecent">${['logarithm', 'quadratic', 'JAMB 2027', 'mole'].map(r => `<button class="chip" data-r="${r}">${I('clock-counter-clockwise')} ${r}</button>`).join('')}</div>
    <div class="stack mt3" id="sRes"></div>`, {
    mount: w => {
      const inp = w.querySelector('#sq'), res = w.querySelector('#sRes');
      const draw = () => {
        const q = inp.value.trim().toLowerCase();
        const hits = q ? INDEX.filter(x => (x[0] + ' ' + x[1]).toLowerCase().includes(q)) : INDEX.slice(0, 5);
        res.innerHTML = (q ? '' : '<span class="t-label muted" style="margin-bottom:6px">Popular</span>') + (hits.length ? `<div class="card list">${hits.map(([t, k, go, pr, need, ic]) => {
          const locked = need && !ST.can(need);
          return `<button class="list-item" ${locked ? `data-sheet="paywall" data-reason="${need}"` : `data-go="${go}" ${pr ? `data-params="${pr}"` : ''}`}><span class="lead">${I(ic, 1)}</span><span class="grow"><b class="t-sm">${t}</b><div class="t-cap muted">${k}</div></span>${locked ? `<span class="badge badge-neutral">${I('lock-simple', 1)}</span>` : I('caret-right').replace('class="', 'class="trail ')}</button>`;
        }).join('')}</div>` : `<div class="state" style="padding:var(--s-6) 0"><div class="art blue" style="width:72px;height:72px;font-size:32px">${I('magnifying-glass', 1)}</div><b>No results for “${ST.esc(inp.value)}”</b><p class="t-sm muted">Try a topic like “logarithm” or an exam year.</p></div>`);
      };
      inp.oninput = draw;
      w.querySelectorAll('[data-r]').forEach(b => b.onclick = () => { inp.value = b.dataset.r; draw(); inp.focus(); });
      w.addEventListener('click', e => { if (e.target.closest('[data-go],[data-sheet]')) ST.closeOverlay(true); }, true);
      draw(); setTimeout(() => inp.focus(), 80);
    }
  });

  ST.sheets.videoMore = () => ST.sheet(`<h2 class="t-h3">Video options</h2><div class="card list mt4">
    <button class="list-item" data-quality><span class="lead">${I('sliders-horizontal', 1)}</span><span class="grow t-sm bold">Quality</span><span class="t-cap muted">480p</span></button>
    <button class="list-item" data-speed><span class="lead">${I('gauge', 1)}</span><span class="grow t-sm bold">Playback speed</span><span class="t-cap muted" id="spd">1×</span></button>
    <button class="list-item" data-toast="Thanks. Our team will check this video."><span class="lead">${I('flag', 1)}</span><span class="grow t-sm bold">Report a problem</span></button></div>`);

  const QUALITIES = [['240p', 'Uses the least data'], ['480p', 'Recommended with data saver'], ['720p', 'Clear, uses more data']];
  const openQuality = btn => ST.sheet(`<h2 class="t-h3">Video quality</h2><p class="t-sm muted mt2">Lower quality saves data.</p>
    <div class="stack g2 mt4">${QUALITIES.map(([q, d]) => `<button class="plan ${(ST.state.vq || '480p') === q ? 'on' : ''}" data-q="${q}"><span class="radio"></span><span class="grow"><b class="t-sm">${q}</b><br><span class="t-cap muted">${d}</span></span></button>`).join('')}</div>`, {
    mount: w => w.querySelectorAll('[data-q]').forEach(b => b.onclick = () => { ST.state.vq = b.dataset.q; document.querySelectorAll('[data-quality] .t-cap, #q480').forEach(x => x.textContent = b.dataset.q); ST.closeOverlay(); ST.toast(`Quality set to ${b.dataset.q}`, 'sliders-horizontal'); })
  });

  document.addEventListener('click', e => {
    const t = e.target;
    // search
    if (t.closest('[data-search]')) { ST.openSearch(); return; }
    // subject filter chips
    const chip = t.closest('.chips.filter .chip');
    if (chip) {
      const scr = chip.closest('.scr'), f = chip.dataset.f || 'All';
      chip.parentNode.querySelectorAll('.chip').forEach(c => c.classList.toggle('on', c === chip));
      let shown = 0;
      scr.querySelectorAll('[data-subj]').forEach(x => { const ok = f === 'All' || x.dataset.subj === f; x.classList.toggle('hidden', !ok); if (ok) shown++; });
      scr.querySelectorAll('.filter-empty').forEach(x => { x.classList.toggle('hidden', shown > 0); x.querySelector('b') && (x.querySelector('b').textContent = `Nothing for ${f} yet`); });
      return;
    }
    // downloads: Premium only (admin rule "offline")
    const dl = t.closest('[data-download]');
    if (dl) {
      e.preventDefault(); e.stopPropagation();
      if (!ST.can('offline')) { ST.openSheet('paywall', { reason: 'offline' }); return; }
      if (ST.needsNet('Downloading')) return;
      if (dl.dataset.done) { ST.toast('Already saved for offline', 'cloud-check'); return; }
      dl.classList.add('is-loading'); const html = dl.innerHTML; if (dl.classList.contains('btn')) dl.textContent = 'Downloading';
      setTimeout(() => { dl.classList.remove('is-loading'); dl.dataset.done = '1'; dl.innerHTML = dl.classList.contains('btn') ? `${I('cloud-check', 1)} Saved offline` : I('cloud-check', 1); ST.toast(`Saved for offline (${dl.dataset.download || 'encrypted on this phone'})`, 'cloud-check'); }, 1200);
      return;
    }
    // bookmark toggle
    const bm = t.closest('[data-bookmark]');
    if (bm) { const on = bm.classList.toggle('bm-on'); bm.innerHTML = I('bookmark-simple', on); bm.setAttribute('aria-pressed', on); ST.toast(on ? 'Saved to bookmarks' : 'Removed from bookmarks', 'bookmark-simple'); return; }
    // tabbed segments
    const segBtn = t.closest('.seg[data-tabs] button');
    if (segBtn) {
      const seg = segBtn.parentNode, scr = seg.closest('.scr');
      seg.querySelectorAll('button').forEach(b => b.classList.toggle('on', b === segBtn));
      scr.querySelectorAll(`[data-panel^="${seg.dataset.tabs}:"]`).forEach(p => p.classList.toggle('hidden', p.dataset.panel !== `${seg.dataset.tabs}:${segBtn.dataset.v}`));
      return;
    }
    // remove a row (e.g. downloads)
    const rm = t.closest('[data-remove-row]');
    if (rm) { const row = rm.closest('.list-item'); row.style.transition = 'opacity .2s'; row.style.opacity = '0'; setTimeout(() => row.remove(), 200); ST.toast(`Removed. ${rm.dataset.removeRow} freed.`, 'trash'); return; }
    // text size (A → A+ → A++)
    const ts = t.closest('[data-textsize]');
    if (ts) { const body = ts.closest('.scr').querySelector('.note-body'); const steps = [1, 1.12, 1.25]; const i = (steps.indexOf(+(body.dataset.scale || 1)) + 1) % steps.length; body.dataset.scale = steps[i]; body.style.fontSize = (16 * steps[i]) + 'px'; body.style.lineHeight = (27 * steps[i]) + 'px'; ST.toast(['Normal text', 'Bigger text', 'Biggest text'][i], 'text-aa'); return; }
    // video quality / speed
    if (t.closest('[data-quality]')) { ST.closeOverlay(true); openQuality(); return; }
    const sp = t.closest('[data-speed]');
    if (sp) { const speeds = ['1×', '1.25×', '1.5×', '0.75×']; const cur = sp.querySelector('#spd'); cur.textContent = speeds[(speeds.indexOf(cur.textContent) + 1) % speeds.length]; return; }
  });
})();
