/* News (admin-posted, with images), Leaderboard (admin-controlled), Question of the day. */
(function () {
  const { def, icon: I, examLogo } = ST;
  const S = ST.state;

  // ---------- Plan / admin switches shared with the admin prototype (per-browser demo only) ----------
  ST.isPremium = () => S.plan === 'premium';
  ST.setPlan = plan => {
    S.plan = plan;
    const ai = ST.access()[plan === 'premium' ? 'premium' : 'free'].ai;
    S.aiMax = ai; S.aiLeft = plan === 'premium' ? Math.max(Math.min(S.aiLeft, ai), ai - 2) : Math.min(S.aiLeft, Math.max(0, ai - 1));
    ST.syncPanel?.();
  };
  /** Leaderboard visibility is set by admin (Admin → Leaderboard). Production default: OFF. */
  ST.lbSettings = () => {
    const def = { on: true, years: { 2027: true, 2026: true, 2025: false }, names: 'first-initial', minTests: 3 };
    try { return Object.assign(def, JSON.parse(localStorage.getItem('st-lb') || '{}')); } catch (e) { return def; }
  };

  // ---------- News ----------
  const NEWS = [
    { id: 'reg', cat: 'JAMB registration', pinned: true, date: '24 Oct 2026', read: 3, cover: { g: 'c-navy', icon: 'identification-card', logo: 'JAMB' },
      title: 'JAMB 2027 UTME registration: dates, fees and what to bring',
      summary: 'Registration opens 6 January 2027. Here is the step-by-step guide so you do not miss anything.',
      body: `<p>JAMB has announced the timetable for the 2027 Unified Tertiary Matriculation Examination (UTME). <b>Sample news for the prototype: always confirm dates on the official JAMB website.</b></p>
        <h2>Key dates</h2><ul><li><b>6 Jan 2027:</b> registration opens</li><li><b>14 Feb 2027:</b> registration closes</li><li><b>Mar 2027:</b> mock examination</li><li><b>Apr to May 2027:</b> main UTME</li></ul>
        <h2>What you need</h2><ul><li>A working email address and phone number linked to your NIN</li><li>Your National Identification Number (NIN)</li><li>The ePIN you buy from an approved vendor or bank</li></ul>
        <h2>Our tip</h2><p>Choose your four subjects carefully. They must match your course requirements in the JAMB brochure (you can read it in Study).</p>`,
      cta: { label: 'Open the JAMB brochure in Study', go: 'doc' } },
    { id: 'phy26', cat: 'New questions', date: '22 Oct 2026', read: 1, cover: { g: 'c-blue', icon: 'atom', logo: 'JAMB' },
      title: 'JAMB 2026 Physics is now available', summary: '40 new questions with full worked solutions and 12 video explanations.',
      body: `<p>We have added the full JAMB 2026 Physics paper with step-by-step solutions. Topics include motion, waves, electricity and modern physics.</p><p>Premium students can practise it now in Test or Study.</p>`,
      cta: { label: 'Practise JAMB 2026 Physics', go: 'test-setup', params: 'body=JAMB&mode=subject' } },
    { id: 'class', cat: 'Classes', date: '21 Oct 2026', read: 2, cover: { g: 'c-gold', icon: 'video-camera' },
      title: 'Free Maths revision class this Saturday', summary: 'Join Mr. Bello live at 10:00 AM for quadratic equations and indices.',
      body: `<p>Our free revision class covers quadratic equations, indices and logarithms. Bring your questions.</p><p>The class link opens 5 minutes before the start time.</p>`,
      cta: { label: 'Remind me', toast: 'We will remind you 30 minutes before the class.' } },
    { id: 'tips', cat: 'Exam tips', date: '18 Oct 2026', read: 4, cover: { g: 'c-green', icon: 'lightbulb' },
      title: '7 habits of students who score 300+ in JAMB', summary: 'Practise timed, review every mistake, and other habits that work.',
      body: `<ol><li>Practise under real time limits.</li><li>Review every wrong answer the same day.</li><li>Learn the JAMB syllabus topics, not just past questions.</li><li>Use the novel summaries for Use of English.</li><li>Sleep well before mock exams.</li><li>Track weak topics and drill them.</li><li>Take at least one full mock every week.</li></ol>` }
  ];
  const CATS = ['All', 'JAMB registration', 'New questions', 'Classes', 'Exam tips'];
  /** News posted from the admin prototype in this browser (demo of admin → app). */
  ST.allNews = () => {
    let custom = [];
    try { custom = JSON.parse(localStorage.getItem('st-news') || '[]'); } catch (e) {}
    return [...custom, ...NEWS];
  };
  ST.newsCover = (n, cls = '') => n.cover.img
    ? `<div class="news-cover ${cls}"><img src="${n.cover.img}" alt=""></div>`
    : `<div class="news-cover ${n.cover.g} ${cls}" aria-hidden="true"><i class="ph-fill ph-${n.cover.icon} nc-ic"></i>${n.cover.logo ? `<span class="nc-logo">${examLogo(n.cover.logo, 'sm')}</span>` : ''}</div>`;
  ST.newsCard = n => `<button class="news-tile" data-go="news-detail" data-params="id=${n.id}">${ST.newsCover(n)}
      <span class="nt-body"><span class="row g2"><span class="badge badge-soft">${n.cat}</span>${n.pinned ? `<span class="badge badge-gold">${I('push-pin', 1)} Pinned</span>` : ''}</span>
      <b class="nt-title">${n.title}</b><span class="t-cap muted">${n.date} · ${n.read} min read</span></span></button>`;

  def('news', {
    title: 'News list', group: 'News & community', tab: 'home',
    render: p => {
      const cat = p.cat || 'All', list = ST.allNews().filter(n => cat === 'All' || n.cat === cat), [top, ...rest] = list;
      return `
      <div class="appbar"><button class="icon-btn" data-back="home" aria-label="Back">${I('arrow-left')}</button><span class="title">News</span><button class="icon-btn" aria-label="Notifications settings" data-go="settings">${I('bell-simple')}</button></div>
      <div class="scr-body"><div class="pad stack g4" style="padding-top:var(--s-2)">
        <div class="chips">${CATS.map(c => `<button class="chip ${c === cat ? 'on' : ''}" data-go="news" data-mode="fade" data-params="cat=${encodeURIComponent(c)}">${c}</button>`).join('')}</div>
        ${top ? `<button class="card card-tap news-feature" data-go="news-detail" data-params="id=${top.id}">${ST.newsCover(top, 'big')}
          <div class="stack g2" style="padding:var(--s-4)"><span class="row g2"><span class="badge badge-soft">${top.cat}</span>${top.pinned ? `<span class="badge badge-gold">${I('push-pin', 1)} Pinned</span>` : ''}</span>
          <b class="t-h3">${top.title}</b><p class="t-sm muted">${top.summary}</p><span class="t-cap muted">${top.date} · ${top.read} min read</span></div></button>` : `<div class="state"><div class="art blue">${I('newspaper', 1)}</div><h2 class="t-h3">No news here yet</h2><p class="muted">Try another category.</p></div>`}
        <div class="card list enter">${rest.map(n => `<button class="list-item news-row" data-go="news-detail" data-params="id=${n.id}">${ST.newsCover(n, 'thumb')}<span class="grow"><b class="t-sm" style="display:block">${n.title}</b><span class="t-cap muted">${n.cat} · ${n.date}</span></span></button>`).join('')}</div>
      </div></div>`;
    }
  });

  def('news-detail', {
    title: 'News article', group: 'News & community',
    render: p => {
      const all = ST.allNews(), n = all.find(x => x.id === p.id) || all[0], more = all.filter(x => x.id !== n.id).slice(0, 2);
      return `
      <div class="read-progress"><i id="rp"></i></div>
      <div class="scr-body" id="artScroll">
        <div class="art-hero">${ST.newsCover(n, 'hero')}
          <div class="art-bar"><button class="icon-btn glass" data-back="news" aria-label="Back">${I('arrow-left')}</button><span class="grow"></span><button class="icon-btn glass" aria-label="Share" data-toast="Opens the share sheet (WhatsApp, Telegram…)">${I('share-network')}</button></div></div>
        <article class="pad stack g3 note-body" style="padding-top:var(--s-5)">
          <span class="row g2"><span class="badge badge-soft">${n.cat}</span><span class="t-cap muted">${n.date} · ${n.read} min read</span></span>
          <h1 class="t-h1" style="margin:0">${n.title}</h1>
          <p class="t-lg muted" style="margin:0">${n.summary}</p>
          <div>${n.body}</div>
          ${n.cta ? `<button class="btn btn-primary btn-block" id="cta">${n.cta.label}</button>` : ''}
          ${more.length ? `<h2 class="t-h3" style="margin-top:var(--s-6)">More news</h2><div class="stack g3">${more.map(ST.newsCard).join('')}</div>` : ''}
        </article>
      </div>`;
    },
    mount(el, p) {
      const all = ST.allNews(), n = all.find(x => x.id === p.id) || all[0];
      const sc = el.querySelector('#artScroll'), rp = el.querySelector('#rp');
      sc.addEventListener('scroll', () => { rp.style.width = (sc.scrollTop / Math.max(1, sc.scrollHeight - sc.clientHeight) * 100) + '%'; }, { passive: true });
      const cta = el.querySelector('#cta');
      if (cta) cta.onclick = () => n.cta.go ? ST.go(n.cta.go, n.cta.params ? Object.fromEntries(new URLSearchParams(n.cta.params)) : null) : n.cta.url ? ST.toast('Opens ' + n.cta.url + ' in the browser', 'arrow-square-out') : ST.toast(n.cta.toast || 'Done');
    }
  });

  // ---------- Leaderboard ----------
  const NG = [['Chiamaka', 'O', 'Anambra', 372], ['Abdullahi', 'M', 'Kano', 366], ['Temiloluwa', 'A', 'Lagos', 361], ['Ifeoma', 'N', 'Enugu', 355], ['Oluwaseun', 'B', 'Oyo', 351], ['Zainab', 'Y', 'Kaduna', 348], ['Ebuka', 'C', 'Imo', 344], ['Halima', 'S', 'FCT Abuja', 341], ['Tobiloba', 'F', 'Ogun', 339], ['Precious', 'E', 'Rivers', 336], ['Mubarak', 'I', 'Kwara', 333], ['Blessing', 'U', 'Delta', 331]];
  const PAST_BEST = { 2026: ['Adaeze', 'K', 'Enugu', 'Queen’s School, Enugu', 381], 2025: ['Babatunde', 'O', 'Lagos', 'King’s College, Lagos', 376] };
  const initials = (f, l) => (f[0] + l).toUpperCase();
  const medal = r => r === 1 ? 'gold' : r === 2 ? 'silver' : 'bronze';

  def('leaderboard', {
    title: 'Leaderboard (admin-controlled)', group: 'News & community', tab: 'test',
    render: p => {
      const set = ST.lbSettings();
      const years = Object.entries(set.years).filter(([, on]) => on).map(([y]) => +y).sort((a, b) => b - a);
      if (!set.on || !years.length) return `
        <div class="appbar"><button class="icon-btn" data-back="test" aria-label="Back">${I('arrow-left')}</button><span class="title">Leaderboard</span></div>
        <div class="scr-body"><div class="state"><div class="art navy">${I('ranking', 1)}</div><h2 class="t-h2">Leaderboards are switched off</h2><p class="muted">SolutionTee has turned leaderboards off for now. Keep practising: your scores still count.</p><button class="btn btn-primary mt4" data-go="test">Back to Test</button></div></div>`;
      const year = +(p.year || years[0]), scope = p.scope || 'ng', current = year === years[0];
      const people = scope === 'state' ? NG.filter((_, i) => i % 2 === 0).map((x, i) => [x[0], x[1], 'Oyo', x[3] - 9 - i]) : NG;
      const [a, b, c] = people, rest = people.slice(3);
      const best = PAST_BEST[year];
      const name = (f, l) => set.names === 'first-initial' ? `${f} ${l}.` : `${f}`;
      return `
      <div class="appbar"><button class="icon-btn" data-back="test" aria-label="Back">${I('arrow-left')}</button><span class="title">Leaderboard<small>Best full JAMB mock score this season</small></span><button class="icon-btn" id="lbInfo" aria-label="How ranking works">${I('info')}</button></div>
      <div class="scr-body"><div class="pad stack g4" style="padding-top:var(--s-2);padding-bottom:110px">
        <div class="chips">${years.map(y => `<button class="chip ${y === year ? 'on' : ''}" data-go="leaderboard" data-mode="fade" data-params="year=${y}&scope=${scope}">${examLogo('JAMB', 'sm')} JAMB ${y}${y === years[0] ? ' (now)' : ''}</button>`).join('')}</div>
        ${current ? `<div class="seg">${[['ng', 'Nigeria'], ['state', 'My state (Oyo)']].map(([k, l]) => `<button class="${k === scope ? 'on' : ''}" data-go="leaderboard" data-mode="fade" data-params="year=${year}&scope=${k}">${l}</button>`).join('')}</div>` : ''}
        ${best ? `<section class="lb-best pop"><span class="lb-crown">${I('crown-simple', 1)}</span><div class="grow"><span class="t-cap bold" style="color:var(--gold-700)">Best student of JAMB ${year}</span><b class="t-h3" style="display:block">${name(best[0], best[1])}</b><span class="t-cap muted">${best[3]} · ${best[2]}</span></div><b class="lb-big tnum">${best[4]}</b></section>` : ''}
        <section class="podium" aria-label="Top 3">
          ${[[b, 2], [a, 1], [c, 3]].map(([x, r]) => `<div class="pod pod-${r}"><div class="pod-av ${medal(r)}">${initials(x[0], x[1])}<span class="pod-r">${r}</span></div><b class="t-sm">${name(x[0], x[1])}</b><span class="t-cap muted">${x[2]}</span><span class="pod-bar"><b class="tnum">${x[3]}</b></span></div>`).join('')}
        </section>
        <div class="card list enter">${rest.map((x, i) => `<div class="list-item lb-row"><span class="lb-rank tnum">${i + 4}</span><span class="avatar" style="width:36px;height:36px;font-size:13px;background:var(--c-primary-soft);color:var(--c-on-primary-soft)">${initials(x[0], x[1])}</span>
          <span class="grow"><b class="t-sm">${name(x[0], x[1])}</b><div class="t-cap muted">${x[2]}</div></span>${i % 3 === 0 ? `<span class="t-cap" style="color:var(--c-success)">${I('caret-up', 1)}${i + 1}</span>` : i % 3 === 1 ? `<span class="t-cap" style="color:var(--c-error)">${I('caret-down', 1)}1</span>` : ''}<b class="tnum">${x[3]}</b></div>`).join('')}</div>
        <p class="t-cap subtle" style="text-align:center">Only first names and an initial are shown. You can hide yourself in Me, then Settings.</p>
      </div></div>
      ${current ? `<div class="lb-me"><span class="lb-rank tnum">#${scope === 'state' ? 14 : 128}</span>${ST.avatar()}<span class="grow"><b class="t-sm">You</b><div class="t-cap muted">${scope === 'state' ? '7 points to reach #13' : '38 points to reach the top 100'}</div></span><b class="tnum">287</b></div>` : ''}`;
    },
    mount(el) {
      el.querySelector('#lbInfo')?.addEventListener('click', () => ST.sheet(`<h2 class="t-h3">How the leaderboard works</h2>
        <div class="stack g3 mt4 t-sm">${[['exam', 'Your best score in a full JAMB mock (out of 400) counts.'], ['list-checks', `You need at least ${ST.lbSettings().minTests} full mocks this season to appear.`], ['timer', 'If two students tie, the faster time ranks higher.'], ['eye-slash', 'Only your first name and an initial are shown. Turn it off in Settings any time.'], ['calendar', 'Each JAMB year has its own board. Past years show the best student.']].map(([ic, t]) => `<div class="benefit">${I(ic, 1).replace('class="', 'style="color:var(--c-secondary);font-size:20px" class="')}<span>${t}</span></div>`).join('')}</div>`));
    }
  });

  // ---------- Question of the day ----------
  const QOTD = { subj: 'Mathematics', src: 'JAMB 2019', q: 'Evaluate $\\log_{2} 32 - \\log_{3} 27$.', o: ['$1$', '$2$', '$3$', '$5$'], a: 1, right: 62,
    exp: 'Write each number as a power of its base: $32 = 2^5$ and $27 = 3^3$. So $\\log_2 32 - \\log_3 27 = 5 - 3 = 2$.' };
  const nextIn = () => { const now = new Date(), mid = new Date(now); mid.setHours(24, 0, 0, 0); const s = Math.floor((mid - now) / 1000); return `${Math.floor(s / 3600)}h ${String(Math.floor(s % 3600 / 60)).padStart(2, '0')}m`; };
  ST.qotdCard = () => `
    <section class="card qotd2" id="qotd">
      <div class="q2-head"><span class="row g2"><span class="q2-ic">${I('lightbulb', 1)}</span><span><b class="t-sm" style="display:block">Question of the day</b><span class="t-cap muted">${QOTD.subj} · from ${QOTD.src}</span></span></span>
        <span class="q2-streak" title="Days in a row">${I('fire', 1)} 4</span></div>
      <div class="q2-body">
        <p style="font-size:16px;line-height:25px">${QOTD.q}</p>
        <div class="stack g2 mt3" id="q2opts">${QOTD.o.map((o, k) => `<button class="opt" data-k="${k}" style="min-height:48px"><span class="key" style="width:32px;height:32px">${'ABCD'[k]}</span><span>${o}</span></button>`).join('')}</div>
        <div id="q2after" class="hidden stack g3 mt3"></div>
        <p class="t-cap muted mt3 row g1" id="q2next">${I('clock')} New question in ${nextIn()}</p>
      </div>
    </section>`;
  ST.mountQotd = el => {
    const box = el.querySelector('#qotd'); if (!box) return;
    box.querySelectorAll('#q2opts .opt').forEach(b => b.onclick = () => {
      const k = +b.dataset.k, ok = k === QOTD.a;
      box.querySelectorAll('#q2opts .opt').forEach(o => { o.disabled = true; if (+o.dataset.k === QOTD.a) o.classList.add('right'); });
      if (!ok) b.classList.add('wrong');
      const after = box.querySelector('#q2after');
      after.innerHTML = `
        <div class="q2-result ${ok ? 'ok' : 'no'} pop">${I(ok ? 'confetti' : 'smiley-sad', 1)}<span class="grow"><b>${ok ? 'Correct! +10 XP' : 'Not this time'}</b><br><span class="t-cap">${ok ? 'Your question-of-the-day streak is now 5 days.' : 'The answer is B. Read why below, then try a similar one.'}</span></span></div>
        <div class="stack g1"><div class="row between t-cap"><span class="muted">Students who got it right</span><b class="tnum">${QOTD.right}%</b></div><div class="bar"><i data-v="${QOTD.right}%"></i></div></div>
        <details class="acc card" ${ok ? '' : 'open'}><summary>Explanation ${I('caret-down')}</summary><p style="color:var(--c-text)">${QOTD.exp}</p></details>
        <div class="row g2"><button class="btn btn-tonal btn-sm grow" data-go="ai" data-params="q=log">${I('sparkle', 1)} Ask AI</button>${ok ? `<button class="btn btn-outline btn-sm grow" data-toast="Opens the share sheet">${I('share-network')} Share</button>` : `<button class="btn btn-outline btn-sm grow" data-go="pq-study" data-params="year=2001">${I('arrow-clockwise')} Similar question</button>`}</div>`;
      after.classList.remove('hidden');
      ST.math(after); ST.animateBars(after);
      if (ok && !ST.reduceMotion()) { box.querySelector('.q2-streak').classList.add('pop'); }
    });
  };
})();
