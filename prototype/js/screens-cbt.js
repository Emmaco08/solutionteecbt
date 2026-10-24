/* CBT exam, palette, calculator, submit, auto-submit, results, review. */
(function () {
  const { def, icon: I, examLogo } = ST;
  const S = ST.state;

  const PASSAGE = `<p>Every market day, Mama Ronke opened her provision stall before the first light reached the road. Customers trusted her because she kept honest scales and remembered the names of their children. When a bigger supermarket opened across the street, her neighbours told her to give up.</p>
    <p>She did not argue. Instead, she began to deliver orders to elderly customers who could no longer walk to the market, and she wrote their lists in a small exercise book. Within a year, the book had grown into three books, and her stall had become the busiest on the street.</p>
    <p>"A shop sells goods," she once said, "but a good trader sells trust." Her nephew, who had just finished secondary school, wrote the sentence on a piece of cardboard and hung it above the stall.</p>`;

  const BANK = {
    eng: [
      { p: 1, q: 'Why did customers trust Mama Ronke?', o: ['She sold goods very cheaply', 'She kept honest scales and knew her customers well', 'She opened before the supermarket', 'Her nephew advised them to'], a: 1 },
      { p: 1, q: 'What did Mama Ronke do when the supermarket opened?', o: ['She closed her stall', 'She argued with her neighbours', 'She started delivering to elderly customers', 'She reduced her prices'], a: 2 },
      { p: 1, q: 'The word <b>"busiest"</b>, as used in the passage, means', o: ['having the most activity', 'the most tiring', 'the most expensive', 'the most crowded with goods'], a: 0 },
      { p: 1, q: 'The main lesson of the passage is that', o: ['supermarkets are bad for trade', 'trust can be a trader\'s greatest asset', 'young people should become traders', 'elderly people need help'], a: 1 },
      { p: 1, q: 'Which of these is a suitable title for the passage?', o: ['The New Supermarket', 'The Trader Who Sold Trust', 'My Nephew\'s Cardboard', 'Market Day'], a: 1 },
      { q: 'Choose the option nearest in meaning to the underlined word: The principal was <u>adamant</u> about the new rule.', o: ['unsure', 'firm', 'angry', 'quiet'], a: 1 },
      { q: 'Choose the option that best completes the sentence: Neither the teacher nor the students ____ in the hall.', o: ['was', 'were', 'is', 'has been'], a: 1 }
    ],
    mth: [
      { q: 'Solve for $x$: $\\;2^{x+1} = 32$', o: ['$3$', '$4$', '$5$', '$16$'], a: 1, topic: 'Indices' },
      { q: 'Find the roots of $x^2 - 5x + 6 = 0$.', o: ['$x = 2$ or $3$', '$x = -2$ or $-3$', '$x = 1$ or $6$', '$x = -1$ or $6$'], a: 0, topic: 'Quadratics' },
      { q: 'Evaluate $$\\int_0^2 (3x^2 + 1)\\,dx$$', o: ['$8$', '$10$', '$12$', '$14$'], a: 1, topic: 'Integration' },
      { q: 'If $\\sin\\theta = \\frac{3}{5}$ and $\\theta$ is acute, find $\\tan\\theta$.', o: ['$\\frac{3}{4}$', '$\\frac{4}{3}$', '$\\frac{4}{5}$', '$\\frac{5}{4}$'], a: 0, topic: 'Trigonometry' },
      { q: 'A bag has 4 red and 6 blue balls. A ball is picked at random. Find the probability that it is red.', o: ['$\\frac{2}{5}$', '$\\frac{3}{5}$', '$\\frac{1}{4}$', '$\\frac{2}{3}$'], a: 0, topic: 'Probability' }
    ],
    phy: [
      { q: 'A car accelerates uniformly from rest to $20\\,\\text{m s}^{-1}$ in $5\\,\\text{s}$. Find its acceleration.', o: ['$2\\,\\text{m s}^{-2}$', '$4\\,\\text{m s}^{-2}$', '$5\\,\\text{m s}^{-2}$', '$100\\,\\text{m s}^{-2}$'], a: 1 },
      { q: 'Which of these is a vector quantity?', o: ['Speed', 'Mass', 'Displacement', 'Energy'], a: 2 }
    ],
    chm: [
      { q: 'How many moles are in $4.4\\,\\text{g}$ of $\\text{CO}_2$? $(\\text{C} = 12,\\ \\text{O} = 16)$', o: ['$0.01$', '$0.1$', '$1.0$', '$10$'], a: 1 },
      { q: 'The pH of a neutral solution at $25^\\circ\\text{C}$ is', o: ['$0$', '$1$', '$7$', '$14$'], a: 2 }
    ]
  };
  const SUBJ = [{ k: 'eng', n: 'English', total: 60 }, { k: 'mth', n: 'Mathematics', total: 40 }, { k: 'phy', n: 'Physics', total: 40 }, { k: 'chm', n: 'Chemistry', total: 40 }];

  // Shared exam state (would live in drift + autosave every answer in the real app)
  const fresh = () => {
    const ans = {}, flags = new Set();
    for (let i = 1; i <= 34; i++) ans['eng:' + i] = i % 4;
    for (let i = 1; i <= 11; i++) if (i !== 6) ans['mth:' + i] = i % 4;
    for (let i = 1; i <= 12; i++) ans['phy:' + i] = (i + 1) % 4;
    for (let i = 1; i <= 7; i++) ans['chm:' + i] = i % 4;
    ['mth:4', 'mth:9', 'eng:12', 'phy:3'].forEach(f => flags.add(f));
    return { subj: 'mth', n: 12, ans, flags, left: 72 * 60 + 40 };
  };
  ST.cbt = ST.cbt || fresh();
  ST.cbtSetTime = s => { ST.cbt.left = s; ST.cbt._tick?.(); };

  const fmt = s => { s = Math.max(0, s); const h = Math.floor(s / 3600), m = Math.floor(s % 3600 / 60), x = s % 60; return `${h}:${String(m).padStart(2, '0')}:${String(x).padStart(2, '0')}`; };
  const counts = k => { const s = SUBJ.find(x => x.k === k); let a = 0, f = 0; for (let i = 1; i <= s.total; i++) { if ((k + ':' + i) in ST.cbt.ans) a++; if (ST.cbt.flags.has(k + ':' + i)) f++; } return { a, f, u: s.total - a, total: s.total }; };
  const qFor = (k, n) => { const b = BANK[k]; if (k === 'eng') return n <= 5 ? b[n - 1] : b[5 + (n % 2)]; return b[(n - 1) % b.length]; };

  def('cbt', {
    title: 'CBT exam screen', group: 'Test & CBT', cls: 'cbt',
    render: () => `
      <div class="cbt-top">
        ${examLogo('JAMB', 'sm')}
        <div class="who"><b>${S.name}</b><span class="tnum">Reg. ${S.reg} · UTME Mock</span></div>
        <button class="timer" id="timer" aria-live="off" aria-label="Time left">${I('timer', 1)}<span class="tnum" id="tm">--</span></button>
      </div>
      <div class="subj-tabs" id="tabs" role="tablist"></div>
      <div class="passage hidden" id="passage">
        <button class="passage-head" id="pHead">${I('article', 1)}<span class="grow">Read the passage and answer questions 1 to 5</span><i class="ph ph-caret-up caret"></i></button>
        <div class="passage-body">${PASSAGE}</div>
      </div>
      <div class="q-area" id="qa"></div>
      <div class="cbt-bottom">
        <div class="row g1"><button class="btn btn-outline btn-sm" id="prev">${I('caret-left')} Prev</button></div>
        <div class="row g1">
          <button class="icon-btn" id="calcBtn" aria-label="Calculator">${I('calculator')}</button>
          <button class="icon-btn" id="palBtn" aria-label="Question palette">${I('squares-four')}</button>
          <button class="icon-btn flag-btn" id="flag" aria-label="Flag question">${I('flag')}</button>
        </div>
        <div class="row g1" style="justify-content:flex-end"><button class="btn btn-primary btn-sm" id="next">Next ${I('caret-right')}</button></div>
      </div>`,
    mount(el, p) {
      const st = ST.cbt;
      if (p.mode === 'quick' || p.mode === 'topic') { st.subj = 'mth'; st.n = 1; }
      const tabs = el.querySelector('#tabs'), qa = el.querySelector('#qa'), pas = el.querySelector('#passage');

      const drawTabs = () => {
        tabs.innerHTML = SUBJ.map(s => { const c = counts(s.k); return `<button class="subj-tab ${st.subj === s.k ? 'on' : ''}" role="tab" data-s="${s.k}">${s.n}<span class="cnt">${c.a}/${c.total}</span></button>`; }).join('') +
          `<button class="subj-tab" id="submitTab" style="color:var(--c-error)">${I('paper-plane-tilt', 1)} Submit</button>`;
        tabs.querySelectorAll('[data-s]').forEach(b => b.onclick = () => { st.subj = b.dataset.s; st.n = 1; draw(true); });
        tabs.querySelector('#submitTab').onclick = openSubmit;
      };
      const draw = (anim) => {
        const s = SUBJ.find(x => x.k === st.subj), q = qFor(st.subj, st.n), key = st.subj + ':' + st.n, sel = st.ans[key];
        pas.classList.toggle('hidden', !q.p);
        qa.innerHTML = `
          <div class="q-meta"><span class="t-label">Question <span class="tnum">${st.n}</span> <span class="muted" style="font-weight:500">of ${s.total}</span></span>
            ${st.flags.has(key) ? `<span class="badge badge-warning">${I('flag', 1)} Flagged</span>` : `<span class="t-cap muted">${s.n}</span>`}</div>
          <div class="q-text ${anim ? 'swap' : ''}">${q.q}</div>
          <div class="opts" role="radiogroup">${q.o.map((o, i) => `<button class="opt ${sel === i ? 'sel' : ''}" role="radio" aria-checked="${sel === i}" data-i="${i}"><span class="key">${'ABCDE'[i]}</span><span>${o}</span></button>`).join('')}</div>`;
        ST.math(qa);
        qa.scrollTop = 0;
        qa.querySelectorAll('.opt').forEach(b => b.onclick = () => {
          st.ans[key] = +b.dataset.i;
          qa.querySelectorAll('.opt').forEach(o => { o.classList.toggle('sel', o === b); o.setAttribute('aria-checked', o === b); });
          drawTabs();
        });
        const fl = el.querySelector('#flag'); fl.classList.toggle('on', st.flags.has(key)); fl.innerHTML = I('flag', st.flags.has(key));
        el.querySelector('#prev').disabled = st.n === 1;
        drawTabs();
      };
      el.querySelector('#prev').onclick = () => { if (st.n > 1) { st.n--; draw(true); } };
      el.querySelector('#next').onclick = () => {
        const s = SUBJ.find(x => x.k === st.subj);
        if (st.n < s.total) { st.n++; draw(true); }
        else { const i = SUBJ.indexOf(s); if (SUBJ[i + 1]) { st.subj = SUBJ[i + 1].k; st.n = 1; draw(true); } else openSubmit(); }
      };
      el.querySelector('#flag').onclick = () => { const k = st.subj + ':' + st.n; st.flags.has(k) ? st.flags.delete(k) : st.flags.add(k); draw(false); };
      el.querySelector('#pHead').onclick = () => pas.classList.toggle('collapsed');

      // Palette
      el.querySelector('#palBtn').onclick = () => {
        const s = SUBJ.find(x => x.k === st.subj), c = counts(st.subj);
        ST.sheet(`
          <div class="row between"><h2 class="t-h3">${s.n}</h2><span class="t-sm muted tnum">${c.a} answered · ${c.u} left</span></div>
          <div class="legend mt3"><span><i style="background:var(--c-answered)"></i>Answered</span><span><i style="box-shadow:inset 0 0 0 1.5px var(--c-unanswered)"></i>Not answered</span><span><i style="background:var(--c-flagged);border-radius:50%"></i>Flagged</span><span><i style="box-shadow:inset 0 0 0 2.5px var(--c-current)"></i>Current</span></div>
          <div class="palette mt4">${Array.from({ length: s.total }, (_, i) => { const k = st.subj + ':' + (i + 1); return `<button class="pal ${k in st.ans ? 'ans' : ''} ${st.flags.has(k) ? 'flag' : ''} ${st.n === i + 1 ? 'cur' : ''}" data-n="${i + 1}" aria-label="Question ${i + 1}">${i + 1}</button>`; }).join('')}</div>
          <button class="btn btn-outline btn-block mt6" id="subFromPal">Submit exam</button>`, {
          mount: w => {
            w.querySelectorAll('.pal').forEach(b => b.onclick = () => { st.n = +b.dataset.n; ST.closeOverlay(); draw(true); });
            w.querySelector('#subFromPal').onclick = () => { ST.closeOverlay(true); openSubmit(); };
          }
        });
      };

      // Calculator
      el.querySelector('#calcBtn').onclick = () => {
        const keys = ['C', '⌫', '%', '÷', '7', '8', '9', '×', '4', '5', '6', '−', '1', '2', '3', '+', '±', '0', '.', '='];
        ST.sheet(`<div class="row between"><h2 class="t-h3">Calculator</h2><button class="icon-btn" data-close aria-label="Close">${I('x')}</button></div>
          <div class="calc-screen"><div class="expr" id="cx"></div><div class="val" id="cv">0</div></div>
          <div class="calc">${keys.map(k => `<button class="${'÷×−+%'.includes(k) ? 'op' : k === '=' ? 'eq' : ''}" data-k="${k}">${k}</button>`).join('')}</div>`, {
          mount: w => {
            let expr = '', cur = '0';
            const cx = w.querySelector('#cx'), cv = w.querySelector('#cv');
            const show = () => { cx.textContent = expr; cv.textContent = cur; };
            const evaluate = s => { const js = s.replace(/×/g, '*').replace(/÷/g, '/').replace(/−/g, '-'); if (!/^[\d.+\-*/() ]+$/.test(js)) return 'Error';
              try { const v = Function('"use strict";return (' + js + ')')(); return Number.isFinite(v) ? String(+v.toFixed(10)) : 'Error'; } catch (e) { return 'Error'; } };
            w.querySelectorAll('[data-k]').forEach(b => b.onclick = () => {
              const k = b.dataset.k;
              if (k === 'C') { expr = ''; cur = '0'; }
              else if (k === '⌫') cur = cur.length > 1 ? cur.slice(0, -1) : '0';
              else if (k === '±') cur = cur.startsWith('-') ? cur.slice(1) : (cur === '0' ? '0' : '-' + cur);
              else if (k === '%') cur = String(parseFloat(cur) / 100);
              else if ('÷×−+'.includes(k)) { expr += cur + ' ' + k + ' '; cur = '0'; }
              else if (k === '=') { const r = evaluate(expr + cur); expr = expr + cur + ' ='; cur = r; }
              else { if (expr.endsWith('=')) expr = ''; cur = cur === '0' && k !== '.' ? k : (k === '.' && cur.includes('.') ? cur : cur + k); }
              show();
            });
          }
        });
      };

      // Submit + auto-submit
      function openSubmit() {
        const rows = SUBJ.map(s => { const c = counts(s.k); return `<div class="sum-row"><span class="bold">${s.n}</span><span style="color:var(--c-success)">${c.a}</span><span style="color:${c.u ? 'var(--c-error)' : 'inherit'}">${c.u}</span><span style="color:var(--c-warning)">${c.f}</span></div>`; }).join('');
        const tot = SUBJ.reduce((t, s) => t + counts(s.k).u, 0);
        ST.dialog(`<div class="stack g3"><div class="ic red" style="width:52px;height:52px;border-radius:14px;display:grid;place-items:center;font-size:26px">${I('paper-plane-tilt', 1)}</div>
          <h2 class="t-h2">Submit your exam?</h2>
          <p class="t-sm muted">You still have <b style="color:var(--c-text)">${fmt(st.left)}</b> left and <b style="color:var(--c-error)">${tot} unanswered</b> questions. You cannot change answers after you submit.</p>
          <div class="card" style="padding:4px 12px"><div class="sum-row t-cap muted"><span>Subject</span><span>Done</span><span>Left</span><span>Flag</span></div>${rows}</div>
          <div class="grid2 mt2"><button class="btn btn-outline" data-close>Keep working</button><button class="btn btn-danger" id="doSubmit">Submit now</button></div></div>`, {
          mount: w => w.querySelector('#doSubmit').onclick = () => { const b = w.querySelector('#doSubmit'); b.classList.add('is-loading'); b.textContent = ''; setTimeout(() => { clearInterval(iv); ST.go('results', null, { mode: 'fade' }); }, 700); }
        });
      }
      ST.cbtSubmit = openSubmit;

      // Timer
      const tEl = el.querySelector('#timer'), tm = el.querySelector('#tm');
      const tick = () => {
        tm.textContent = fmt(st.left);
        tEl.classList.toggle('warn', st.left <= 600 && st.left > 300);
        tEl.classList.toggle('danger', st.left <= 300);
        tEl.setAttribute('aria-label', 'Time left ' + fmt(st.left));
        if (st.left <= 0) {
          clearInterval(iv); ST.closeOverlay(true);
          ST.dialog(`<div class="stack g3" style="text-align:center;align-items:center"><div class="ic red" style="width:60px;height:60px;border-radius:18px;display:grid;place-items:center;font-size:30px">${I('alarm', 1)}</div>
            <h2 class="t-h2">Time is up</h2><p class="t-sm muted">Your answers were saved and submitted automatically.</p>
            <button class="btn btn-primary btn-block" id="seeRes">See my results</button></div>`, { sticky: true, mount: w => w.querySelector('#seeRes').onclick = () => ST.go('results', null, { mode: 'fade' }) });
        }
      };
      st._tick = tick;
      const iv = setInterval(() => { if (!el.isConnected) return clearInterval(iv); st.left--; tick(); }, 1000);
      tEl.onclick = () => ST.sheet(`<h2 class="t-h3">Time left: <span class="tnum">${fmt(st.left)}</span></h2>
        <p class="t-sm muted mt2">The timer turns amber at 10 minutes and red at 5 minutes. When it reaches zero, your exam submits automatically. If your phone dies, you continue from where you stopped.</p>
        <div class="banner warn mt4">${I('wrench', 1)}<span><b>Prototype demo:</b> jump the timer to see each state.</span></div>
        <div class="grid3 mt3"><button class="btn btn-outline btn-sm" data-t="600">10:00</button><button class="btn btn-outline btn-sm" data-t="300">5:00</button><button class="btn btn-outline btn-sm" data-t="4">Time up</button></div>`,
        { mount: w => w.querySelectorAll('[data-t]').forEach(b => b.onclick = () => { ST.closeOverlay(); ST.cbtSetTime(+b.dataset.t); }) });
      tick(); draw(false);
      if (p.resume) ST.toast('Welcome back. We saved your answers.', 'cloud-check');
    }
  });

  // ---------- Results ----------
  def('results', {
    title: 'Results (celebration)', group: 'Test & CBT',
    noStatus: false, navy: true,
    render: () => `
      <canvas id="confetti"></canvas>
      <div class="appbar" style="background:transparent"><button class="icon-btn" data-go="home" data-mode="fade" aria-label="Close" style="color:#fff">${I('x')}</button><span class="title" style="text-align:center;padding-right:48px">Your result</span></div>
      <div class="scr-body" style="background:var(--c-bg)">
        <div class="res-hero">
          <div class="row center g2">${examLogo('JAMB', 'sm')}<span class="t-sm muted">JAMB UTME Mock · 24 Oct 2026</span></div>
          ${ST.ring(0.7175, 176, 3.2, `<span><span class="score tnum" id="sc">0</span><br><span class="of">out of 400</span></span>`)}
          <h1 class="t-h2">Great work, ${S.first}!</h1>
          <p class="t-sm muted mt2">You beat your last score by <b style="color:var(--gold-400)">38 points</b>.</p>
        </div>
        <div class="kpis">
          <div class="card kpi"><b class="tnum">71%</b><span>Accuracy</span></div>
          <div class="card kpi"><b class="tnum">38s</b><span>Per question</span></div>
          <div class="card kpi"><b class="tnum">1:54</b><span>Time used</span></div>
        </div>
        <div class="pad stack g5">
          <section class="card card-pad stack g4"><h2 class="t-h3">Score by subject</h2>
            ${[['Use of English', 78], ['Mathematics', 64], ['Physics', 70], ['Chemistry', 75]].map(([s, v]) => `<div class="subj-score"><span class="t-sm bold">${s}</span><span class="t-sm bold tnum">${v}/100</span><div class="bar ${v >= 70 ? 'ok' : ''}"><i data-v="${v}%"></i></div></div>`).join('')}
          </section>
          <section class="card card-pad stack g3"><h2 class="t-h3">Topics to practise</h2>
            <div class="row wrap g2">${['Integration', 'Probability', 'Organic chemistry', 'Concord'].map(t => `<span class="chip" style="cursor:default">${I('target')} ${t}</span>`).join('')}</div>
            <button class="btn btn-tonal btn-block" data-go="test-setup" data-params="body=JAMB&mode=topic">Practise weak topics</button>
          </section>
          <div class="grid2"><button class="btn btn-primary" data-go="review">Review answers</button><button class="btn btn-outline" id="share">${I('share-network')} Share</button></div>
        </div>
      </div>`,
    mount(el) {
      ST.animateRings(el); ST.animateBars(el);
      const sc = el.querySelector('#sc'), target = 287, t0 = performance.now(), dur = ST.reduceMotion() ? 1 : 1100;
      const step = t => { const k = Math.min(1, (t - t0) / dur); sc.textContent = Math.round(target * (1 - Math.pow(1 - k, 3))); if (k < 1) requestAnimationFrame(step); };
      requestAnimationFrame(step);
      if (!ST.reduceMotion()) confetti(el.querySelector('#confetti'));
      el.querySelector('#share').onclick = () => ST.sheet(`<h2 class="t-h3">Share your result</h2>
        <div class="share-card mt4"><div class="row g2"><img src="/brand/mark-dark.png" alt="" style="height:22px"><b class="t-sm">SolutionTee CBT</b></div>
          <p class="t-sm mt4" style="color:#AFC0DD">${S.first} scored</p><div style="font-size:56px;line-height:1;font-weight:700;letter-spacing:-1px" class="tnum">287<span style="font-size:18px;color:#AFC0DD"> / 400</span></div>
          <p class="t-sm mt2" style="color:#AFC0DD">JAMB UTME practice · Learn. Think. Solve.</p></div>
        <div class="grid2 mt4"><button class="btn btn-accent" data-toast="Opens WhatsApp share">${I('whatsapp-logo', 1)} WhatsApp</button><button class="btn btn-outline" data-toast="Image saved to gallery">${I('download-simple')} Save image</button></div>`);
    }
  });
  // reset exam state for next run, but keep it until results first renders
  const origResults = ST.screens.results.mount;
  ST.screens.results.mount = (el, p) => { origResults(el, p); ST.cbt = fresh(); };

  function confetti(cv) {
    const ctx = cv.getContext('2d'), W = cv.width = cv.offsetWidth * 2, H = cv.height = cv.offsetHeight * 2;
    const cols = ['#F2B233', '#2563B3', '#FFFFFF', '#7AA0D1', '#F6C970'];
    const ps = Array.from({ length: 90 }, () => ({ x: W / 2 + (Math.random() - .5) * 120, y: H * .32, vx: (Math.random() - .5) * 26, vy: -Math.random() * 30 - 10, s: 6 + Math.random() * 10, r: Math.random() * 6, vr: (Math.random() - .5) * .3, c: cols[Math.random() * cols.length | 0] }));
    const t0 = performance.now();
    (function f(t) {
      ctx.clearRect(0, 0, W, H);
      const age = (t - t0) / 1000;
      ps.forEach(p => { p.vy += 1.1; p.vx *= .985; p.x += p.vx; p.y += p.vy; p.r += p.vr;
        ctx.save(); ctx.translate(p.x, p.y); ctx.rotate(p.r); ctx.globalAlpha = Math.max(0, 1 - age / 2.4); ctx.fillStyle = p.c; ctx.fillRect(-p.s / 2, -p.s / 4, p.s, p.s / 2); ctx.restore(); });
      if (age < 2.4 && cv.isConnected) requestAnimationFrame(f); else ctx.clearRect(0, 0, W, H);
    })(t0);
  }
  ST.confetti = confetti;

  // ---------- Review ----------
  def('review', {
    title: 'Review answers', group: 'Test & CBT',
    render: () => `
      <div class="appbar lined"><button class="icon-btn" data-back="results" aria-label="Back">${I('arrow-left')}</button><span class="title">Review<small>Mathematics · Question 3 of 40</small></span></div>
      <div class="px4" style="padding-block:10px;background:var(--c-bg)"><div class="chips">${[['All', 40], ['Wrong', 12], ['Flagged', 2], ['Skipped', 2]].map(([c, n], i) => `<button class="chip ${i === 1 ? 'on' : ''}">${c} <span class="tnum" style="opacity:.7">${n}</span></button>`).join('')}</div></div>
      <div class="scr-body"><div class="pad stack g4" style="padding-top:var(--s-2)">
        <div class="row g2"><span class="badge badge-error">${I('x-circle', 1)} Wrong</span><span class="badge badge-soft">Integration</span><span class="t-cap muted" style="margin-left:auto">You took 1m 12s</span></div>
        <p class="q-text" style="margin:0">Evaluate $$\\int_0^2 (3x^2 + 1)\\,dx$$</p>
        <div class="opts">
          <div class="opt"><span class="key">A</span>$8$</div>
          <div class="opt right"><span class="key">B</span>$10$<span class="tag" style="color:var(--c-on-success-soft)">Correct answer</span></div>
          <div class="opt wrong"><span class="key">C</span>$12$<span class="tag" style="color:var(--c-on-error-soft)">Your answer</span></div>
          <div class="opt"><span class="key">D</span>$14$</div>
        </div>
        <div class="explain"><b>Explanation</b>
          <p class="mt2">Integrate each term, then substitute the limits:</p>
          $$\\int_0^2 (3x^2+1)\\,dx = \\Big[x^3 + x\\Big]_0^2 = (8 + 2) - 0 = 10$$
          <p>A common trap is forgetting the $+x$ from integrating $1$, which gives $8$.</p></div>
        <button class="btn btn-accent btn-block" data-go="ai" data-params="q=integral">${I('sparkle', 1)} Ask SolutionTee AI to explain</button>
        <p class="t-cap muted" style="text-align:center">Uses 1 AI prompt · ${S.aiLeft} left today</p>
      </div></div>
      <div class="cbt-bottom"><button class="btn btn-outline btn-sm">${I('caret-left')} Prev</button><span class="t-cap muted tnum">3 / 12 wrong</span><button class="btn btn-primary btn-sm">Next ${I('caret-right')}</button></div>`
  });
})();
