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

  // ---------- Home ----------
  def('home', {
    title: 'Home', group: 'Main tabs', tab: 'home',
    render: () => `
      <div class="scr-body">
        <div class="home-head">
          <button data-go="profile" aria-label="Open my profile" style="border-radius:50%">${ST.avatar()}</button>
          <div class="grow"><div class="t-cap muted">Good afternoon,</div><div class="t-h3">${S.first}</div></div>
          <span class="streak" title="${S.streak}-day streak">${I('fire', 1)} ${S.streak}</span>
          <button class="icon-btn" aria-label="Notifications" data-toast="2 new announcements">${I('bell')}</button>
        </div>
        <div class="px5 stack g6" style="padding-bottom:var(--s-8)">
          <div class="card goal-card enter">
            ${ring(0.6, 64, 3.6, '<b class="t-sm tnum">12/20</b>')}
            <div class="grow"><b>Today's goal</b><p class="t-sm muted">Answer 8 more questions to keep your ${S.streak}-day streak.</p></div>
          </div>

          <section data-tour="start">
            <div class="sect-title"><h2 class="t-h3">Start a CBT practice</h2></div>
            <div class="stack g2 enter">
              <button class="card card-tap exam-card" data-go="test-setup" data-params="body=JAMB">${examLogo('JAMB')}<div class="meta"><b>JAMB UTME</b><div class="t-cap muted">4 subjects · 180 questions · 2 hrs</div></div><span class="go">${I('play', 1)}</span></button>
              <button class="card card-tap exam-card locked" data-sheet="paywall" data-reason="WAEC">${examLogo('WAEC')}<div class="meta"><b>WAEC WASSCE</b><div class="t-cap muted">Objective papers by subject</div></div>${lockBadge}</button>
              <button class="card card-tap exam-card locked" data-sheet="paywall" data-reason="NECO">${examLogo('NECO')}<div class="meta"><b>NECO SSCE</b><div class="t-cap muted">Objective papers by subject</div></div>${lockBadge}</button>
            </div>
          </section>

          <button class="card card-tap continue-card" data-go="cbt">
            <div class="ic blue" style="width:44px;height:44px;border-radius:12px;display:grid;place-items:center;font-size:22px">${I('clock-counter-clockwise', 1)}</div>
            <div class="grow"><b class="t-sm">Continue your test</b><div class="t-cap muted">JAMB Mock · 64 of 180 answered · 1:12:40 left</div><div class="bar mt2"><i data-v="36%"></i></div></div>
            ${I('caret-right')}
          </button>

          <section>
            <div class="sect-title"><h2 class="t-h3">News</h2><button class="btn btn-ghost">See all</button></div>
            <div class="news">
              <div class="news-card n1"><i class="ph-fill ph-megaphone bg-ic"></i><span class="badge badge-gold" style="align-self:flex-start">New</span><div><b>JAMB 2026 Physics is now available</b><p class="t-sm" style="opacity:.8">40 questions with full solutions.</p></div></div>
              <div class="news-card n2"><i class="ph-fill ph-calendar-check bg-ic"></i><span class="badge" style="background:rgba(255,255,255,.18);color:#fff;align-self:flex-start">Reminder</span><div><b>UTME registration closes soon</b><p class="t-sm" style="opacity:.85">Check the JAMB brochure in Study.</p></div></div>
              <div class="news-card n3"><i class="ph-fill ph-video-camera bg-ic"></i><span class="badge" style="background:var(--navy-900);color:#fff;align-self:flex-start">Live class</span><div><b>Free Maths revision class</b><p class="t-sm">Saturday · 10:00 AM</p></div></div>
            </div>
          </section>

          <section class="card card-pad qotd">
            <div class="row between"><span class="badge badge-soft">${I('lightbulb', 1)} Question of the day</span><span class="t-cap muted">Mathematics</span></div>
            <p class="mt3" style="font-size:16px;line-height:25px">Evaluate $\\log_{2} 32 - \\log_{3} 27$.</p>
            <div class="grid2 mt3" id="qotd">
              ${['1', '2', '3', '5'].map((o, k) => `<button class="opt opt-mini" data-ok="${o === '2'}"><span class="key" style="width:30px;height:30px">${'ABCD'[k]}</span>${o}</button>`).join('')}
            </div>
          </section>

          <div class="upgrade-banner" data-tour="upgrade">
            <div class="crown">${I('crown-simple', 1)}</div>
            <div class="grow" style="position:relative;z-index:1"><b>Unlock all years and exams</b><p class="t-sm" style="color:#AFC0DD">WAEC, NECO, every year, 100 AI prompts a day.</p></div>
            <button class="btn btn-accent btn-sm" data-sheet="paywall" style="position:relative;z-index:1">Upgrade</button>
          </div>

          <section class="card card-pad row g3">
            <div class="ic gold" style="width:48px;height:48px;border-radius:12px;display:grid;place-items:center;font-size:24px">${I('video-camera', 1)}</div>
            <div class="grow"><span class="t-cap muted bold">Next live class</span><div class="bold">Physics: Waves and sound</div><div class="t-cap muted">Today · 4:00 PM · Mr. Bello</div></div>
            <button class="btn btn-tonal btn-sm" data-toast="Class link opens at 3:55 PM">Remind me</button>
          </section>
        </div>
      </div>`,
    mount(el) {
      ST.animateRings(el); ST.animateBars(el);
      el.querySelectorAll('#qotd .opt').forEach(b => b.onclick = () => {
        el.querySelectorAll('#qotd .opt').forEach(o => { o.disabled = true; if (o.dataset.ok === 'true') o.classList.add('right'); });
        if (b.dataset.ok !== 'true') b.classList.add('wrong'); else ST.toast('Correct! +10 XP', 'confetti');
      });
    }
  });

  // ---------- Study hub ----------
  def('study', {
    title: 'Study', group: 'Main tabs', tab: 'study',
    render: () => `
      <div class="appbar"><span class="title" style="padding-left:12px;font-size:var(--t-h2-size)">Study</span><button class="icon-btn" aria-label="Search">${I('magnifying-glass')}</button><button class="icon-btn" aria-label="Downloads" data-go="offline">${I('download-simple')}</button></div>
      <div class="scr-body"><div class="pad stack g6" style="padding-top:var(--s-2)">
        <div class="chips">${['All', 'Mathematics', 'English', 'Physics', 'Chemistry', 'Biology'].map((c, i) => `<button class="chip ${i ? '' : 'on'}">${c}</button>`).join('')}</div>
        <div class="grid2 enter">
          <button class="card card-tap study-tile" data-go="pq"><span class="ic navy">${I('exam', 1)}</span><span><b>Past questions</b><br><span class="t-cap muted">Study mode with answers</span></span></button>
          <button class="card card-tap study-tile" data-go="videos"><span class="ic blue">${I('play-circle', 1)}</span><span><b>Video solutions</b><br><span class="t-cap muted">Watch each answer</span></span></button>
          <button class="card card-tap study-tile" data-go="videos" data-params="kind=lessons"><span class="ic green">${I('chalkboard-teacher', 1)}</span><span><b>Topic lessons</b><br><span class="t-cap muted">By syllabus topic</span></span></button>
          <button class="card card-tap study-tile" data-go="note"><span class="ic gold">${I('note', 1)}</span><span><b>Lesson notes</b><br><span class="t-cap muted">Read, with formulas</span></span></button>
          <button class="card card-tap study-tile" data-go="novels"><span class="ic red">${I('books', 1)}</span><span><b>Novels</b><br><span class="t-cap muted">JAMB literature texts</span></span></button>
          <button class="card card-tap study-tile" data-go="doc"><span class="ic navy">${I('file-pdf', 1)}</span><span><b>Syllabus & brochure</b><br><span class="t-cap muted">JAMB, WAEC, NECO</span></span></button>
        </div>
        <section>
          <div class="sect-title"><h2 class="t-h3">Continue learning</h2></div>
          <div class="card list">
            <button class="list-item" data-go="note"><span class="lead">${I('note', 1)}</span><span class="grow"><b class="t-sm">Quadratic equations</b><div class="bar mt2" style="height:6px"><i data-v="64%"></i></div></span><span class="t-cap muted">64%</span></button>
            <button class="list-item" data-go="video"><span class="lead" style="background:var(--c-secondary-soft);color:var(--c-on-secondary-soft)">${I('play', 1)}</span><span class="grow"><b class="t-sm">JAMB 2002 Chemistry Q14</b><div class="t-cap muted">Video solution · 4:38</div></span>${I('caret-right').replace('class="', 'class="trail ')}</button>
          </div>
        </section>
        <section>
          <div class="sect-title"><h2 class="t-h3">Bookmarks</h2><button class="btn btn-ghost" data-go="empty">View all</button></div>
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
        <div class="seg" id="bodySeg"><button class="on">JAMB</button><button>WAEC</button><button>NECO</button></div>
        <div class="field"><span class="field-label">Subject</span><div class="input"><i class="ph ph-function lead-ic"></i><select><option>Mathematics</option><option>Use of English</option><option>Physics</option><option>Chemistry</option><option>Biology</option></select><i class="ph ph-caret-down sel-caret"></i></div></div>
        <div>
          <div class="sect-title"><h2 class="t-h3">Choose a year</h2><span class="t-cap muted">${I('lock-simple', 1)} = Premium</span></div>
          <div class="year-grid enter">
            ${[2000, 2001, 2002].map((y, k) => `<button class="year ${k === 0 ? 'done' : ''}" data-go="pq-study" data-params="year=${y}">${y}</button>`).join('')}
            ${Array.from({ length: 23 }, (_, k) => 2003 + k).map(y => `<button class="year locked" data-sheet="paywall" data-reason="${y}">${y}<i class="ph-fill ph-lock-simple lk"></i></button>`).join('')}
          </div>
        </div>
        <div class="banner info">${I('info', 1)}<span>Free plan: JAMB 2000, 2001 and 2002. Upgrade to open every year.</span></div>
      </div></div>`,
    mount(el) {
      el.querySelectorAll('#bodySeg button').forEach((b, i) => b.onclick = () => {
        if (i) { ST.openSheet('paywall', { reason: b.textContent }); return; }
      });
    }
  });

  def('pq-study', {
    title: 'Past question (study mode)', group: 'Study',
    render: p => `
      <div class="appbar lined"><button class="icon-btn" data-back="pq" aria-label="Back">${I('arrow-left')}</button>
        <span class="title">JAMB ${p.year || 2001} Mathematics<small>Study mode · Question 7 of 50</small></span>
        <button class="icon-btn" id="bm" aria-label="Bookmark">${I('bookmark-simple')}</button></div>
      <div class="scr-body"><div class="pad stack g4">
        <div class="row g2"><span class="badge badge-soft">Indices & logarithms</span><span class="badge badge-neutral">Medium</span></div>
        <p class="q-text" style="margin:0">If $\\log_{10} 2 = 0.3010$ and $\\log_{10} 3 = 0.4771$, evaluate $\\log_{10} 4.5$.</p>
        <div class="opts" id="opts">
          ${['0.6532', '0.6990', '0.6543', '0.7781'].map((o, k) => `<button class="opt" data-ok="${k === 0}"><span class="key">${'ABCD'[k]}</span>$${o}$</button>`).join('')}
        </div>
        <div id="exp" class="hidden stack g3">
          <div class="explain"><b>Explanation</b>
            <p class="mt2">Write $4.5$ using $2$ and $3$: $$4.5 = \\frac{9}{2} = \\frac{3^2}{2}$$</p>
            <p>So $\\log_{10} 4.5 = 2\\log_{10} 3 - \\log_{10} 2 = 2(0.4771) - 0.3010 = 0.6532$.</p></div>
          <div class="row g2"><button class="btn btn-tonal btn-sm grow" data-go="video">${I('play-circle', 1)} Watch solution</button><button class="btn btn-outline btn-sm grow" data-go="ai" data-params="q=log">${I('sparkle', 1)} Ask AI</button></div>
        </div>
      </div></div>
      <div class="cbt-bottom"><button class="btn btn-outline btn-sm">${I('caret-left')} Prev</button><span class="t-cap muted tnum">7 / 50</span><button class="btn btn-primary btn-sm">Next ${I('caret-right')}</button></div>`,
    mount(el) {
      el.querySelectorAll('#opts .opt').forEach(b => b.onclick = () => {
        el.querySelectorAll('#opts .opt').forEach(o => { o.disabled = true; if (o.dataset.ok === 'true') { o.classList.add('right'); o.insertAdjacentHTML('beforeend', `<span class="tag" style="color:var(--c-on-success-soft)">Correct answer</span>`); } });
        if (b.dataset.ok !== 'true') { b.classList.add('wrong'); b.insertAdjacentHTML('beforeend', `<span class="tag" style="color:var(--c-on-error-soft)">Your answer</span>`); }
        el.querySelector('#exp').classList.remove('hidden'); el.querySelector('#exp').classList.add('pop');
      });
      el.querySelector('#bm').onclick = e => { e.currentTarget.innerHTML = I('bookmark-simple', 1); e.currentTarget.style.color = 'var(--c-secondary)'; ST.toast('Saved to bookmarks', 'bookmark-simple'); };
    }
  });

  // ---------- Videos ----------
  const vids = [['th-1', 'JAMB 2002 Chemistry Q14', 'Mole concept', '4:38', 0, 'flask'], ['th-2', 'JAMB 2001 Physics Q3', 'Motion', '6:12', 0, 'atom'], ['th-3', 'JAMB 2015 Maths Q22', 'Probability', '7:05', 1, 'function'], ['th-4', 'JAMB 2019 Biology Q9', 'Genetics', '5:40', 1, 'dna']];
  def('videos', {
    title: 'Video solutions / lessons', group: 'Study',
    render: p => `
      <div class="appbar"><button class="icon-btn" data-back="study" aria-label="Back">${I('arrow-left')}</button><span class="title">${p.kind === 'lessons' ? 'Topic lessons' : 'Video solutions'}</span><button class="icon-btn" aria-label="Search">${I('magnifying-glass')}</button></div>
      <div class="scr-body"><div class="pad stack g4" style="padding-top:var(--s-2)">
        <div class="chips">${['All subjects', 'Mathematics', 'Physics', 'Chemistry', 'Biology'].map((c, i) => `<button class="chip ${i ? '' : 'on'}">${c}</button>`).join('')}</div>
        <div class="banner warn">${I('cell-signal-low', 1)}<span><b>Data saver is on.</b> Videos play in low quality. Download on Wi-Fi to watch offline.</span></div>
        <div class="stack g4 enter">${vids.map(([th, t, topic, d, lock, ic]) => `
          <button class="card card-tap" style="padding:10px" ${lock ? `data-sheet="paywall" data-reason="video"` : 'data-go="video"'}>
            <div class="thumb ${th}"><i class="ph-fill ph-${ic} sub-ic"></i><span class="play">${I(lock ? 'lock-simple' : 'play', 1)}</span><span class="dur">${d}</span>${lock ? `<span class="lock-chip badge badge-gold">${I('crown-simple', 1)} Premium</span>` : ''}</div>
            <div class="row between" style="padding:10px 4px 2px"><div><b class="t-sm">${t}</b><div class="t-cap muted">${topic}</div></div>${lock ? '' : `<span class="icon-btn" aria-label="Download">${I('download-simple')}</span>`}</div>
          </button>`).join('')}</div>
      </div></div>`
  });

  def('video', {
    title: 'Video player', group: 'Study',
    render: () => `
      <div class="appbar"><button class="icon-btn" data-back="videos" aria-label="Back">${I('arrow-left')}</button><span class="title">Video solution</span><button class="icon-btn" aria-label="More">${I('dots-three-vertical')}</button></div>
      <div class="thumb th-1" style="border-radius:0;flex:none"><i class="ph-fill ph-flask sub-ic"></i><span class="play" style="width:60px;height:60px;font-size:26px">${I('play', 1)}</span>
        <div style="position:absolute;left:12px;right:12px;bottom:10px"><div class="bar" style="height:4px;background:rgba(255,255,255,.25)"><i data-v="32%" style="background:var(--gold-400)"></i></div><div class="row between t-cap" style="margin-top:6px;color:#fff"><span>1:29</span><span>4:38</span></div></div></div>
      <div class="scr-body"><div class="pad stack g4">
        <div><h1 class="t-h2">JAMB 2002 Chemistry Q14</h1><p class="t-sm muted mt2">Mole concept · Mrs. Okonkwo · 4:38</p></div>
        <div class="row g2"><button class="btn btn-tonal btn-sm">${I('download-simple')} Download (18 MB)</button><button class="btn btn-outline btn-sm" id="q480">480p</button></div>
        <div class="card card-pad"><b class="t-sm">The question</b><p class="mt2">How many moles are in $4.4\\,\\text{g}$ of $\\text{CO}_2$? $(\\text{C}=12, \\text{O}=16)$</p></div>
        <div class="card card-pad"><b class="t-sm">Key working</b><p class="mt2">$$n = \\frac{m}{M} = \\frac{4.4}{44} = 0.1\\ \\text{mol}$$</p></div>
      </div></div>`,
    mount: el => ST.animateBars(el)
  });

  // ---------- Lesson note with LaTeX ----------
  def('note', {
    title: 'Lesson note (LaTeX)', group: 'Study',
    render: () => `
      <div class="read-progress"><i id="rp"></i></div>
      <div class="appbar lined"><button class="icon-btn" data-back="study" aria-label="Back">${I('arrow-left')}</button><span class="title">Quadratic equations<small>Mathematics · 8 min read</small></span>
        <button class="icon-btn" aria-label="Text size">${I('text-aa')}</button><button class="icon-btn" aria-label="Download">${I('download-simple')}</button></div>
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
        <p>A bad formula shows a safe fallback instead of breaking the page: $\\frac{1}{$</p>
        <div class="card card-pad stack g3 mt6" style="font-size:15px;line-height:22px">
          <b>Check yourself</b><p class="muted t-sm">Try 5 quick questions on this note.</p>
          <button class="btn btn-primary btn-block" data-go="cbt" data-params="mode=topic">Start topic drill</button>
        </div>
      </article></div>`,
    mount(el) {
      const sc = el.querySelector('#noteScroll'), rp = el.querySelector('#rp');
      sc.addEventListener('scroll', () => { rp.style.width = (sc.scrollTop / (sc.scrollHeight - sc.clientHeight) * 100) + '%'; }, { passive: true });
    }
  });

  // ---------- Novels ----------
  def('novels', {
    title: 'Novels', group: 'Study',
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
          <button class="stack g2" data-sheet="paywall" data-reason="novel"><div class="cover c1"><span class="lock-chip badge badge-gold">${I('lock-simple', 1)}</span><b>Poetry</b></div><span class="t-cap bold" style="text-align:left">Selected poems</span></button>
        </div>
      </div></div>`,
    mount: el => ST.animateBars(el)
  });

  def('novel', {
    title: 'Novel detail', group: 'Study',
    render: () => `
      <div class="appbar"><button class="icon-btn" data-back="novels" aria-label="Back">${I('arrow-left')}</button><span class="title">Featured novel</span><button class="icon-btn" aria-label="Bookmark">${I('bookmark-simple')}</button></div>
      <div class="scr-body"><div class="pad stack g5" style="padding-top:var(--s-2)">
        <div class="row g4"><div class="cover c1" style="width:88px;flex:none"><b>Novel (TBC)</b></div><div class="stack g1"><span class="badge badge-sample" style="align-self:flex-start">SAMPLE</span><h1 class="t-h2">Featured JAMB novel</h1><span class="t-sm muted">Author name · 12 chapters</span></div></div>
        <div class="seg"><button class="on">Summary</button><button>Themes</button><button>Characters</button><button>Quizzes</button></div>
        <div class="card list">${Array.from({ length: 6 }, (_, k) => `
          <button class="list-item" ${k > 3 ? 'data-sheet="paywall" data-reason="novel"' : 'data-toast="Opens chapter summary and quiz"'}><span class="lead" style="${k < 3 ? 'background:var(--c-success-soft);color:var(--c-on-success-soft)' : ''}">${k < 3 ? I('check', 1) : k + 1}</span>
            <span class="grow"><b class="t-sm">Chapter ${k + 1}</b><div class="t-cap muted">${k < 3 ? 'Quiz score 4/5' : '5-question quiz'}</div></span>${k > 3 ? I('lock-simple', 1).replace('class="', 'class="trail ') : I('caret-right').replace('class="', 'class="trail ')}</button>`).join('')}</div>
      </div></div>`
  });

  // ---------- Document (PDF) viewer ----------
  def('doc', {
    title: 'Syllabus / brochure viewer', group: 'Study',
    render: () => `
      <div class="appbar lined"><button class="icon-btn" data-back="study" aria-label="Back">${I('arrow-left')}</button><span class="title">JAMB syllabus: Mathematics<small>PDF · 24 pages · 1.2 MB</small></span><button class="icon-btn" aria-label="Download">${I('download-simple')}</button></div>
      <div class="row g2 px4" style="padding-block:10px;background:var(--c-surface);border-bottom:1px solid var(--c-border)">
        <div class="seg grow" style="max-width:220px"><button class="on">PDF</button><button id="topicsBtn">Topic list</button></div>
        <span class="grow"></span><span class="t-cap muted tnum">Page 3 / 24</span></div>
      <div class="scr-body pdf" id="pdfv">
        ${[1, 2].map(n => `<div class="pdf-page"><h4>${n === 1 ? 'SECTION I: NUMBER AND NUMERATION' : 'SECTION II: ALGEBRA'}</h4>
          <p style="margin-bottom:6px"><b>Topics:</b> ${n === 1 ? 'Number bases, fractions, decimals, indices, logarithms, surds, sets.' : 'Polynomials, variation, inequalities, progressions, binary operations, matrices.'}</p>
          ${Array.from({ length: 16 }, (_, k) => `<div class="ln" style="width:${60 + ((k * 37) % 40)}%"></div>`).join('')}</div>`).join('')}
      </div>
      <div class="hidden scr-body" id="topics"><div class="pad"><div class="card list">${['Number bases', 'Fractions, decimals, approximations', 'Indices, logarithms and surds', 'Sets', 'Polynomials', 'Variation', 'Inequalities', 'Progressions'].map((t, k) => `<button class="list-item"><span class="lead">${k + 1}</span><span class="grow t-sm bold">${t}</span>${I('caret-right').replace('class="', 'class="trail ')}</button>`).join('')}</div></div></div>`,
    mount(el) {
      const [a, b] = el.querySelectorAll('.seg button');
      a.onclick = () => { a.classList.add('on'); b.classList.remove('on'); el.querySelector('#pdfv').classList.remove('hidden'); el.querySelector('#topics').classList.add('hidden'); };
      b.onclick = () => { b.classList.add('on'); a.classList.remove('on'); el.querySelector('#pdfv').classList.add('hidden'); el.querySelector('#topics').classList.remove('hidden'); };
    }
  });

  // ---------- Test hub ----------
  def('test', {
    title: 'Test hub', group: 'Main tabs', tab: 'test',
    render: () => `
      <div class="appbar"><span class="title" style="padding-left:12px;font-size:var(--t-h2-size)">Test</span><button class="icon-btn" aria-label="History" data-go="profile">${I('clock-counter-clockwise')}</button></div>
      <div class="scr-body"><div class="pad stack g6" style="padding-top:var(--s-2)">
        <div class="card surface-navy card-pad stack g3" style="position:relative;overflow:hidden">
          <div class="row g3">${examLogo('JAMB', 'bare')}<div class="grow"><b>Full JAMB simulation</b><div class="t-cap muted">English + 3 subjects · 180 questions · 2 hours</div></div></div>
          <button class="btn btn-accent btn-block" data-go="test-setup" data-params="body=JAMB">Start full exam</button>
        </div>
        <section><div class="sect-title"><h2 class="t-h3">Practice modes</h2></div>
          <div class="stack g2 enter">
            ${[['book-open-text', 'navy', 'Single subject', 'One subject, timed like the real paper', 'test-setup', 'body=JAMB&mode=subject'],
               ['target', 'blue', 'Topic drill', 'Practise your weak topics only', 'test-setup', 'body=JAMB&mode=topic'],
               ['lightning', 'gold', 'Quick test', '20 questions · 15 minutes', 'cbt', 'mode=quick'],
               ['calendar-blank', 'green', 'Practice by year', 'Pick an exam year and go', 'pq', '']].map(([ic, c, t, d, go, pr]) => `
              <button class="card card-tap mode-card" data-go="${go}" ${pr ? `data-params="${pr}"` : ''}><span class="ic ${c}" style="width:44px;height:44px;border-radius:12px;display:grid;place-items:center;font-size:22px;flex:none">${I(ic, 1)}</span>
                <span class="grow"><b>${t}</b><br><span class="t-cap muted">${d}</span></span>${I('caret-right').replace('class="', 'class="trail ')}</button>`).join('')}
          </div></section>
        <section><div class="sect-title"><h2 class="t-h3">Other exams</h2></div>
          <div class="grid2">
            <button class="card card-tap exam-card locked" data-sheet="paywall" data-reason="WAEC" style="flex-direction:column;align-items:flex-start">${examLogo('WAEC')}<b class="t-sm">WAEC</b>${'<span class="badge badge-neutral">' + I('lock-simple', 1) + ' Premium</span>'}</button>
            <button class="card card-tap exam-card locked" data-sheet="paywall" data-reason="NECO" style="flex-direction:column;align-items:flex-start">${examLogo('NECO')}<b class="t-sm">NECO</b>${'<span class="badge badge-neutral">' + I('lock-simple', 1) + ' Premium</span>'}</button>
          </div></section>
        <section><div class="sect-title"><h2 class="t-h3">Downloaded packs</h2><button class="btn btn-ghost" data-go="offline">Manage</button></div>
          <div class="card list"><div class="list-item"><span class="lead">${I('cloud-check', 1)}</span><span class="grow"><b class="t-sm">JAMB 2000 to 2002 · all subjects</b><div class="t-cap muted">Works offline · 6.4 MB</div></span><span class="badge badge-success">Ready</span></div></div></section>
      </div></div>`
  });

  def('test-setup', {
    title: 'Test setup', group: 'Test & CBT',
    render: p => `
      <div class="appbar"><button class="icon-btn" data-back="test" aria-label="Back">${I('arrow-left')}</button><span class="title">JAMB UTME practice</span></div>
      <div class="scr-body"><div class="pad stack g5" style="padding-top:var(--s-2)">
        <div class="row g3">${examLogo('JAMB', 'lg')}<div><h1 class="t-h2">Set up your exam</h1><p class="t-sm muted">Rules come from the JAMB exam config.</p></div></div>
        <div class="field"><span class="field-label">Mode</span><div class="seg"><button class="${p.mode ? '' : 'on'}">Full exam</button><button class="${p.mode === 'subject' ? 'on' : ''}">Subject</button><button class="${p.mode === 'topic' ? 'on' : ''}">Topic</button></div></div>
        <div class="field"><span class="field-label">Your subjects</span>
          <div class="card list">${[['Use of English', 60, 'book-open-text'], ['Mathematics', 40, 'function'], ['Physics', 40, 'atom'], ['Chemistry', 40, 'flask']].map(([s, n, ic]) => `
            <div class="list-item"><span class="lead">${I(ic, 1)}</span><span class="grow t-sm bold">${s}</span><span class="t-cap muted tnum">${n} questions</span></div>`).join('')}</div>
          <button class="btn btn-ghost btn-sm" style="align-self:flex-start">Change subjects</button></div>
        <div class="field"><span class="field-label">Year</span><div class="chips">${['Mixed (free years)', '2000', '2001', '2002'].map((y, i) => `<button class="chip ${i ? '' : 'on'}">${y}</button>`).join('')}<button class="chip" data-sheet="paywall" data-reason="years">${I('lock-simple', 1)} 2003 to 2025</button></div></div>
        <div class="card card-pad row g4" style="justify-content:space-around;text-align:center">
          <div><b class="t-h2 tnum">180</b><div class="t-cap muted">questions</div></div><div><b class="t-h2 tnum">2:00</b><div class="t-cap muted">hours</div></div><div><b class="t-h2 tnum">400</b><div class="t-cap muted">max score</div></div></div>
        <div class="banner info">${I('wifi-slash', 1)}<span>This pack is downloaded. You can take this exam offline.</span></div>
      </div></div>
      <div class="footer-cta"><button class="btn btn-primary btn-block" data-go="cbt">Start exam</button></div>`
  });
})();
