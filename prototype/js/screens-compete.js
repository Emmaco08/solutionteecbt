/* Challenges & events (cash prizes, rewards, paid entry), fair-play anti-cheat, prize claims,
   locked-feature page, syllabus list. Open to Free and Premium students. */
(function () {
  const { def, icon: I, examLogo } = ST;
  const S = ST.state;
  const G = 'Challenges & events';

  // ---------- Locked feature page (used by core for screens with `needs`) ----------
  const FEATURE_NAMES = { videos: 'Video solutions', lessons: 'Topic video lessons', notes: 'Lesson notes', novels: 'Novels', compete: 'Challenges' };
  ST.lockedScreen = (cfg, need) => ({
    ...cfg, mount: null, cls: '',
    render: () => `
      <div class="appbar"><button class="icon-btn" data-back="study" aria-label="Back">${I('arrow-left')}</button><span class="title">${FEATURE_NAMES[need] || cfg.title}</span></div>
      <div class="scr-body"><div class="state">
        <div class="art gold">${I('lock-simple', 1)}</div>
        <h2 class="t-h2">${FEATURE_NAMES[need] || 'This'} ${need === 'novels' || need === 'notes' ? 'are' : 'is'} for Premium</h2>
        <p class="muted">Your plan does not include ${(FEATURE_NAMES[need] || 'this').toLowerCase()}. Go Premium to open it, with every past-question year and 100 AI prompts a day.</p>
        <button class="btn btn-accent btn-block mt4" data-sheet="paywall" data-reason="${need}">${I('crown-simple', 1)} See Premium plans</button>
        <button class="btn btn-ghost" data-go="pq">Practise free past questions</button>
      </div></div>`
  });

  // ---------- Syllabus & brochure list (Free: first N documents) ----------
  const DOCS = [['JAMB brochure 2027', 'Course requirements and subject combinations', 'book-open'], ['JAMB syllabus: Use of English', '24 pages', 'file-pdf'], ['JAMB syllabus: Mathematics', '24 pages', 'file-pdf'],
    ['JAMB syllabus: Physics', '22 pages', 'file-pdf'], ['WAEC syllabus: Mathematics', '18 pages', 'file-pdf'], ['NECO syllabus: Mathematics', '16 pages', 'file-pdf']];
  def('docs', {
    title: 'Syllabus & brochure list', group: 'Study',
    render: () => {
      const n = ST.rule('syllabus'), open = i => n === 'all' || i < n;
      return `
      <div class="appbar"><button class="icon-btn" data-back="study" aria-label="Back">${I('arrow-left')}</button><span class="title">Syllabus & brochure</span></div>
      <div class="scr-body"><div class="pad stack g4" style="padding-top:var(--s-2)">
        ${n === 'all' ? '' : `<div class="banner info">${I('info', 1)}<span>Your plan includes ${n} document${n === 1 ? '' : 's'}. Upgrade to open every syllabus.</span></div>`}
        <div class="card list enter">${DOCS.map(([t, d, ic], i) => `<button class="list-item" ${open(i) ? 'data-go="doc"' : 'data-sheet="paywall" data-reason="syllabus"'}><span class="lead">${I(ic, 1)}</span><span class="grow"><b class="t-sm">${t}</b><div class="t-cap muted">${d}</div></span>${open(i) ? I('caret-right').replace('class="', 'class="trail ') : `<span class="badge badge-neutral">${I('lock-simple', 1)} Premium</span>`}</button>`).join('')}</div>
      </div></div>`;
    }
  });

  // ---------- Challenges & events data (SAMPLE) ----------
  // type: 'cash' weekly challenge · 'event' (reward optional, free or paid entry) · 'practice' (no reward)
  const NOW = Date.now(), H = 3600e3;
  const CH = [
    { id: 'wk44', type: 'cash', title: 'Weekly Challenge #44', sub: 'Mixed JAMB subjects · new questions', status: 'live', ends: NOW + 2.2 * H, q: 10, perQ: 30, entry: 0,
      prizes: [20000, 10000, 5000], rule: 'Highest score wins. If scores tie, the fastest time wins.', joined: 1284, cover: { g: 'c-gold', icon: 'trophy' } },
    { id: 'sprint', type: 'event', title: 'Maths Sprint Cup', sub: 'Algebra and calculus · 15 questions', status: 'upcoming', starts: NOW + 26 * H, q: 15, perQ: 40, entry: 200,
      prizes: [50000, 25000, 10000], rule: 'Highest score wins. Ties go to the fastest time.', joined: 412, cover: { g: 'c-navy', icon: 'function' } },
    { id: 'bee', type: 'event', title: 'Use of English Bee', sub: 'Lexis, structure and comprehension', status: 'upcoming', starts: NOW + 50 * H, q: 20, perQ: 30, entry: 0,
      reward: '30 days of Premium for the top 10', rule: 'Top 10 scores win. Ties go to the fastest time.', joined: 230, cover: { g: 'c-blue', icon: 'book-open-text' } },
    { id: 'night', type: 'practice', title: 'Physics Practice Night', sub: 'For fun and practice, no prize', status: 'live', ends: NOW + 5 * H, q: 10, perQ: 45, entry: 0,
      rule: 'No winners. See how you rank against other students.', joined: 96, cover: { g: 'c-green', icon: 'atom' } },
    { id: 'wk43', type: 'cash', title: 'Weekly Challenge #43', sub: 'Mixed JAMB subjects', status: 'ended', q: 10, perQ: 30, entry: 0, prizes: [20000, 10000, 5000],
      winners: [['Ifeoma N.', 'Enugu', '10/10', '3:12'], ['Mubarak I.', 'Kwara', '10/10', '3:40'], ['Zainab Y.', 'Kaduna', '9/10', '2:58']], joined: 1532, cover: { g: 'c-gold', icon: 'trophy' } }
  ];
  ST.CHALLENGES = CH;
  ST.joined = ST.joined || new Set();
  const money = n => ST.naira(n);
  const until = t => { const s = Math.max(0, Math.round((t - Date.now()) / 1000)); const d = Math.floor(s / 86400), h = Math.floor(s % 86400 / 3600), m = Math.floor(s % 3600 / 60); return d ? `${d}d ${h}h` : h ? `${h}h ${String(m).padStart(2, '0')}m` : `${m}m ${String(s % 60).padStart(2, '0')}s`; };
  const rewardText = c => c.prizes ? `${money(c.prizes[0])} first prize` : c.reward || 'No prize, just for practice';
  const entryText = c => c.entry ? `${money(c.entry)} to join` : 'Free to join';
  const statusBadge = c => c.status === 'live' ? `<span class="badge badge-error"><span class="fx-live" style="animation:st-blink 1.2s steps(1) infinite"></span>LIVE</span>` : c.status === 'upcoming' ? `<span class="badge badge-soft">${I('clock', 1)} Starts in ${until(c.starts)}</span>` : `<span class="badge badge-neutral">Ended</span>`;
  const typeBadge = c => c.type === 'cash' ? `<span class="badge badge-gold">${I('currency-ngn', 1)} Cash prize</span>` : c.type === 'event' ? `<span class="badge badge-soft">${I('calendar-star', 1)} Event</span>` : `<span class="badge badge-neutral">Practice</span>`;

  /** Home hero card for the live weekly challenge. */
  ST.challengeHero = () => {
    if (!ST.can('compete')) return '';
    const c = CH.find(x => x.type === 'cash' && x.status === 'live'); if (!c) return '';
    return `<button class="ch-hero" data-go="challenge" data-params="id=${c.id}" data-tour="compete">
      <span class="ch-hero-glow"></span>
      <span class="row between" style="position:relative"><span class="badge badge-error"><span class="fx-live" style="animation:st-blink 1.2s steps(1) infinite"></span>LIVE NOW</span><span class="t-cap" style="color:#AFC0DD">${c.joined.toLocaleString()} students in</span></span>
      <span style="position:relative"><span class="t-cap" style="color:var(--gold-300);font-weight:700">${c.title}</span><b class="ch-hero-amt">Win ${money(c.prizes[0])}</b><span class="t-sm" style="color:#DCE4F2">${c.q} questions · ${c.perQ}s each · free for everyone</span></span>
      <span class="row between" style="position:relative"><span class="t-cap" style="color:#AFC0DD">${I('timer', 1)} Closes in <b class="tnum" data-until="${c.ends}">${until(c.ends)}</b></span><span class="btn btn-accent btn-sm">Join challenge ${I('arrow-right')}</span></span>
    </button>`;
  };

  def('compete', {
    title: 'Challenges & events list', group: G, tab: 'test',
    render: () => {
      const live = CH.filter(c => c.status === 'live'), up = CH.filter(c => c.status === 'upcoming'), past = CH.filter(c => c.status === 'ended');
      const card = c => `<button class="card card-tap ch-card" data-go="challenge" data-params="id=${c.id}">${ST.newsCover({ cover: c.cover }, 'thumb')}
        <span class="grow stack g1"><span class="row g2 wrap">${statusBadge(c)}${typeBadge(c)}</span><b class="t-sm">${c.title}</b><span class="t-cap muted">${rewardText(c)} · ${entryText(c)}</span></span>${I('caret-right').replace('class="', 'class="trail ')}</button>`;
      return `
      <div class="appbar"><button class="icon-btn" data-back="test" aria-label="Back">${I('arrow-left')}</button><span class="title">Challenges & events<small>Win prizes. Free and Premium can join.</small></span><button class="icon-btn" data-go="winnings" aria-label="My winnings">${I('wallet')}</button></div>
      <div class="scr-body"><div class="pad stack g5" style="padding-top:var(--s-2)">
        ${ST.challengeHero()}
        ${live.length ? `<section class="stack g2"><h2 class="t-h3">Live now</h2>${live.map(card).join('')}</section>` : ''}
        ${up.length ? `<section class="stack g2"><h2 class="t-h3">Coming up</h2>${up.map(card).join('')}</section>` : ''}
        ${past.length ? `<section class="stack g2"><h2 class="t-h3">Past winners</h2>${past.map(c => `<div class="card card-pad stack g2"><div class="row between"><b class="t-sm">${c.title}</b><span class="t-cap muted">${c.joined.toLocaleString()} took part</span></div>
          ${c.winners.map((w, i) => `<div class="row g3 t-sm"><span class="pod-av ${['gold', 'silver', 'bronze'][i]}" style="width:30px;height:30px;font-size:12px;margin:0">${i + 1}</span><span class="grow"><b>${w[0]}</b> <span class="muted">${w[1]}</span></span><span class="tnum muted">${w[2]} · ${w[3]}</span><b class="tnum">${money(c.prizes[i])}</b></div>`).join('')}</div>`).join('')}</section>` : ''}
        <p class="t-cap subtle" style="text-align:center">Prizes are paid after a fair-play review. Sample amounts for the prototype.</p>
      </div></div>`;
    },
    mount(el) {
      const iv = setInterval(() => { if (!el.isConnected) return clearInterval(iv); el.querySelectorAll('[data-until]').forEach(x => x.textContent = until(+x.dataset.until)); }, 1000);
    }
  });

  // ---------- Challenge detail: prizes, fair-play rules, join (free or paid) ----------
  const FAIR = [['device-mobile', 'Stay on the challenge screen', 'Leaving the app, opening another app (like an AI app), split screen or a floating window submits your answers and disqualifies you.'],
    ['camera-slash', 'Screenshots and copying are blocked', 'You cannot screenshot, screen-record or copy the questions.'],
    ['timer', 'One question at a time, timed', 'Each question has its own short timer. You cannot go back.'],
    ['shuffle', 'Your questions are shuffled', 'Every student gets the questions and options in a different order. The answers are checked on our server.'],
    ['magnifying-glass', 'Answers are reviewed', 'Very fast or unusual answer patterns are checked before prizes are paid.'],
    ['identification-badge', 'Winners are verified', 'One account per person and phone. Winners confirm their identity. Under 18? A parent or guardian must agree and receives the prize.']];
  def('challenge', {
    title: 'Challenge details & fair-play rules', group: G,
    render: p => {
      const c = CH.find(x => x.id === p.id) || CH[0], joined = ST.joined.has(c.id) || !c.entry;
      return `
      <div class="scr-body">
        <div class="art-hero">${ST.newsCover({ cover: c.cover }, 'hero')}
          <div class="art-bar"><button class="icon-btn glass" data-back="compete" aria-label="Back">${I('arrow-left')}</button><span class="grow"></span><button class="icon-btn glass" aria-label="Share" data-toast="Opens the share sheet">${I('share-network')}</button></div></div>
        <div class="pad stack g4" style="padding-top:var(--s-4)">
          <span class="row g2 wrap">${statusBadge(c)}${typeBadge(c)}</span>
          <div><h1 class="t-h1">${c.title}</h1><p class="muted mt2">${c.sub}</p></div>
          <div class="grid3 ch-facts"><div><b class="tnum">${c.q}</b><span>questions</span></div><div><b class="tnum">${c.perQ}s</b><span>per question</span></div><div><b>${c.entry ? money(c.entry) : 'Free'}</b><span>entry</span></div></div>
          ${c.prizes ? `<section class="card card-pad stack g2"><b>Prizes</b>${c.prizes.map((pz, i) => `<div class="row g3"><span class="pod-av ${['gold', 'silver', 'bronze'][i]}" style="width:32px;height:32px;font-size:13px;margin:0">${i + 1}</span><span class="grow t-sm bold">${['1st', '2nd', '3rd'][i]} place</span><b class="tnum">${money(pz)}</b></div>`).join('')}<p class="t-cap muted">${c.rule}</p></section>`
            : `<section class="card card-pad stack g2"><b>Reward</b><p class="t-sm">${c.reward || 'No prize. Practise and see how you rank.'}</p><p class="t-cap muted">${c.rule}</p></section>`}
          <section class="stack g3"><div class="row g2"><span class="ic green" style="width:32px;height:32px;border-radius:9px;display:grid;place-items:center">${I('shield-check', 1)}</span><h2 class="t-h3">Fair-play rules</h2></div>
            <div class="card list">${FAIR.map(([ic, t, d]) => `<div class="list-item" style="align-items:flex-start"><span class="lead" style="background:var(--c-success-soft);color:var(--c-on-success-soft)">${I(ic, 1)}</span><span class="grow"><b class="t-sm">${t}</b><div class="t-cap muted">${d}</div></span></div>`).join('')}</div>
            <label class="check" id="fpBox"><input type="checkbox" id="fpOk"><span>I agree to the fair-play rules. I understand that leaving the challenge screen <b>disqualifies</b> me.</span></label>
          </section>
          <div class="banner warn">${I('wrench', 1)}<span><b>Prototype:</b> leaving this browser tab or switching apps during the challenge really triggers disqualification. You can also use "Simulate cheating" in the side panel.</span></div>
        </div>
      </div>
      <div class="footer-cta" id="chFoot"></div>`;
    },
    mount(el, p) {
      const c = CH.find(x => x.id === p.id) || CH[0], foot = el.querySelector('#chFoot'), ok = el.querySelector('#fpOk');
      const draw = () => {
        const paid = ST.joined.has(c.id) || !c.entry;
        if (c.status === 'ended') foot.innerHTML = `<button class="btn btn-outline btn-block" data-go="compete">See past winners</button>`;
        else if (c.status === 'upcoming') foot.innerHTML = paid
          ? `<button class="btn btn-tonal btn-block" data-toast="We will remind you 15 minutes before it starts">${I('bell-ringing', 1)} You are in. Remind me</button>`
          : `<button class="btn btn-primary btn-block" id="payJoin">Pay ${money(c.entry)} to join</button>`;
        else foot.innerHTML = paid ? `<button class="btn btn-primary btn-block" id="startCh">${I('play', 1)} Start challenge</button>` : `<button class="btn btn-primary btn-block" id="payJoin">Pay ${money(c.entry)} to join</button>`;
        foot.querySelector('#startCh')?.addEventListener('click', () => {
          if (!ok.checked) { el.querySelector('#fpBox').classList.add('shake'); ok.closest('.check').style.color = 'var(--c-error)'; setTimeout(() => el.querySelector('#fpBox').classList.remove('shake'), 400); ok.focus(); ST.toast('Tick the fair-play box first.', 'shield-warning'); return; }
          ST.go('challenge-play', { id: c.id });
        });
        foot.querySelector('#payJoin')?.addEventListener('click', () => {
          if (!ok.checked) { ok.focus(); ST.toast('Tick the fair-play box first.', 'shield-warning'); return; }
          ST.sheet(`<h2 class="t-h3">Join ${c.title}</h2>
            <div class="card card-pad stack g2 mt4 t-sm"><div class="row between"><span class="muted">Entry fee</span><b>${money(c.entry)}</b></div><div class="row between"><span class="muted">First prize</span><b>${money(c.prizes ? c.prizes[0] : 0)}</b></div></div>
            <p class="t-cap muted mt3">Paid with Paystack (card, transfer or USSD). Entry fees are not refunded if you are disqualified.</p>
            <button class="btn btn-primary btn-block mt4" id="pj">Pay ${money(c.entry)}</button>`, {
            mount: w => w.querySelector('#pj').onclick = () => { const b = w.querySelector('#pj'); b.classList.add('is-loading'); b.textContent = ''; setTimeout(() => { ST.joined.add(c.id); ST.closeOverlay(); draw(); ST.toast(`You have joined ${c.title}.`, 'check-circle'); }, 1000); }
          });
        });
      };
      ok.onchange = () => { ok.closest('.check').style.color = ''; };
      draw();
    }
  });

  // ---------- Challenge play: one question at a time + fair-play guard ----------
  const CQ = [
    { q: 'If $3^{x} = 81$, find $x$.', o: ['$3$', '$4$', '$9$', '$27$'], a: 1 },
    { q: 'Which of these is a noun?', o: ['quickly', 'happiness', 'beautiful', 'run'], a: 1 },
    { q: 'The SI unit of force is the', o: ['joule', 'watt', 'newton', 'pascal'], a: 2 },
    { q: 'Simplify $\\frac{2}{3} + \\frac{1}{6}$.', o: ['$\\frac{1}{2}$', '$\\frac{5}{6}$', '$\\frac{3}{9}$', '$1$'], a: 1 },
    { q: 'Water boils at $100^\\circ\\text{C}$ at', o: ['any pressure', 'sea-level pressure', 'high altitude', 'zero pressure'], a: 1 },
    { q: 'Choose the correct spelling.', o: ['accomodation', 'acommodation', 'accommodation', 'accomodasion'], a: 2 },
    { q: 'What is $15\\%$ of $\\text{₦}2{,}000$?', o: ['₦150', '₦200', '₦300', '₦350'], a: 2 },
    { q: 'Which gas do plants take in for photosynthesis?', o: ['Oxygen', 'Carbon dioxide', 'Nitrogen', 'Hydrogen'], a: 1 },
    { q: 'Find the next number: $2, 6, 18, 54, \\ldots$', o: ['$108$', '$72$', '$162$', '$216$'], a: 2 },
    { q: 'An antonym of "ancient" is', o: ['old', 'modern', 'historic', 'aged'], a: 1 }
  ];
  const shuffle = a => { const b = [...a]; for (let i = b.length - 1; i > 0; i--) { const j = Math.floor(Math.random() * (i + 1)); [b[i], b[j]] = [b[j], b[i]]; } return b; };

  def('challenge-play', {
    title: 'Challenge in progress (anti-cheat)', group: G, cls: 'ch-play', noNav: true,
    render: p => {
      const c = CH.find(x => x.id === p.id) || CH[0];
      return `
      <div class="ch-top">
        <span class="fp-on" title="Fair-play protection is on">${I('shield-check', 1)} Fair play on</span>
        <b class="grow t-sm" style="text-align:center">${c.title}</b>
        <span class="t-cap tnum" id="chTotal">0:00</span>
      </div>
      <div class="ch-progress"><i id="chBar"></i></div>
      <div class="ch-body no-copy" id="chBody"></div>`;
    },
    mount(el, p) {
      const c = CH.find(x => x.id === p.id) || CH[0];
      const qs = shuffle(CQ).slice(0, c.q).map(x => { const order = shuffle(x.o.map((o, i) => ({ o, i }))); return { ...x, order }; });
      const t0 = Date.now(); let i = 0, score = 0, qTimer = null, over = false; const times = [];
      const body = el.querySelector('#chBody');
      const totalEl = el.querySelector('#chTotal');
      const totalIv = setInterval(() => { if (!el.isConnected) return clearInterval(totalIv); const s = Math.floor((Date.now() - t0) / 1000); totalEl.textContent = `${Math.floor(s / 60)}:${String(s % 60).padStart(2, '0')}`; }, 500);

      // ---- Fair-play guard (web prototype of the native protections) ----
      const block = e => { e.preventDefault(); ST.toast('Copying is turned off during challenges.', 'prohibit'); };
      const onVis = () => { if (document.hidden) violation('You left the challenge screen (switched app or tab).'); };
      const onBlur = () => setTimeout(() => { if (!document.hasFocus() && el.isConnected && !over) violation('Another window or app took focus.'); }, 300);
      const onFs = () => { if (fsEntered && !document.fullscreenElement) violation('You exited full screen.'); };
      let fsEntered = false;
      const guardOn = () => {
        document.addEventListener('visibilitychange', onVis); window.addEventListener('blur', onBlur); document.addEventListener('fullscreenchange', onFs);
        ['copy', 'cut', 'paste', 'contextmenu'].forEach(ev => document.addEventListener(ev, block));
        const fs = document.querySelector('.phone.real') && document.documentElement.requestFullscreen?.(); if (fs) fs.then(() => { fsEntered = true; }).catch(() => {});
      };
      const guardOff = () => {
        document.removeEventListener('visibilitychange', onVis); window.removeEventListener('blur', onBlur); document.removeEventListener('fullscreenchange', onFs);
        ['copy', 'cut', 'paste', 'contextmenu'].forEach(ev => document.removeEventListener(ev, block));
        if (document.fullscreenElement) document.exitFullscreen?.().catch(() => {});
      };
      ST.simulateCheat = () => violation('Another app was opened over the challenge (simulated).');
      const finish = (dq) => {
        if (over) return; over = true; clearInterval(qTimer); clearInterval(totalIv); guardOff(); ST.simulateCheat = null;
        const secs = Math.round((Date.now() - t0) / 1000);
        ST.lastChallenge = { id: c.id, score, total: qs.length, secs, dq, at: Math.round((Date.now() - t0) / 1000), answered: i };
        ST.go(dq ? 'challenge-dq' : 'challenge-result', { id: c.id }, { mode: 'fade', replace: true });
      };
      function violation(reason) { if (over || !el.isConnected) return; ST.lastReason = reason; finish(true); }

      const show = () => {
        if (i >= qs.length) return finish(false);
        const q = qs[i], per = c.perQ; let left = per; const qStart = Date.now();
        el.querySelector('#chBar').style.width = (i / qs.length * 100) + '%';
        body.innerHTML = `
          <div class="row between"><span class="t-label">Question ${i + 1} <span class="muted" style="font-weight:500">of ${qs.length}</span></span>
            <span class="q-timer" id="qt"><svg viewBox="0 0 36 36"><circle cx="18" cy="18" r="15" class="qt-track"/><circle cx="18" cy="18" r="15" class="qt-val" pathLength="1" id="qtv"/></svg><b class="tnum" id="qtn">${per}</b></span></div>
          <div class="q-text swap" style="margin-top:var(--s-3)">${q.q}</div>
          <div class="opts" role="radiogroup">${q.order.map((x, k) => `<button class="opt" data-i="${x.i}"><span class="key">${'ABCD'[k]}</span><span>${x.o}</span></button>`).join('')}</div>
          <p class="t-cap subtle mt4 row g1">${I('lock-simple', 1)} You cannot go back. Answers are checked on our server.</p>`;
        ST.math(body);
        const tv = body.querySelector('#qtv'), tn = body.querySelector('#qtn');
        const next = sel => {
          clearInterval(qTimer); times.push(Date.now() - qStart);
          if (sel === q.a) score++;
          body.querySelectorAll('.opt').forEach(o => { o.disabled = true; if (+o.dataset.i === sel) o.classList.add('sel'); });
          i++; setTimeout(show, ST.reduceMotion() ? 50 : 350);
        };
        body.querySelectorAll('.opt').forEach(b => b.onclick = () => next(+b.dataset.i));
        clearInterval(qTimer);
        qTimer = setInterval(() => {
          if (!el.isConnected) return clearInterval(qTimer);
          left -= 0.25; tv.style.strokeDashoffset = String(1 - left / per); tn.textContent = Math.ceil(left);
          body.querySelector('#qt').classList.toggle('low', left <= 5);
          if (left <= 0) next(-1);
        }, 250);
      };
      guardOn(); show();
    }
  });

  def('challenge-result', {
    title: 'Challenge result', group: G, navy: true,
    render: p => {
      const c = CH.find(x => x.id === p.id) || CH[0], r = ST.lastChallenge && ST.lastChallenge.id === c.id ? ST.lastChallenge : { score: 9, total: 10, secs: 192 };
      const rank = r.score === r.total ? 2 : r.score >= r.total - 1 ? 14 : 186, mm = `${Math.floor(r.secs / 60)}:${String(r.secs % 60).padStart(2, '0')}`;
      const inPrize = c.prizes && rank <= c.prizes.length;
      return `
      <canvas id="confetti"></canvas>
      <div class="scr-body" style="display:flex;flex-direction:column">
        <div class="res-hero" style="padding-top:var(--s-6)">
          <span class="badge badge-success" style="margin:0 auto">${I('shield-check', 1)} Fair-play check passed</span>
          <div class="score tnum mt4" style="font-size:56px">${r.score}<span style="font-size:22px;color:#AFC0DD">/${r.total}</span></div>
          <p class="muted mt2">Finished in <b style="color:#fff">${mm}</b></p>
          <h1 class="t-h2 mt4">${inPrize ? `You are #${rank} so far!` : `You are #${rank} so far`}</h1>
          <p class="muted t-sm mt2">${c.prizes ? (inPrize ? `If you stay in the top ${c.prizes.length} you win ${money(c.prizes[rank - 1])}.` : 'Keep practising. A new challenge comes every week.') : c.reward || 'Thanks for taking part.'}</p>
        </div>
        <div class="pad stack g4">
          <section class="card card-pad stack g2"><div class="row between"><b>Live ranking</b><span class="t-cap muted">${c.joined.toLocaleString()} students</span></div>
            ${[['Chiamaka O.', 'Anambra', '10/10', '2:51'], ['You', 'Oyo', `${r.score}/${r.total}`, mm], ['Abdullahi M.', 'Kano', '10/10', '3:30']].sort((a, b) => a[0] === 'You' ? rank - 2 : b[0] === 'You' ? 2 - rank : 0).map((w, k) => `<div class="row g3 t-sm ${w[0] === 'You' ? 'lb-you' : ''}"><span class="lb-rank tnum">${w[0] === 'You' ? rank : k + 1}</span><span class="grow"><b>${w[0]}</b> <span class="muted">${w[1]}</span></span><span class="tnum">${w[2]}</span><span class="tnum muted">${w[3]}</span></div>`).join('')}</section>
          <div class="banner info">${I('clock', 1)}<span>Winners are announced when the challenge closes, after the fair-play review. We will notify you.</span></div>
          ${inPrize ? `<button class="btn btn-accent btn-block" data-go="claim-prize" data-params="id=${c.id}&rank=${rank}">${I('gift', 1)} How I get my prize</button>` : ''}
          <button class="btn btn-outline btn-block" data-go="compete">See other challenges</button>
        </div>
      </div>`;
    },
    mount(el, p) { const c = CH.find(x => x.id === p.id) || CH[0]; const r = ST.lastChallenge; if (r && r.score >= r.total - 1 && !ST.reduceMotion()) ST.confetti(el.querySelector('#confetti')); }
  });

  def('challenge-dq', {
    title: 'Disqualified (auto-submitted)', group: G,
    render: p => {
      const c = CH.find(x => x.id === p.id) || CH[0], r = ST.lastChallenge || { answered: 3, at: 72 };
      return `
      <div class="appbar"><span class="grow"></span><button class="icon-btn" data-go="compete" aria-label="Close">${I('x')}</button></div>
      <div class="scr-body"><div class="state">
        <div class="art red">${I('shield-warning', 1)}</div>
        <h2 class="t-h2">Entry disqualified</h2>
        <p class="muted">${ST.lastReason || 'You left the challenge screen.'} Your answers were submitted automatically at ${Math.floor(r.at / 60)}:${String(r.at % 60).padStart(2, '0')}, after ${r.answered} of ${c.q} questions.</p>
        <div class="card card-pad stack g2 mt2" style="text-align:left;width:100%"><b class="t-sm">What this means</b>
          <p class="t-sm muted">This entry cannot win a prize${c.entry ? ' and the entry fee is not refunded' : ''}. You can still join next week's challenge.</p></div>
        <div class="banner warn mt2" style="text-align:left">${I('phone-call', 1)}<span>Was it a phone call or a crash? Send an appeal within 24 hours. Our team checks it.</span></div>
        <button class="btn btn-outline btn-block mt2" data-toast="Appeal sent. We will reply within 24 hours.">Send an appeal</button>
        <button class="btn btn-ghost" data-go="compete">Back to challenges</button>
      </div></div>`;
    }
  });

  // ---------- Prize claim (identity + bank details; guardian for under-18) ----------
  def('claim-prize', {
    title: 'Claim prize (verification)', group: G,
    render: p => {
      const c = CH.find(x => x.id === p.id) || CH[0], rank = +(p.rank || 1), amt = c.prizes ? c.prizes[Math.min(rank, c.prizes.length) - 1] : 0;
      return `
      <div class="appbar"><button class="icon-btn" data-back="compete" aria-label="Back">${I('arrow-left')}</button><span class="title">Get your prize</span></div>
      <div class="scr-body"><div class="pad stack g4" style="padding-top:var(--s-2)">
        <div class="ch-prize-banner">${I('trophy', 1)}<span class="grow"><b>${money(amt)}</b><br><span class="t-cap">${c.title} · #${rank} (pending review)</span></span></div>
        <div class="steps"><i class="on"></i><i></i><i></i></div>
        <p class="t-sm muted">We pay prizes by bank transfer within 3 working days after the challenge closes and the fair-play review is done.</p>
        <div class="field"><label>Are you 18 or older?</label><div class="seg" id="age"><button class="on" data-a="18">Yes, 18+</button><button data-a="u18">No, under 18</button></div></div>
        <div class="stack g4 hidden" id="guard">
          <div class="banner info">${I('users', 1)}<span>Because you are under 18, the prize is paid to your parent or guardian, and they must agree.</span></div>
          <div class="field"><label for="gName">Parent or guardian full name</label><div class="input"><input id="gName" autocomplete="off"></div></div>
          <div class="field"><label for="gPhone">Their phone number</label><div class="input"><input id="gPhone" inputmode="tel" autocomplete="off" placeholder="0803 000 0000"></div><span class="help">We send them a code to confirm.</span></div>
        </div>
        <div class="field"><label for="bank">Bank</label><div class="input"><select id="bank"><option value="">Choose bank</option>${['Access Bank', 'First Bank', 'GTBank', 'Kuda', 'Moniepoint', 'OPay', 'PalmPay', 'UBA', 'Wema Bank', 'Zenith Bank'].map(b => `<option>${b}</option>`).join('')}</select><i class="ph ph-caret-down sel-caret"></i></div></div>
        <div class="field" id="accF"><label for="acc">Account number</label><div class="input"><input id="acc" inputmode="numeric" maxlength="10" autocomplete="off" placeholder="10 digits"></div><span class="help" id="accHelp">The account name must match your name (or your guardian's).</span></div>
        <p class="t-cap subtle">We never ask for your PIN, password or card details. Bank details go straight to our payment provider.</p>
      </div></div>
      <div class="footer-cta"><button class="btn btn-primary btn-block" id="claimGo">Check account and continue</button></div>`;
    },
    mount(el) {
      el.querySelectorAll('#age button').forEach(b => b.onclick = () => { el.querySelectorAll('#age button').forEach(x => x.classList.toggle('on', x === b)); el.querySelector('#guard').classList.toggle('hidden', b.dataset.a !== 'u18'); });
      el.querySelector('#claimGo').onclick = () => {
        const f = el.querySelector('#accF'), acc = el.querySelector('#acc').value, bank = el.querySelector('#bank').value;
        f.classList.remove('has-error'); f.querySelector('.err')?.remove();
        if (!bank || !/^\d{10}$/.test(acc)) { f.classList.add('has-error'); f.insertAdjacentHTML('beforeend', `<span class="err">${I('warning-circle', 1)} Choose your bank and enter the 10-digit account number.</span>`); return; }
        ST.toast('Account checked. Your prize is pending review.', 'check-circle'); ST.go('winnings');
      };
    }
  });

  def('winnings', {
    title: 'My winnings', group: G,
    render: () => `
      <div class="appbar"><button class="icon-btn" data-back="profile" aria-label="Back">${I('arrow-left')}</button><span class="title">My winnings</span></div>
      <div class="scr-body"><div class="pad stack g4" style="padding-top:var(--s-2)">
        <div class="ch-prize-banner">${I('wallet', 1)}<span class="grow"><span class="t-cap">Total won</span><br><b class="tnum" style="font-size:28px">${ST.naira(15000)}</b></span><span class="badge badge-success">${ST.naira(5000)} paid</span></div>
        <div class="card list">
          ${[['Weekly Challenge #44', '#2 · pending fair-play review', 10000, 'warning'], ['Weekly Challenge #40', '#3 · paid to GTBank ••••4821', 5000, 'success'], ['Use of English Bee', 'Top 10 · 30 days Premium added', 0, 'soft']].map(([t, d, a, b]) => `
          <div class="list-item"><span class="lead" style="background:var(--c-accent-soft);color:var(--c-on-accent-soft)">${I('trophy', 1)}</span><span class="grow"><b class="t-sm">${t}</b><div class="t-cap muted">${d}</div></span><span class="badge badge-${b}">${a ? ST.naira(a) : 'Reward'}</span></div>`).join('')}
        </div>
        <p class="t-cap subtle" style="text-align:center">Sample data. Questions about a prize? Contact support on WhatsApp.</p>
      </div></div>`
  });
})();
