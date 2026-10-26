/* Home, Study (and sub-screens), Test hub. */
(function () {
  const { def, icon: I, examLogo, mark } = ST;
  const S = ST.state;

  const ring = (pct, size = 64, stroke = 3.6, label = '') => {
    const r = 15, c = 2 * Math.PI * r;
    return `<div class="ring" style="--size:${size}px;--stroke:${stroke}"><svg viewBox="0 0 36 36"><circle class="track" cx="18" cy="18" r="${r}"/><circle class="val" cx="18" cy="18" r="${r}" stroke-dasharray="${c.toFixed(1)}" stroke-dashoffset="${c.toFixed(1)}" data-off="${(c * (1 - pct)).toFixed(1)}"/></svg><span class="ring-label">${label}</span></div>`;
  };
  ST.ring = ring;
  ST.animateRings = el => requestAnimationFrame(() => setTimeout(() => el.querySelectorAll('.ring .val[data-off]').forEach(v => v.style.strokeDashoffset = v.dataset.off), 80));
  ST.animateBars = el => requestAnimationFrame(() => setTimeout(() => el.querySelectorAll('.bar > i[data-v]').forEach(b => b.style.width = b.dataset.v), 80));
  const lockBadge = `<span class="badge badge-neutral">${I('lock-simple', 1)} Premium</span>`;
  /** Attributes for a link to a gated feature: opens it when the plan allows, otherwise the paywall. */
  const gate = (key, attrs, reason) => ST.can(key) ? attrs : `data-sheet="paywall" data-reason="${reason || key}"`;
  const tileLock = key => ST.can(key) ? '' : `<span class="tile-lock" aria-label="Premium">${I('lock-simple', 1)}</span>`;
  ST.gate = gate;
  /** Exam card: open for JAMB on Free, and for every exam on Premium; otherwise opens the paywall. */
  const examCard = (body, title, meta) => {
    const open = ST.examOpen(body), n = ST.rule(body.toLowerCase());
    const yrs = '';
    return `<button class="card card-tap exam-card ${open ? '' : 'locked'}" ${open ? `data-go="test-setup" data-params="body=${body}"` : `data-sheet="paywall" data-reason="${body}"`}>${examLogo(body)}<div class="meta"><b>${title}</b>${yrs}<div class="t-cap muted">${meta}</div></div>${open ? `<span class="go">${I('play', 1)}</span>` : lockBadge}</button>`;
  };
  ST.examCard = examCard;

  // ---------- Home ----------
  ST.greeting = () => { const h = new Date().getHours(); return h < 12 ? 'Good morning' : h < 17 ? 'Good afternoon' : 'Good evening'; };
  const NOTES = [['trophy', 'gold', 'Weekly Challenge #44 is live', 'Win ₦20,000. Closes tonight.', 'challenge', 'id=wk44', '2 min ago'],
    ['newspaper', 'blue', 'JAMB 2027 registration dates are out', 'Read what to bring and the fees.', 'news-detail', 'id=reg', '1 h ago'],
    ['video-camera', 'navy', 'Live class today at 4:00 PM', 'Physics: Waves and sound with Mr. Bello.', '', '', '3 h ago'],
    ['fire', 'gold', 'Keep your 6-day streak', 'Answer 8 more questions today.', 'test', '', 'Yesterday']];
  ST.sheets.notifications = () => ST.sheet(`<div class="row between"><h2 class="t-h3">Notifications</h2><button class="btn btn-ghost btn-sm" data-close data-toast="All marked as read">Mark all read</button></div>
    <div class="card list mt3">${NOTES.map(([ic, c, t, d, go, pr, when], i) => `<button class="list-item" ${go ? `data-go="${go}" ${pr ? `data-params="${pr}"` : ''}` : 'data-toast="We will remind you at 3:55 PM"'}><span class="ic ${c}" style="width:40px;height:40px;border-radius:10px;display:grid;place-items:center;font-size:20px;flex:none">${I(ic, 1)}</span>
      <span class="grow"><b class="t-sm">${t}</b><div class="t-cap muted">${d}</div><div class="t-cap subtle">${when}</div></span>${i < 2 ? '<span class="unread-dot" aria-label="Unread"></span>' : ''}</button>`).join('')}</div>
    <button class="btn btn-ghost btn-block mt3" data-close data-go="settings">Notification settings</button>`, {
    mount: w => w.addEventListener('click', e => { if (e.target.closest('[data-go]')) ST.closeOverlay(true); }, true)
  });

  def('home', {
    title: 'Home', group: 'Main tabs', tab: 'home',
    render: () => {
      const lb = ST.lbSettings && ST.lbSettings().on;
      const tile = (go, ic, c, title, sub, extra = '') => `<button class="card card-tap quick-tile" ${go}><span class="ic ${c}">${I(ic, 1)}</span><b class="t-sm">${title}</b><span class="t-cap muted">${sub}</span>${extra}</button>`;
      return `
      <div class="scr-body">
        <div class="home-head">
          <button data-go="profile" aria-label="Open my profile" style="border-radius:50%">${ST.avatar()}</button>
          <div class="grow"><div class="t-cap muted">${ST.greeting()},</div><div class="t-h3">${S.first}</div></div>
          <span class="streak" title="${S.streak}-day streak">${I('fire', 1)} ${S.streak}</span>
          <button class="icon-btn bell" aria-label="Notifications${ST.unreadCount && ST.unreadCount() ? `, ${ST.unreadCount()} unread` : ''}" data-go="notifications">${I('bell')}${ST.unreadCount && ST.unreadCount() ? `<span class="bell-count tnum">${ST.unreadCount()}</span>` : ''}</button>
        </div>
        <div class="px5 stack g5" style="padding-bottom:var(--s-8)">
          <div class="goal-strip enter">${ring(0.6, 44, 3.6, '')}<span class="grow"><b class="t-sm">Today: 12 of 20 questions</b><span class="t-cap muted" style="display:block">8 more keeps your ${S.streak}-day streak</span></span><button class="btn btn-tonal btn-sm" data-go="test-setup" data-params="body=JAMB&mode=quick">Practise</button></div>

          ${ST.unfinishedCard ? ST.unfinishedCard() : ''}

          ${ST.challengeSection ? ST.challengeSection() : ''}

          <section data-tour="start">
            <div class="sect-title"><h2 class="t-h3">Start a CBT practice</h2>${ST.isPremium() ? `<span class="badge badge-gold">${I('crown-simple', 1)} Premium</span>` : ''}</div>
            <div class="stack g2 enter">
              ${examCard('JAMB', 'JAMB UTME', '4 subjects · 180 questions · 2 hrs')}
              ${examCard('WAEC', 'WAEC WASSCE', 'Objective papers by subject')}
              ${examCard('NECO', 'NECO SSCE', 'Objective papers by subject')}
            </div>
          </section>

          ${ST.qotdCard ? ST.qotdCard() : ''}

          <section>
            <div class="sect-title"><h2 class="t-h3">News</h2><button class="btn btn-ghost" data-go="news">See all</button></div>
            <div class="news">${ST.allNews ? ST.allNews().slice(0, 4).map(ST.newsCard).join('') : ''}</div>
          </section>

          <section>
            <div class="sect-title"><h2 class="t-h3">More for you</h2></div>
            <div class="grid2 quick-grid">
              ${lb ? tile('data-go="leaderboard"', 'ranking', 'gold', 'Leaderboard', 'You are #128') : tile('data-go="compete"', 'trophy', 'gold', 'Challenges', 'Win prizes')}
              ${tile('data-go="referral"', 'gift', 'green', 'Invite friends', `${ST.refRules ? ST.refRules().step : 10}% off per friend`)}
              ${tile('data-go="winners-wall"', 'seal-check', 'blue', 'Winners wall', 'Proof we pay')}
              ${tile('data-toast="We will remind you at 3:55 PM"', 'video-camera', 'navy', 'Live class 4:00 PM', 'Physics: Waves')}
            </div>
          </section>

          ${ST.isPremium() ? '' : `<div class="upgrade-banner" data-tour="upgrade">
            <div class="crown">${I('crown-simple', 1)}</div>
            <div class="grow" style="position:relative;z-index:1"><b>Get every year and every lesson</b><p class="t-sm" style="color:#AFC0DD">Videos, notes, novels, offline downloads and 100 AI prompts a day.</p></div>
            <button class="btn btn-accent btn-sm" data-sheet="paywall" style="position:relative;z-index:1">Upgrade</button>
          </div>`}
        </div>
      </div>`;
    },
    mount(el) {
      ST.animateRings(el); ST.animateBars(el);
      ST.mountQotd && ST.mountQotd(el);
    }
  });

  // ---------- Study hub ----------
  def('study', {
    title: 'Study', group: 'Main tabs', tab: 'study',
    render: () => `
      <div class="appbar"><span class="title" style="padding-left:12px;font-size:var(--t-h2-size)">Study</span><button class="icon-btn" aria-label="Search" data-search>${I('magnifying-glass')}</button><button class="icon-btn" aria-label="Downloads" ${gate('offline', 'data-go="offline"', 'offline')}>${I('download-simple')}</button></div>
      <div class="scr-body"><div class="pad stack g6" style="padding-top:var(--s-2)">
        <button class="search-field" data-search>${I('magnifying-glass')}<span>Search questions, topics, notes</span></button>
        <div class="grid2 enter">
          <button class="card card-tap study-tile" data-go="pq"><span class="ic navy">${I('exam', 1)}</span><span><b>Past questions</b><br><span class="t-cap muted">Study mode with answers</span></span></button>
          <button class="card card-tap study-tile" ${gate('videos', 'data-go="videos"', 'video')}>${tileLock('videos')}<span class="ic blue">${I('play-circle', 1)}</span><span><b>Video solutions</b><br><span class="t-cap muted">Watch each answer</span></span></button>
          <button class="card card-tap study-tile" ${gate('lessons', 'data-go="videos" data-params="kind=lessons"', 'lessons')}>${tileLock('lessons')}<span class="ic green">${I('chalkboard-teacher', 1)}</span><span><b>Topic lessons</b><br><span class="t-cap muted">By syllabus topic</span></span></button>
          <button class="card card-tap study-tile" ${gate('notes', 'data-go="note"', 'notes')}>${tileLock('notes')}<span class="ic gold">${I('note', 1)}</span><span><b>Lesson notes</b><br><span class="t-cap muted">Read, with formulas</span></span></button>
          <button class="card card-tap study-tile" ${gate('novels', 'data-go="novels"', 'novel')}>${tileLock('novels')}<span class="ic red">${I('books', 1)}</span><span><b>Novels</b><br><span class="t-cap muted">JAMB literature texts</span></span></button>
          <button class="card card-tap study-tile" data-go="docs"><span class="ic navy">${I('file-pdf', 1)}</span><span><b>Syllabus & brochure</b><br><span class="t-cap muted">${ST.rule('syllabus') === 'all' ? 'JAMB, WAEC, NECO' : ST.rule('syllabus') + ' free on your plan'}</span></span></button>
        </div>
        <section>
          <div class="sect-title"><h2 class="t-h3">Continue learning</h2></div>
          <div class="chips filter" style="margin-bottom:var(--s-3)">${['All', 'Mathematics', 'Chemistry', 'Physics', 'English'].map((c, i) => `<button class="chip ${i ? '' : 'on'}" data-f="${c}">${c}</button>`).join('')}</div>
          <div class="card list">
            <button class="list-item" data-subj="Mathematics" ${gate('notes', 'data-go="note"', 'notes')}><span class="lead">${I('note', 1)}</span><span class="grow"><b class="t-sm">Quadratic equations</b><div class="bar mt2" style="height:6px"><i data-v="64%"></i></div></span><span class="t-cap muted">64%</span></button>
            <button class="list-item" data-subj="Chemistry" ${gate('videos', 'data-go="video"', 'video')}><span class="lead" style="background:var(--c-secondary-soft);color:var(--c-on-secondary-soft)">${I('play', 1)}</span><span class="grow"><b class="t-sm">JAMB 2002 Chemistry Q14</b><div class="t-cap muted">Video solution · 4:38</div></span>${I('caret-right').replace('class="', 'class="trail ')}</button>
            <button class="list-item" data-subj="Physics" data-go="test-setup" data-params="body=JAMB&mode=topic&subj=phy&topic=Motion"><span class="lead" style="background:var(--c-accent-soft);color:var(--c-on-accent-soft)">${I('target', 1)}</span><span class="grow"><b class="t-sm">Topic drill: Motion</b><div class="t-cap muted">Physics · 6 of 20 done</div></span>${I('caret-right').replace('class="', 'class="trail ')}</button>
            <div class="filter-empty hidden state" style="padding:var(--s-5)"><b>Nothing here yet</b><span class="t-cap muted">Start a lesson or drill in this subject and it shows here.</span></div>
          </div>
        </section>
        <section>
          <div class="sect-title"><h2 class="t-h3">Bookmarks</h2><button class="btn btn-ghost" data-go="bookmarks">View all</button></div>
          <div class="card list">
            <button class="list-item" data-go="pq-study"><span class="lead">${I('bookmark-simple', 1)}</span><span class="grow"><b class="t-sm">JAMB 2001 Maths Q7</b><div class="t-cap muted">Indices and logarithms</div></span>${I('caret-right').replace('class="', 'class="trail ')}</button>
          </div>
        </section>
      </div></div>`,
    mount: el => ST.animateBars(el)
  });

  // ---------- Past questions: exam → subject → year ----------
  def('pq', {
    title: 'Past questions (browse)', group: 'Study',
    render: () => `
      <div class="appbar"><button class="icon-btn" data-back="study" aria-label="Back">${I('arrow-left')}</button><span class="title">Past questions</span></div>
      <div class="scr-body"><div class="pad stack g5" style="padding-top:var(--s-2)">
        <div class="seg" id="bodySeg">${['JAMB', 'WAEC', 'NECO'].map(b => `<button class="${b === (ST.pqBody || 'JAMB') ? 'on' : ''}" data-b="${b}">${b}${ST.examOpen(b) ? '' : ' ' + I('lock-simple', 1)}</button>`).join('')}</div>
        <div class="field"><span class="field-label">Subject</span><div class="input"><i class="ph ph-function lead-ic"></i><select><option>Mathematics</option><option>Use of English</option><option>Physics</option><option>Chemistry</option><option>Biology</option></select><i class="ph ph-caret-down sel-caret"></i></div></div>
        <div>
          <div class="sect-title"><h2 class="t-h3">Choose a year</h2>${ST.rule('pq') === 'all' ? `<span class="badge badge-gold">${I('crown-simple', 1)} All years open</span>` : `<span class="t-cap muted">${I('lock-simple', 1)} = Premium</span>`}</div>
          <div class="year-grid enter">
            ${ST.YEARS.map((y, k) => ST.yearOpen(ST.pqBody || 'JAMB', y, 'pq')
              ? `<button class="year ${k === 0 ? 'done' : ''}" data-go="pq-study" data-params="year=${y}">${y}</button>`
              : `<button class="year locked" data-sheet="paywall" data-reason="${y}">${y}<i class="ph-fill ph-lock-simple lk"></i></button>`).join('')}
          </div>
        </div>
        ${ST.rule('pq') === 'all' ? '' : `<div class="banner info">${I('info', 1)}<span>Your plan includes ${ST.yearsLabel(ST.rule('pq'))} of study-mode past questions per exam (${ST.openYears(ST.pqBody || 'JAMB', 'pq').join(', ')}). Upgrade to open every year.</span></div>`}
      </div></div>`,
    mount(el) {
      el.querySelectorAll('#bodySeg button').forEach(b => b.onclick = () => {
        if (!ST.examOpen(b.dataset.b)) { ST.openSheet('paywall', { reason: b.dataset.b }); return; }
        ST.pqBody = b.dataset.b; ST.go('pq', null, { mode: 'fade', replace: true });
      });
    }
  });

  const PQS = [
    { topic: 'Indices & logarithms', lvl: 'Medium', q: 'If $\\log_{10} 2 = 0.3010$ and $\\log_{10} 3 = 0.4771$, evaluate $\\log_{10} 4.5$.', o: ['$0.6532$', '$0.6990$', '$0.6543$', '$0.7781$'], a: 0,
      exp: '<p>Write $4.5$ using $2$ and $3$: $$4.5 = \\frac{9}{2} = \\frac{3^2}{2}$$</p><p>So $\\log_{10} 4.5 = 2\\log_{10} 3 - \\log_{10} 2 = 0.6532$.</p>', ai: 'log' },
    { topic: 'Quadratic equations', lvl: 'Easy', q: 'Find the roots of $x^2 - 7x + 12 = 0$.', o: ['$3$ and $4$', '$-3$ and $-4$', '$2$ and $6$', '$1$ and $12$'], a: 0,
      exp: '<p>Two numbers that multiply to $12$ and add to $7$ are $3$ and $4$, so $(x-3)(x-4)=0$.</p>', ai: 'default' },
    { topic: 'Probability', lvl: 'Medium', q: 'A die is thrown once. What is the probability of getting an even number?', o: ['$\\frac{1}{6}$', '$\\frac{1}{3}$', '$\\frac{1}{2}$', '$\\frac{2}{3}$'], a: 2,
      exp: '<p>Even numbers: $2, 4, 6$, so $3$ out of $6$ outcomes: $\\frac{3}{6} = \\frac{1}{2}$.</p>', ai: 'default' }
  ];
  def('pq-study', {
    title: 'Past question (study mode)', group: 'Study',
    render: p => {
      const n = Math.max(1, +(p.n || 7)), q = PQS[(n - 1) % PQS.length];
      return `
      <div class="appbar lined"><button class="icon-btn" data-back="pq" aria-label="Back">${I('arrow-left')}</button>
        <span class="title">JAMB ${p.year || 2001} Mathematics<small>Study mode · Question ${n} of 50</small></span>
        <button class="icon-btn" data-bookmark aria-label="Bookmark" aria-pressed="false">${I('bookmark-simple')}</button></div>
      <div class="scr-body"><div class="pad stack g4">
        <div class="row g2"><span class="badge badge-soft">${q.topic}</span><span class="badge badge-neutral">${q.lvl}</span></div>
        <p class="q-text" style="margin:0">${q.q}</p>
        <div class="opts" id="opts">${q.o.map((o, k) => `<button class="opt" data-ok="${k === q.a}"><span class="key">${'ABCD'[k]}</span><span>${o}</span></button>`).join('')}</div>
        <div id="exp" class="hidden stack g3">
          <div class="explain"><b>Explanation</b><div class="mt2">${q.exp}</div></div>
          <div class="row g2"><button class="btn btn-tonal btn-sm grow" ${gate('videos', 'data-go="video"', 'video')}>${I(ST.can('videos') ? 'play-circle' : 'lock-simple', 1)} Watch solution</button><button class="btn btn-outline btn-sm grow" data-go="ai" data-params="q=${q.ai}">${I('sparkle', 1)} Ask AI</button></div>
        </div>
      </div></div>
      <div class="cbt-bottom"><button class="btn btn-outline btn-sm" id="pqPrev" ${n === 1 ? 'disabled' : ''}>${I('caret-left')} Prev</button><span class="t-cap muted tnum">${n} / 50</span><button class="btn btn-primary btn-sm" id="pqNext" ${n === 50 ? 'disabled' : ''}>Next ${I('caret-right')}</button></div>`;
    },
    mount(el, p) {
      const n = Math.max(1, +(p.n || 7));
      el.querySelectorAll('#opts .opt').forEach(b => b.onclick = () => {
        el.querySelectorAll('#opts .opt').forEach(o => { o.disabled = true; if (o.dataset.ok === 'true') { o.classList.add('right'); o.insertAdjacentHTML('beforeend', `<span class="tag" style="color:var(--c-on-success-soft)">Correct answer</span>`); } });
        if (b.dataset.ok !== 'true') { b.classList.add('wrong'); b.insertAdjacentHTML('beforeend', `<span class="tag" style="color:var(--c-on-error-soft)">Your answer</span>`); }
        const ex = el.querySelector('#exp'); ex.classList.remove('hidden'); ex.classList.add('pop'); setTimeout(() => ex.scrollIntoView({ behavior: 'smooth', block: 'nearest' }), 50);
      });
      el.querySelector('#pqPrev').onclick = () => ST.go('pq-study', { ...p, n: n - 1 }, { replace: true, mode: 'fade' });
      el.querySelector('#pqNext').onclick = () => ST.go('pq-study', { ...p, n: n + 1 }, { replace: true, mode: 'fade' });
    }
  });

  // ---------- Videos ----------
  const vids = [['th-1', 'JAMB 2002 Chemistry Q14', 'Mole concept', '4:38', 0, 'flask'], ['th-2', 'JAMB 2001 Physics Q3', 'Motion', '6:12', 0, 'atom'], ['th-3', 'JAMB 2015 Maths Q22', 'Probability', '7:05', 1, 'function'], ['th-4', 'JAMB 2019 Biology Q9', 'Genetics', '5:40', 1, 'dna']];
  def('videos', {
    title: 'Video solutions / lessons', group: 'Study', needs: p => p.kind === 'lessons' ? 'lessons' : 'videos',
    render: p => `
      <div class="appbar"><button class="icon-btn" data-back="study" aria-label="Back">${I('arrow-left')}</button><span class="title">${p.kind === 'lessons' ? 'Topic lessons' : 'Video solutions'}</span><button class="icon-btn" aria-label="Search" data-search>${I('magnifying-glass')}</button></div>
      <div class="scr-body"><div class="pad stack g4" style="padding-top:var(--s-2)">
        <div class="chips filter">${['All', 'Mathematics', 'Physics', 'Chemistry', 'Biology'].map((c, i) => `<button class="chip ${i ? '' : 'on'}" data-f="${c}">${i ? c : 'All subjects'}</button>`).join('')}</div>
        <div class="banner warn">${I('cell-signal-low', 1)}<span><b>Data saver is on.</b> Videos play in low quality. Download on Wi-Fi to watch offline.</span></div>
        <div class="stack g4 enter">${vids.map(([th, t, topic, d, lk, ic]) => { const lock = false; return `
          <button class="card card-tap" style="padding:10px" data-subj="${{ flask: 'Chemistry', atom: 'Physics', function: 'Mathematics', dna: 'Biology' }[ic]}" ${lock ? `data-sheet="paywall" data-reason="video"` : 'data-go="video"'}>
            <div class="thumb ${th}"><i class="ph-fill ph-${ic} sub-ic"></i><span class="play">${I(lock ? 'lock-simple' : 'play', 1)}</span><span class="dur">${d}</span>${lock ? `<span class="lock-chip badge badge-gold">${I('crown-simple', 1)} Premium</span>` : ''}</div>
            <div class="row between" style="padding:10px 4px 2px"><div><b class="t-sm">${t}</b><div class="t-cap muted">${topic}</div></div>${lock ? '' : `<span class="icon-btn" role="button" aria-label="Download" data-download="${d === '4:38' ? '18 MB' : '22 MB'}">${I('download-simple')}</span>`}</div>
          </button>`; }).join('')}</div>
      </div></div>`
  });

  def('video', {
    title: 'Video player', group: 'Study', needs: 'videos',
    render: () => `
      <div class="appbar"><button class="icon-btn" data-back="videos" aria-label="Back">${I('arrow-left')}</button><span class="title">Video solution</span><button class="icon-btn" aria-label="More options" data-sheet="videoMore">${I('dots-three-vertical')}</button></div>
      <div class="thumb th-1" style="border-radius:0;flex:none"><i class="ph-fill ph-flask sub-ic"></i><span class="play" style="width:60px;height:60px;font-size:26px">${I('play', 1)}</span>
        <div style="position:absolute;left:12px;right:12px;bottom:10px"><div class="bar" style="height:4px;background:rgba(255,255,255,.25)"><i data-v="32%" style="background:var(--gold-400)"></i></div><div class="row between t-cap" style="margin-top:6px;color:#fff"><span>1:29</span><span>4:38</span></div></div></div>
      <div class="scr-body"><div class="pad stack g4">
        <div><h1 class="t-h2">JAMB 2002 Chemistry Q14</h1><p class="t-sm muted mt2">Mole concept · Mrs. Okonkwo · 4:38</p></div>
        <div class="row g2"><button class="btn btn-tonal btn-sm" data-download="18 MB">${I('download-simple')} Download (18 MB)</button><button class="btn btn-outline btn-sm" data-quality>${I('sliders-horizontal')} <span id="q480">${ST.state.vq || '480p'}</span></button></div>
        <div class="card card-pad"><b class="t-sm">The question</b><p class="mt2">How many moles are in $4.4\\,\\text{g}$ of $\\text{CO}_2$? $(\\text{C}=12, \\text{O}=16)$</p></div>
        <div class="card card-pad"><b class="t-sm">Key working</b><p class="mt2">$$n = \\frac{m}{M} = \\frac{4.4}{44} = 0.1\\ \\text{mol}$$</p></div>
      </div></div>`,
    mount: el => ST.animateBars(el)
  });

  // ---------- Lesson note with LaTeX ----------
  def('note', {
    title: 'Lesson note (LaTeX)', group: 'Study', needs: 'notes',
    render: () => `
      <div class="read-progress"><i id="rp"></i></div>
      <div class="appbar lined"><button class="icon-btn" data-back="study" aria-label="Back">${I('arrow-left')}</button><span class="title">Quadratic equations<small>Mathematics · 8 min read</small></span>
        <button class="icon-btn" aria-label="Text size" data-textsize>${I('text-aa')}</button><button class="icon-btn" aria-label="Download for offline" data-download="1.1 MB">${I('download-simple')}</button></div>
      <div class="scr-body" id="noteScroll"><article class="pad note-body">
        <p>A quadratic equation has the form $ax^2 + bx + c = 0$, where $a \\neq 0$. JAMB asks at least two questions on this topic every year.</p>
        <h2>1. The quadratic formula</h2>
        <p>Use this when the equation does not factorise easily:</p>
        $$x = \\frac{-b \\pm \\sqrt{b^2 - 4ac}}{2a}$$
        <div class="callout"><b>Exam tip.</b> Before you solve, check the discriminant $b^2 - 4ac$. If it is negative, there are no real roots, and you can pick the option that says so in seconds.</div>
        <h2>2. Sum and product of roots</h2>
        <p>If the roots are $\\alpha$ and $\\beta$, then</p>
        $$\\alpha + \\beta = -\\frac{b}{a}, \\qquad \\alpha\\beta = \\frac{c}{a}$$
        <h2>3. Nature of the roots</h2>
        <table><thead><tr><th>Discriminant</th><th>Roots</th></tr></thead><tbody>
          <tr><td>$b^2-4ac > 0$</td><td>Two different real roots</td></tr>
          <tr><td>$b^2-4ac = 0$</td><td>Two equal roots</td></tr>
          <tr><td>$b^2-4ac < 0$</td><td>No real roots</td></tr></tbody></table>
        <h2>Worked example</h2>
        <p>Solve $2x^2 - 7x + 3 = 0$.</p>
        <p>Here $a=2$, $b=-7$, $c=3$, so $b^2-4ac = 49 - 24 = 25$.</p>
        $$x = \\frac{7 \\pm 5}{4} \\;\\Rightarrow\\; x = 3 \\text{ or } x = \\tfrac{1}{2}$$
        <div class="card card-pad stack g3 mt6" style="font-size:15px;line-height:22px">
          <b>Check yourself</b><p class="muted t-sm">Try 5 quick questions on this note.</p>
          <button class="btn btn-primary btn-block" data-go="test-setup" data-params="body=JAMB&mode=topic&subj=mth&topic=Quadratic%20equations">Start topic drill</button>
        </div>
      </article></div>`,
    mount(el) {
      const sc = el.querySelector('#noteScroll'), rp = el.querySelector('#rp');
      sc.addEventListener('scroll', () => { rp.style.width = (sc.scrollTop / (sc.scrollHeight - sc.clientHeight) * 100) + '%'; }, { passive: true });
    }
  });

  // ---------- Novels ----------
  def('novels', {
    title: 'Novels', group: 'Study', needs: 'novels',
    render: () => `
      <div class="appbar"><button class="icon-btn" data-back="study" aria-label="Back">${I('arrow-left')}</button><span class="title">Recommended novels</span></div>
      <div class="scr-body"><div class="pad stack g5" style="padding-top:var(--s-2)">
        <div class="banner warn">${I('info', 1)}<span><b>SAMPLE.</b> The featured JAMB novel is not chosen yet. Titles below are placeholders.</span></div>
        <button class="card card-tap row g4" style="padding:var(--s-4);align-items:stretch" data-go="novel">
          <div class="cover c1" style="width:96px;flex:none"><b>Novel title (TBC)</b></div>
          <div class="stack g2 grow"><span class="badge badge-gold" style="align-self:flex-start">JAMB 2027 text</span><b>Featured JAMB novel</b><span class="t-cap muted">Summary · themes · characters · 12 chapter quizzes</span>
            <div class="bar mt2"><i data-v="25%"></i></div><span class="t-cap muted">3 of 12 chapters done</span></div>
        </button>
        <div class="sect-title" style="margin:0"><h2 class="t-h3">More texts</h2></div>
        <div class="grid3 enter">
          <button class="stack g2" data-go="novel"><div class="cover c2"><b>Prose text</b></div><span class="t-cap bold" style="text-align:left">WAEC prose</span></button>
          <button class="stack g2" data-go="novel"><div class="cover c3" style="color:var(--navy-900)"><b>Drama text</b></div><span class="t-cap bold" style="text-align:left">WAEC drama</span></button>
          <button class="stack g2" data-go="novel"><div class="cover c1"><b>Poetry</b></div><span class="t-cap bold" style="text-align:left">Selected poems</span></button>
        </div>
      </div></div>`,
    mount: el => ST.animateBars(el)
  });

  def('novel', {
    title: 'Novel detail', group: 'Study', needs: 'novels',
    render: () => `
      <div class="appbar"><button class="icon-btn" data-back="novels" aria-label="Back">${I('arrow-left')}</button><span class="title">Featured novel</span><button class="icon-btn" aria-label="Bookmark" data-bookmark>${I('bookmark-simple')}</button></div>
      <div class="scr-body"><div class="pad stack g5" style="padding-top:var(--s-2)">
        <div class="row g4"><div class="cover c1" style="width:88px;flex:none"><b>Novel (TBC)</b></div><div class="stack g1"><span class="badge badge-sample" style="align-self:flex-start">SAMPLE</span><h1 class="t-h2">Featured JAMB novel</h1><span class="t-sm muted">Author name · 12 chapters</span></div></div>
        <div class="seg" data-tabs="nv">${['Chapters', 'Themes', 'Characters', 'Quizzes'].map((t, i) => `<button class="${i ? '' : 'on'}" data-v="${t}">${t}</button>`).join('')}</div>
        <div class="card list" data-panel="nv:Chapters">${Array.from({ length: 6 }, (_, k) => `
          <button class="list-item" data-toast="Opens the chapter ${k + 1} summary"><span class="lead" style="${k < 3 ? 'background:var(--c-success-soft);color:var(--c-on-success-soft)' : ''}">${k < 3 ? I('check', 1) : k + 1}</span>
            <span class="grow"><b class="t-sm">Chapter ${k + 1}</b><div class="t-cap muted">${k < 3 ? 'Read · quiz 4/5' : 'Summary · 5-question quiz'}</div></span>${I('caret-right').replace('class="', 'class="trail ')}</button>`).join('')}</div>
        <div class="stack g3 hidden" data-panel="nv:Themes">${[['Ambition and its cost', 'How the main character’s drive helps and hurts the people around them.'], ['Family and duty', 'What the characters owe their families, and what they choose.'], ['Change in society', 'Old ways meeting new ones in a growing town.']].map(([t, d]) => `<div class="card card-pad"><b class="t-sm">${t}</b><p class="t-sm muted mt2">${d}</p></div>`).join('')}<p class="t-cap subtle">Sample themes until the real novel is chosen.</p></div>
        <div class="card list hidden" data-panel="nv:Characters">${[['Main character', 'Determined, proud, learns to listen'], ['The mentor', 'Wise, patient, tests the hero'], ['The rival', 'Clever, jealous, changes by the end']].map(([n, d]) => `<div class="list-item"><span class="avatar" style="width:40px;height:40px;font-size:14px">${n[0]}</span><span class="grow"><b class="t-sm">${n}</b><div class="t-cap muted">${d}</div></span></div>`).join('')}</div>
        <div class="card list hidden" data-panel="nv:Quizzes">${Array.from({ length: 4 }, (_, k) => `<button class="list-item" data-toast="Starts the chapter ${k + 1} quiz"><span class="lead">${I('list-checks', 1)}</span><span class="grow"><b class="t-sm">Chapter ${k + 1} quiz</b><div class="t-cap muted">${k < 3 ? 'Best score 4/5' : 'Not taken yet'}</div></span><span class="btn btn-tonal btn-sm" style="pointer-events:none">${k < 3 ? 'Retry' : 'Start'}</span></button>`).join('')}</div>
      </div></div>`
  });

  // ---------- Document (PDF) viewer ----------
  def('doc', {
    title: 'Syllabus / brochure viewer', group: 'Study',
    render: () => `
      <div class="appbar lined"><button class="icon-btn" data-back="docs" aria-label="Back">${I('arrow-left')}</button><span class="title">JAMB syllabus: Mathematics<small>PDF · 24 pages · 1.2 MB</small></span><button class="icon-btn" aria-label="Download for offline" data-download="1.2 MB">${I('download-simple')}</button></div>
      <div class="row g2 px4" style="padding-block:10px;background:var(--c-surface);border-bottom:1px solid var(--c-border)">
        <div class="seg grow" style="max-width:220px"><button class="on">PDF</button><button id="topicsBtn">Topic list</button></div>
        <span class="grow"></span><span class="t-cap muted tnum">Page 3 / 24</span></div>
      <div class="scr-body pdf" id="pdfv">
        ${[1, 2].map(n => `<div class="pdf-page"><h4>${n === 1 ? 'SECTION I: NUMBER AND NUMERATION' : 'SECTION II: ALGEBRA'}</h4>
          <p style="margin-bottom:6px"><b>Topics:</b> ${n === 1 ? 'Number bases, fractions, decimals, indices, logarithms, surds, sets.' : 'Polynomials, variation, inequalities, progressions, binary operations, matrices.'}</p>
          ${Array.from({ length: 16 }, (_, k) => `<div class="ln" style="width:${60 + ((k * 37) % 40)}%"></div>`).join('')}</div>`).join('')}
      </div>
      <div class="hidden scr-body" id="topics"><div class="pad"><div class="card list">${['Number bases', 'Fractions, decimals, approximations', 'Indices, logarithms and surds', 'Sets', 'Polynomials', 'Variation', 'Inequalities', 'Progressions'].map((t, k) => `<button class="list-item" data-topic-page="${k * 3 + 1}"><span class="lead">${k + 1}</span><span class="grow"><b class="t-sm">${t}</b><div class="t-cap muted">Page ${k * 3 + 1}</div></span>${I('caret-right').replace('class="', 'class="trail ')}</button>`).join('')}</div></div></div>`,
    mount(el) {
      const [a, b] = el.querySelectorAll('.seg button');
      a.onclick = () => { a.classList.add('on'); b.classList.remove('on'); el.querySelector('#pdfv').classList.remove('hidden'); el.querySelector('#topics').classList.add('hidden'); };
      b.onclick = () => { b.classList.add('on'); a.classList.remove('on'); el.querySelector('#pdfv').classList.add('hidden'); el.querySelector('#topics').classList.remove('hidden'); };
      el.querySelectorAll('[data-topic-page]').forEach(t => t.onclick = () => { a.click(); el.querySelector('.t-cap.tnum').textContent = `Page ${t.dataset.topicPage} / 24`; el.querySelector('#pdfv').scrollTop = 0; ST.toast(`Jumped to page ${t.dataset.topicPage}`, 'file-text'); });
    }
  });

  // ---------- Test hub ----------
  def('test', {
    title: 'Test hub', group: 'Main tabs', tab: 'test',
    render: () => `
      <div class="appbar"><span class="title" style="padding-left:12px;font-size:var(--t-h2-size)">Test</span><button class="icon-btn" aria-label="Test history" data-go="history">${I('clock-counter-clockwise')}</button></div>
      <div class="scr-body"><div class="pad stack g6" style="padding-top:var(--s-2)">
        <div class="card surface-navy card-pad stack g3" style="position:relative;overflow:hidden">
          <div class="row g3">${examLogo('JAMB', 'bare')}<div class="grow"><b>Full JAMB simulation</b><div class="t-cap muted">English + 3 subjects · 180 questions · 2 hours</div></div></div>
          <button class="btn btn-accent btn-block" data-go="test-setup" data-params="body=JAMB">Start full exam</button>
        </div>
        <section><div class="sect-title"><h2 class="t-h3">Practice modes</h2></div>
          <div class="stack g2 enter">
            ${[['book-open-text', 'navy', 'Single subject', 'One subject, timed like the real paper', 'test-setup', 'body=JAMB&mode=subject'],
               ['target', 'blue', 'Topic drill', 'Practise your weak topics only', 'test-setup', 'body=JAMB&mode=topic'],
               ['lightning', 'gold', 'Quick test', '20 questions · 15 minutes', 'test-setup', 'body=JAMB&mode=quick'],
               ['calendar-blank', 'green', 'Practice by year', 'Pick an exam year and go', 'pq', '']].map(([ic, c, t, d, go, pr]) => `
              <button class="card card-tap mode-card" data-go="${go}" ${pr ? `data-params="${pr}"` : ''}><span class="ic ${c}" style="width:44px;height:44px;border-radius:12px;display:grid;place-items:center;font-size:22px;flex:none">${I(ic, 1)}</span>
                <span class="grow"><b>${t}</b><br><span class="t-cap muted">${d}</span></span>${I('caret-right').replace('class="', 'class="trail ')}</button>`).join('')}
          </div></section>
        <section><div class="sect-title"><h2 class="t-h3">Other exams</h2></div>
          <div class="grid2">${['WAEC', 'NECO'].map(b => ST.examOpen(b)
            ? `<button class="card card-tap exam-card" data-go="test-setup" data-params="body=${b}" style="flex-direction:column;align-items:flex-start">${examLogo(b)}<b class="t-sm">${b}</b><span class="badge ${ST.rule(b.toLowerCase()) === 'all' ? 'badge-success' : 'badge-soft'}">${I('lock-simple-open', 1)} ${ST.rule(b.toLowerCase()) === 'all' ? 'All years' : ST.yearsLabel(ST.rule(b.toLowerCase())) + ' free'}</span></button>`
            : `<button class="card card-tap exam-card locked" data-sheet="paywall" data-reason="${b}" style="flex-direction:column;align-items:flex-start">${examLogo(b)}<b class="t-sm">${b}</b><span class="badge badge-neutral">${I('lock-simple', 1)} Premium</span></button>`).join('')}
          </div></section>
        ${ST.can('compete') ? `<button class="card card-tap mode-card" data-go="compete"><span class="ic gold" style="width:44px;height:44px;border-radius:12px;display:grid;place-items:center;font-size:22px;flex:none">${I('trophy', 1)}</span><span class="grow"><b>Challenges & events</b><br><span class="t-cap muted">Weekly cash prizes and special events</span></span>${ST.livePill ? ST.livePill() : ''}</button>` : ''}
        ${ST.lbSettings && ST.lbSettings().on ? `<button class="card card-tap mode-card" data-go="leaderboard"><span class="ic gold" style="width:44px;height:44px;border-radius:12px;display:grid;place-items:center;font-size:22px;flex:none">${I('ranking', 1)}</span><span class="grow"><b>Leaderboard</b><br><span class="t-cap muted">See the best JAMB students this season</span></span>${I('caret-right').replace('class="', 'class="trail ')}</button>` : ''}
        ${ST.can('offline')
          ? `<section><div class="sect-title"><h2 class="t-h3">Downloaded for offline</h2><button class="btn btn-ghost" data-go="offline">Manage</button></div>
          <div class="card list"><div class="list-item"><span class="lead">${I('cloud-check', 1)}</span><span class="grow"><b class="t-sm">JAMB 2023 to 2025 · your subjects</b><div class="t-cap muted">Works offline · 6.4 MB · encrypted on this phone</div></span><span class="badge badge-success">Ready</span></div></div></section>`
          : `<button class="card card-tap row g3" style="padding:var(--s-4)" data-sheet="paywall" data-reason="offline"><span class="ic navy" style="width:44px;height:44px;border-radius:12px;display:grid;place-items:center;font-size:22px;flex:none">${I('cloud-arrow-down', 1)}</span><span class="grow"><b>Practise without data</b><br><span class="t-cap muted">Premium can download tests to use offline</span></span><span class="badge badge-neutral">${I('lock-simple', 1)} Premium</span></button>`}
      </div></div>`
  });

  // ---------- Test setup: every mode works; always starts a FRESH test ----------
  const SUBJ_KEY = { 'Use of English': 'eng', 'English Language': 'eng', Mathematics: 'mth', Physics: 'phy', Chemistry: 'chm', Biology: 'bio' };
  const SUBJ_ICON = { eng: 'book-open-text', mth: 'function', phy: 'atom', chm: 'flask', bio: 'dna', gen: 'book-open' };
  const TOPICS = { eng: ['Comprehension', 'Lexis and structure', 'Concord', 'Oral English'], mth: ['Indices and logarithms', 'Quadratic equations', 'Integration', 'Probability', 'Trigonometry'],
    phy: ['Motion', 'Waves', 'Electricity', 'Heat'], chm: ['Mole concept', 'Acids and bases', 'Organic chemistry', 'Redox'], bio: ['Genetics', 'Ecology', 'Cell biology'], gen: ['General'] };
  const MODES = {
    JAMB: [['full', 'Full exam'], ['subject', 'Subject'], ['topic', 'Topic'], ['quick', 'Quick']],
    WAEC: [['subject', 'One subject'], ['topic', 'Topic']], NECO: [['subject', 'One subject'], ['topic', 'Topic']]
  };
  const mySubjects = body => {
    const list = body === 'JAMB' ? (S.subjects || ['Use of English', 'Mathematics', 'Physics', 'Chemistry']) : ['English Language', 'Mathematics', 'Physics', 'Chemistry', 'Biology'];
    return list.map(n => ({ n: n === 'Use of English' ? 'English' : n, full: n, k: SUBJ_KEY[n] || 'gen' }));
  };
  const plan = st => {          // questions, minutes, score label for the summary card
    const subs = mySubjects(st.body);
    if (st.body === 'JAMB' && st.mode === 'full') return { subjects: subs.map(x => ({ k: x.k, n: x.n, total: x.k === 'eng' ? 60 : 40 })), mins: 120, max: '400', maxLabel: 'max score', title: 'JAMB UTME Mock' };
    if (st.mode === 'quick') return { subjects: [{ k: 'mth', n: 'Mixed', total: 20 }], mins: 15, max: '%', maxLabel: 'score shown', title: 'Quick test' };
    const sub = subs.find(x => x.k === st.subj) || subs[0];
    if (st.mode === 'topic') return { subjects: [{ k: sub.k, n: sub.n, total: st.count }], mins: st.count, max: '%', maxLabel: 'score shown', title: `Topic drill · ${[...st.topics].join(', ') || 'All topics'}` };
    const total = st.body === 'JAMB' ? (sub.k === 'eng' ? 60 : 40) : 50;
    return { subjects: [{ k: sub.k, n: sub.n, total }], mins: st.body === 'JAMB' ? 30 : 60, max: st.body === 'JAMB' ? '100' : '%', maxLabel: st.body === 'JAMB' ? 'max score' : 'score shown', title: `${st.body} ${sub.n}` };
  };

  def('test-setup', {
    title: 'Test setup (all modes)', group: 'Test & CBT',
    render: p => {
      const body = ['JAMB', 'WAEC', 'NECO'].includes(p.body) ? p.body : 'JAMB';
      return `
      <div class="appbar"><button class="icon-btn" data-back="test" aria-label="Back">${I('arrow-left')}</button><span class="title">${body} ${body === 'JAMB' ? 'UTME' : body === 'WAEC' ? 'WASSCE' : 'SSCE'} practice</span></div>
      <div class="scr-body"><div class="pad stack g5" style="padding-top:var(--s-2)" id="setupBody"></div></div>
      <div class="footer-cta"><button class="btn btn-primary btn-block" id="startBtn">Start exam</button></div>`;
    },
    mount(el, p) {
      const body = ['JAMB', 'WAEC', 'NECO'].includes(p.body) ? p.body : 'JAMB';
      if (!ST.examOpen(body)) { ST.go('test', null, { mode: 'back', replace: true }); ST.openSheet('paywall', { reason: body }); return; }
      const modes = MODES[body];
      const st = { body, mode: modes.some(m => m[0] === p.mode) ? p.mode : modes[0][0], subj: p.subj || mySubjects(body)[body === 'JAMB' ? 1 : 0].k, topics: new Set(p.topic ? [p.topic] : []), count: 20, year: 'mixed' };
      const box = el.querySelector('#setupBody'), start = el.querySelector('#startBtn');
      const allOpen = ST.rule(body.toLowerCase()) === 'all';
      const years = allOpen ? [2025, 2024, 2023, 2022, 2021, 2020] : ST.openYears(body);
      const draw = () => {
        const subs = mySubjects(body), pl = plan(st), q = pl.subjects.reduce((t, x) => t + x.total, 0);
        box.innerHTML = `
          <div class="row g3">${examLogo(body, 'lg')}<div><h1 class="t-h2">Set up your practice</h1><p class="t-sm muted">${body === 'JAMB' ? 'Rules come from the JAMB exam config.' : 'Objective paper, like the real exam.'}</p></div></div>
          <div class="field"><span class="field-label">Mode</span><div class="seg" id="modeSeg">${modes.map(([k, l]) => `<button class="${st.mode === k ? 'on' : ''}" data-m="${k}">${l}</button>`).join('')}</div>
            <span class="help">${{ full: 'All your subjects, timed like the real UTME.', subject: 'One subject at a time, timed.', topic: 'Only the topics you pick. Great for weak areas.', quick: '20 mixed questions in 15 minutes.' }[st.mode]}</span></div>
          ${st.mode === 'full' ? `<div class="field"><span class="field-label">Your subjects</span>
            <div class="card list">${pl.subjects.map(x => `<div class="list-item"><span class="lead">${I(SUBJ_ICON[x.k], 1)}</span><span class="grow t-sm bold">${x.n === 'English' ? 'Use of English' : x.n}</span><span class="t-cap muted tnum">${x.total} questions</span></div>`).join('')}</div>
            <button class="btn btn-ghost btn-sm" style="align-self:flex-start" data-go="setup" data-params="step=3">Change subjects</button></div>` : ''}
          ${st.mode === 'subject' || st.mode === 'topic' ? `<div class="field"><span class="field-label">Subject</span>
            <div class="stack g2">${subs.map(x => `<button class="subj ${st.subj === x.k ? 'on' : ''}" data-sub="${x.k}">${I(SUBJ_ICON[x.k])} ${x.n === 'English' ? 'Use of English' : x.n}<span class="tick">${I('check', 1)}</span></button>`).join('')}</div></div>` : ''}
          ${st.mode === 'topic' ? `<div class="field"><span class="field-label">Topics <span class="muted" style="font-weight:500">(pick one or more)</span></span>
            <div class="row wrap g2">${(TOPICS[st.subj] || TOPICS.gen).map(t => `<button class="chip ${st.topics.has(t) ? 'on' : ''}" data-topic="${t}">${t}</button>`).join('')}</div></div>
            <div class="field"><span class="field-label">Number of questions</span><div class="seg">${[10, 20, 30].map(n => `<button class="${st.count === n ? 'on' : ''}" data-count="${n}">${n}</button>`).join('')}</div></div>` : ''}
          ${st.mode !== 'quick' ? `<div class="field"><span class="field-label">Year</span><div class="chips">${['mixed', ...years].map(y => `<button class="chip ${String(st.year) === String(y) ? 'on' : ''}" data-year="${y}">${y === 'mixed' ? (allOpen ? 'Mixed (all years)' : 'Mixed (your free years)') : y}</button>`).join('')}${allOpen ? '' : `<button class="chip" data-sheet="paywall" data-reason="years">${I('lock-simple', 1)} More years</button>`}</div></div>` : ''}
          <div class="card card-pad row g4" style="justify-content:space-around;text-align:center">
            <div><b class="t-h2 tnum">${q}</b><div class="t-cap muted">questions</div></div><div><b class="t-h2 tnum">${pl.mins >= 60 ? Math.floor(pl.mins / 60) + ':' + String(pl.mins % 60).padStart(2, '0') : pl.mins}</b><div class="t-cap muted">${pl.mins >= 60 ? 'hours' : 'minutes'}</div></div><div><b class="t-h2 tnum">${pl.max}</b><div class="t-cap muted">${pl.maxLabel}</div></div></div>
          <div class="banner info">${I('arrow-counter-clockwise', 1)}<span>This starts a <b>new</b> test. To finish an old one, use <b>Continue your test</b> on Home.</span></div>
          ${ST.can('offline') ? `<p class="t-cap muted row g1">${I('cloud-check', 1)} Downloaded. You can take it offline.</p>` : `<p class="t-cap muted row g1">${I('wifi-high', 1)} Needs internet on the Free plan.</p>`}`;
        box.querySelectorAll('[data-m]').forEach(b => b.onclick = () => { st.mode = b.dataset.m; draw(); });
        box.querySelectorAll('[data-sub]').forEach(b => b.onclick = () => { st.subj = b.dataset.sub; st.topics.clear(); draw(); });
        box.querySelectorAll('[data-topic]').forEach(b => b.onclick = () => { st.topics.has(b.dataset.topic) ? st.topics.delete(b.dataset.topic) : st.topics.add(b.dataset.topic); draw(); });
        box.querySelectorAll('[data-count]').forEach(b => b.onclick = () => { st.count = +b.dataset.count; draw(); });
        box.querySelectorAll('[data-year]').forEach(b => b.onclick = () => { st.year = b.dataset.year; draw(); });
        const needTopic = st.mode === 'topic' && !st.topics.size;
        start.disabled = needTopic; start.classList.toggle('is-disabled', needTopic);
        start.textContent = needTopic ? 'Pick at least one topic' : { full: 'Start full exam', subject: 'Start subject practice', topic: 'Start topic drill', quick: 'Start quick test' }[st.mode];
      };
      draw();
      const begin = () => { const pl = plan(st); ST.startAttempt({ title: pl.title, subjects: pl.subjects, mins: pl.mins, body }); };
      start.onclick = () => {
        if (!ST.can('offline') && ST.needsNet('Practice on the Free plan')) return;
        const saved = ST.cbtSaved;
        if (!saved || !ST.attemptAnswered(saved)) return begin();
        ST.dialog(`<div class="stack g3"><div class="ic blue" style="width:52px;height:52px;border-radius:14px;display:grid;place-items:center;font-size:26px">${I('clock-counter-clockwise', 1)}</div>
          <h2 class="t-h2">You have an unfinished test</h2>
          <p class="t-sm muted"><b style="color:var(--c-text)">${saved.title}</b>: ${ST.attemptAnswered(saved)} of ${ST.attemptTotal(saved)} answered, ${ST.fmtTime(saved.left)} left.</p>
          <p class="t-sm muted">Starting a new test submits the unfinished one as it is, so its score still counts.</p>
          <button class="btn btn-primary btn-block" id="dNew">Start new test</button>
          <button class="btn btn-outline btn-block" id="dOld">Continue unfinished test</button>
          <button class="btn btn-ghost" data-close>Cancel</button></div>`, {
          mount: w => {
            w.querySelector('#dNew').onclick = () => { ST.closeOverlay(true); ST.toast('Your unfinished test was submitted. Starting a new one.', 'check-circle'); begin(); };
            w.querySelector('#dOld').onclick = () => { ST.closeOverlay(true); ST.go('cbt', { resume: 1 }); };
          }
        });
      };
    }
  });
})();
