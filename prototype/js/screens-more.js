/* Paywall + payments, AI tutor, profile/settings/help/delete, system states. */
(function () {
  const { def, icon: I, examLogo, mark } = ST;
  const S = ST.state;
  const PLANS = [
    { id: 'm', name: 'Monthly', price: 1500, per: '1 month', note: 'Billed once. No auto-renew.' },
    { id: 'q', name: '3 Months', price: 3500, per: '3 months', note: 'Save ₦1,000', best: true },
    { id: 'e', name: 'Exam Season', price: 6000, per: 'Until 31 Jul 2027', note: 'Covers JAMB, WAEC and NECO 2027' }
  ];
  ST.PLANS = PLANS;
  const planRow = (p, on) => `<button class="plan ${on ? 'on' : ''}" data-plan="${p.id}">${p.best ? '<span class="best badge badge-gold">Best value</span>' : ''}<span class="radio"></span>
    <span class="grow"><b>${p.name}</b><br><span class="t-cap muted">${p.note}</span></span><span class="price"><b>${ST.naira(p.price)}</b><span class="t-cap muted">${p.per}</span></span></button>`;
  const bindPlans = (root, cb) => root.querySelectorAll('[data-plan]').forEach(b => b.onclick = () => { root.querySelectorAll('[data-plan]').forEach(x => x.classList.toggle('on', x === b)); cb && cb(b.dataset.plan); });

  // ---------- Paywall bottom sheet ----------
  const REASONS = { WAEC: 'WAEC is a Premium exam', NECO: 'NECO is a Premium exam', video: 'This video is Premium', novel: 'This chapter is Premium', ai: 'Get more AI prompts', years: 'More years are Premium' };
  ST.sheets.paywall = (d) => {
    const head = REASONS[d.reason] || (/^\d{4}$/.test(d.reason || '') ? `JAMB ${d.reason} is Premium` : 'Go Premium');
    let pick = 'q';
    ST.sheet(`
      <div class="stack g4">
        <div class="row g3"><div class="upgrade-banner" style="padding:0;width:52px;height:52px;border-radius:14px;justify-content:center;flex:none"><span class="crown" style="width:52px;height:52px;border-radius:14px">${I('crown-simple', 1)}</span></div>
          <div><h2 class="t-h2">${head}</h2><p class="t-sm muted">Unlock everything and practise without limits.</p></div></div>
        <div class="stack g3 enter">
          ${['All JAMB years, not just 2000 to 2002', 'WAEC and NECO past questions and CBT', '100 AI tutor prompts every day', 'Every video, lesson note and novel', 'Download everything for offline use'].map(b => `<div class="benefit">${I('check-circle', 1)}<span>${b}</span></div>`).join('')}
        </div>
        <div class="row between"><span class="t-label">Choose a plan</span><span class="badge badge-sample">SAMPLE PRICES</span></div>
        <div class="stack g3" style="padding-top:6px">${PLANS.map(p => planRow(p, p.id === pick)).join('')}</div>
        <button class="btn btn-primary btn-block" id="pwGo">Continue with 3 Months · ${ST.naira(3500)}</button>
        <p class="t-cap muted" style="text-align:center">Secure payment. Premium starts as soon as payment is confirmed.</p>
      </div>`, {
      mount: w => {
        const go = w.querySelector('#pwGo');
        bindPlans(w, id => { pick = id; const p = PLANS.find(x => x.id === id); go.textContent = `Continue with ${p.name} · ${ST.naira(p.price)}`; });
        go.onclick = () => ST.go('checkout', { plan: pick });
      }
    });
  };

  def('paywall', {
    title: 'Paywall bottom sheet', group: 'Premium & payments',
    render: p => ST.screens.pq.render(p),
    mount: (el) => { ST.screens.pq.mount(el); setTimeout(() => ST.openSheet('paywall', { reason: '2015' }), 250); }
  });

  // ---------- Checkout (two build flavours) ----------
  def('checkout', {
    title: 'Plan checkout (Play / Paystack)', group: 'Premium & payments',
    render: p => {
      const plan = PLANS.find(x => x.id === (p.plan || 'q'));
      return `
      <div class="appbar"><button class="icon-btn" data-back="home" aria-label="Back">${I('arrow-left')}</button><span class="title">Checkout</span></div>
      <div class="scr-body"><div class="pad stack g5" style="padding-top:var(--s-2)">
        <div class="banner warn">${I('wrench', 1)}<span><b>Prototype:</b> switch build to see both payment flows.</span></div>
        <div class="seg" id="flv"><button class="${S.payFlavor === 'play' ? 'on' : ''}" data-f="play">Play Store build</button><button class="${S.payFlavor === 'direct' ? 'on' : ''}" data-f="direct">Website APK build</button></div>
        <div class="card card-pad stack g3">
          <div class="row between"><span class="t-sm muted">Plan</span><span class="badge badge-sample">SAMPLE</span></div>
          <div class="row between"><b class="t-h3">SolutionTee Premium · ${plan.name}</b></div>
          <div class="row between t-sm"><span class="muted">Access</span><span class="bold">${plan.per}</span></div>
          <hr class="divider"><div class="row between"><span class="bold">Total</span><b class="t-h2 tnum">${ST.naira(plan.price)}</b></div>
        </div>
        <div id="flvBody"></div>
      </div></div>
      <div class="footer-cta"><button class="btn btn-primary btn-block" id="pay">Pay ${ST.naira(plan.price)}</button></div>`;
    },
    mount(el, p) {
      const plan = PLANS.find(x => x.id === (p.plan || 'q'));
      const body = el.querySelector('#flvBody');
      const draw = () => {
        body.innerHTML = S.payFlavor === 'play'
          ? `<div class="stack g3"><span class="t-label">Payment</span>
              <div class="card pay-method">${I('google-play-logo', 1).replace('class="', 'style="font-size:28px;color:var(--c-secondary)" class="')}<span class="grow"><b class="t-sm">Google Play</b><div class="t-cap muted">Card, Google Pay or other Play methods</div></span></div>
              <p class="t-cap muted">You will confirm the payment in Google Play. We check it with Google before Premium turns on.</p></div>`
          : `<div class="stack g3"><span class="t-label">Pay with Paystack</span>
              ${[['credit-card', 'Card', 'Visa, Mastercard, Verve'], ['bank', 'Bank transfer', 'Pay from any Nigerian bank'], ['hash', 'USSD', 'Dial a code on any phone']].map(([ic, t, d], k) => `
              <button class="plan ${k ? '' : 'on'}" data-plan="${ic}"><span class="radio"></span><span class="ic navy" style="width:40px;height:40px;border-radius:10px;display:grid;place-items:center;font-size:20px">${I(ic, 1)}</span><span class="grow"><b class="t-sm">${t}</b><br><span class="t-cap muted">${d}</span></span></button>`).join('')}
              <p class="t-cap muted">Paystack opens securely in the app. Premium turns on after we confirm the payment.</p></div>`;
        bindPlans(body);
      };
      el.querySelectorAll('#flv button').forEach(b => b.onclick = () => { S.payFlavor = b.dataset.f; el.querySelectorAll('#flv button').forEach(x => x.classList.toggle('on', x === b)); draw(); });
      draw();
      el.querySelector('#pay').onclick = () => {
        if (S.payFlavor === 'play') {
          ST.sheet(`<div class="stack g4"><div class="row g3">${I('google-play-logo', 1).replace('class="', 'style="font-size:26px;color:#01875F" class="')}<b>Google Play</b></div>
            <div class="row g3"><img src="/brand/favicon.svg" alt="" style="width:48px;height:48px;border-radius:12px"><div class="grow"><b class="t-sm">SolutionTee Premium · ${plan.name}</b><div class="t-cap muted">SolutionTee CBT</div></div><b class="tnum">${ST.naira(plan.price)}</b></div>
            <div class="card pay-method">${I('credit-card', 1)}<span class="grow t-sm bold">Visa ···· 4417</span>${I('caret-right')}</div>
            <button class="btn btn-block" style="background:#01875F;color:#fff" id="gpBuy">Buy</button>
            <p class="t-cap muted" style="text-align:center">Mock of the Google Play purchase sheet (rendered by Google in the real app).</p></div>`, {
            mount: w => w.querySelector('#gpBuy').onclick = () => { const b = w.querySelector('#gpBuy'); b.classList.add('is-loading'); b.textContent = 'Verifying'; setTimeout(() => ST.go('pay-success', { plan: plan.id }, { mode: 'fade' }), 1100); }
          });
        } else {
          const b = el.querySelector('#pay'); b.classList.add('is-loading'); b.textContent = 'Opening Paystack';
          setTimeout(() => { b.classList.remove('is-loading'); b.textContent = 'Checking payment'; b.classList.add('is-loading'); setTimeout(() => ST.go('pay-success', { plan: plan.id }, { mode: 'fade' }), 1000); }, 900);
        }
      };
    }
  });

  def('pay-success', {
    title: 'Payment success', group: 'Premium & payments',
    render: p => {
      const plan = PLANS.find(x => x.id === (p.plan || 'q'));
      return `<canvas id="confetti"></canvas>
      <div class="scr-body" style="display:flex;flex-direction:column"><div class="stack center g4 grow" style="padding:var(--s-8) var(--s-6);text-align:center">
        <div class="success-burst pop">${I('check-fat', 1)}</div>
        <h1 class="t-h1">You are now Premium!</h1>
        <p class="muted">Thank you, ${S.first}. Every year, every exam and 100 AI prompts a day are now open.</p>
        <div class="card card-pad stack g2" style="width:100%;text-align:left">
          <div class="row between t-sm"><span class="muted">Plan</span><b>${plan.name}</b></div>
          <div class="row between t-sm"><span class="muted">Active until</span><b>24 Jan 2027</b></div>
          <div class="row between t-sm"><span class="muted">Receipt</span><b>Sent to your email</b></div>
        </div>
        <div class="row g2">${examLogo('JAMB', 'sm')}${examLogo('WAEC', 'sm')}${examLogo('NECO', 'sm')}<span class="badge badge-success">${I('lock-simple-open', 1)} Unlocked</span></div>
      </div>
      <div class="footer-cta clean"><button class="btn btn-primary btn-block" data-go="home" data-mode="fade" id="startP">Start practising</button></div></div>`;
    },
    mount(el) { S.plan = 'premium'; S.aiLeft = 100; S.aiMax = 100; if (!ST.reduceMotion()) ST.confetti(el.querySelector('#confetti')); el.querySelector('#startP').addEventListener('click', () => { S.plan = 'free'; S.aiLeft = 2; S.aiMax = 3; }); }
  });

  // ---------- AI tutor ----------
  const REPLY = {
    integral: [
      'Good question. Let us solve it step by step.', '\n\n',
      '**Step 1.** Integrate each term. Use the power rule ', '$\\int x^n\\,dx = \\frac{x^{n+1}}{n+1}$', ':', '\n\n',
      '$$\\int (3x^2 + 1)\\,dx = x^3 + x$$', '\n\n',
      '**Step 2.** Put in the limits $2$ and $0$:', '\n\n',
      '$$\\big(2^3 + 2\\big) - \\big(0 + 0\\big) = 10$$', '\n\n',
      '**Exam trap:** many students forget that ', '$\\int 1\\,dx = x$', ' and get $8$. Always integrate every term.', '\n\n',
      '**Quick check:** what is ', '$\\int_0^1 2x\\,dx$', '? Reply with your answer.'],
    log: ['Let us break $4.5$ into numbers we know.', '\n\n', '$$4.5 = \\frac{9}{2} = \\frac{3^2}{2}$$', '\n\n', 'So $\\log 4.5 = 2\\log 3 - \\log 2 = 0.9542 - 0.3010 = 0.6532$.', '\n\n', '**Tip:** whenever JAMB gives you $\\log 2$ and $\\log 3$, try to write the number using only $2$s and $3$s.'],
    photo: ['I can read your photo. The question says a trader bought a phone for ', '₦24,000', ' and sold it for ', '₦30,000', '.', '\n\n',
      '**Step 1.** Find the profit: ', '$30{,}000 - 24{,}000 = 6{,}000$', '.', '\n\n',
      '**Step 2.** Percentage profit is always on the **cost price**:', '\n\n',
      '$$\\frac{6{,}000}{24{,}000} \\times 100\\% = 25\\%$$', '\n\n',
      'So the answer is **(B) 25%**.', '\n\n', '**Exam trap:** if you divide by the selling price you get $20\\%$, which is option A. JAMB puts that option there on purpose.'],
    default: ['Sure! A quadratic equation looks like ', '$ax^2+bx+c=0$', '. To solve ', '$x^2 - 5x + 6 = 0$', ', find two numbers that multiply to $6$ and add up to $-5$.', '\n\n', 'Those numbers are $-2$ and $-3$, so', '\n\n', '$$(x-2)(x-3) = 0 \\;\\Rightarrow\\; x = 2 \\text{ or } x = 3$$', '\n\n', '**Your turn:** solve $x^2 - 7x + 12 = 0$.']
  };
  const mdLite = s => s.replace(/\*\*(.+?)\*\*/g, '<b>$1</b>');

  function stream(bubble, chunks, done) {
    const target = bubble.querySelector('.txt');
    // split prose into words; keep math chunks atomic
    const tokens = [];
    chunks.forEach(c => { if (/^\$/.test(c) || c === '\n\n') tokens.push(c); else c.split(/(\s+)/).forEach(w => w && tokens.push(w)); });
    let i = 0, html = '';
    const render = () => {
      // render math inline as soon as each complete token arrives
      target.innerHTML = '<p>' + html.split('\n\n').map(mdLite).join('</p><p>') + '</p>' + (i < tokens.length ? '<span class="cursor"></span>' : '');
      ST.math(target);
      bubble.closest('.chat').scrollTop = 1e6;
    };
    const iv = setInterval(() => {
      if (!bubble.isConnected) return clearInterval(iv);
      const n = ST.reduceMotion() ? tokens.length : 2;
      for (let k = 0; k < n && i < tokens.length; k++) html += tokens[i++];
      render();
      if (i >= tokens.length) { clearInterval(iv); done && done(); }
    }, 55);
  }

  def('ai', {
    title: 'AI chat (streaming + LaTeX)', group: 'AI tutor', tab: 'ai',
    render: p => `
      <div class="appbar lined"><span class="title" style="padding-left:12px">SolutionTee AI<small>Your step-by-step tutor</small></span>
        <span class="quota ${S.aiLeft ? '' : 'out'}" id="quota">${I('sparkle', 1)} <span class="tnum">${S.aiLeft} of ${S.aiMax}</span> left today</span>
        <button class="icon-btn" aria-label="New chat" data-go="ai" data-mode="fade">${I('note-pencil')}</button></div>
      <div class="row g2 px4" style="padding-block:8px;border-bottom:1px solid var(--c-border)">
        <div class="chips grow">${['Mathematics', 'Physics', 'Chemistry', 'English', 'Biology'].map((c, i) => `<button class="chip ${i ? '' : 'on'}" data-subj>${c}</button>`).join('')}</div></div>
      <div class="chat" id="chat">
        ${p.q ? `<div class="ai-attached"><b>${I('paperclip', 1)} Attached question</b><br>${p.q === 'log' ? 'JAMB 2001 Maths Q7: evaluate $\\log_{10} 4.5$' : 'JAMB Mock Maths Q3: evaluate $\\int_0^2 (3x^2+1)\\,dx$. My answer: C ($12$).'}</div>` : `
        <div class="stack center g3" style="text-align:center;padding:var(--s-5) var(--s-3) var(--s-2)">
          <div class="state" style="padding:0"><div class="art gold" style="width:76px;height:76px;font-size:36px;border-radius:24px;margin:0">${I('sparkle', 1)}</div></div>
          <h2 class="t-h3">Hi ${S.first}, what are we solving today?</h2><p class="t-sm muted" style="max-width:30ch">I explain step by step, like a patient teacher. Turn on hint mode if you want clues, not answers.</p></div>
        <div class="suggest enter" id="sugg">
          <button id="snapSugg">${I('camera')}<span><b>Snap a question.</b> Take a photo of your textbook or past question and I will solve it.</span></button>
          ${['Explain how to solve $x^2 - 5x + 6 = 0$', 'What is the difference between speed and velocity?', 'Give me 3 tips for JAMB Use of English'].map(s => `<button data-s="${s.replace(/"/g, '&quot;')}">${I('arrow-up-right')}<span>${s}</span></button>`).join('')}
        </div>`}
      </div>
      <div class="row between px4 t-cap" style="padding-block:4px"><label class="row g2 bold" style="cursor:pointer;white-space:nowrap"><span class="switch" style="transform:scale(.75);transform-origin:left;margin-right:-12px"><input type="checkbox" id="hint"><span></span></span>Hint mode</label><span class="muted">AI can make mistakes.</span></div>
      <div class="attach-preview hidden" id="attPrev"></div>
      <div class="composer">
        <button class="icon-btn attach-btn" id="attach" aria-label="Add a photo">${I('camera-plus')}</button>
        <div class="input"><textarea rows="1" id="msg" placeholder="Ask any question..." aria-label="Message"></textarea></div>
        <button class="send" id="send" aria-label="Send">${I('paper-plane-right', 1)}</button>
      </div>`,
    mount(el, p) {
      const chat = el.querySelector('#chat'), msg = el.querySelector('#msg'), send = el.querySelector('#send'), quota = el.querySelector('#quota');
      el.querySelectorAll('[data-subj]').forEach(b => b.onclick = () => el.querySelectorAll('[data-subj]').forEach(x => x.classList.toggle('on', x === b)));
      // ---- Photo attachment (one image per message) ----
      let att = null;
      const prev = el.querySelector('#attPrev');
      const setAtt = a => {
        att = a;
        prev.classList.toggle('hidden', !a);
        prev.innerHTML = a ? `<button class="att-thumb" id="attView" aria-label="View photo"><img src="${a.url}" alt="Your photo"></button>
          <div class="grow"><b class="t-sm">Question photo</b><div class="t-cap muted">${a.kb} KB${a.origKb > a.kb ? ` · shrunk from ${a.origKb >= 1024 ? (a.origKb / 1024).toFixed(1) + ' MB' : a.origKb + ' KB'} to save data` : ''}</div></div>
          <button class="icon-btn" id="attX" aria-label="Remove photo">${I('x-circle', 1)}</button>` : '';
        if (a) {
          prev.querySelector('#attX').onclick = () => setAtt(null);
          prev.querySelector('#attView').onclick = () => ST.viewImage(a.url, 'Your question photo');
          msg.placeholder = 'Add a note (optional)'; msg.focus();
        } else msg.placeholder = 'Ask any question...';
      };
      const openAttach = () => ST.sheet(`
        <h2 class="t-h3">Add a photo</h2>
        <p class="t-sm muted mt2">Snap your question so the whole of it is clear, well lit and not blurry. One photo uses 1 AI prompt.</p>
        <div class="card list mt4">
          <button class="list-item" data-src="camera"><span class="lead">${I('camera', 1)}</span><span class="grow"><b class="t-sm">Take a photo</b><div class="t-cap muted">Opens your camera</div></span></button>
          <button class="list-item" data-src="gallery"><span class="lead">${I('images', 1)}</span><span class="grow"><b class="t-sm">Choose from gallery</b><div class="t-cap muted">Screenshots and saved photos</div></span></button>
          <button class="list-item" data-src="sample"><span class="lead" style="background:var(--c-warning-soft);color:var(--c-on-warning-soft)">${I('flask', 1)}</span><span class="grow"><b class="t-sm">Use a sample photo</b><div class="t-cap muted">Prototype only, for testing on a laptop</div></span></button>
        </div>
        <p class="t-cap subtle mt4">Photos are shrunk on your phone before upload and are only used to answer your question.</p>`, {
        mount: w => w.querySelectorAll('[data-src]').forEach(b => b.onclick = async () => {
          ST.closeOverlay();
          const a = b.dataset.src === 'sample' ? await ST.samplePhoto() : await ST.pickImage({ camera: b.dataset.src === 'camera' });
          if (a) setAtt(a);
        })
      });
      el.querySelector('#attach').onclick = openAttach;
      el.querySelector('#snapSugg')?.addEventListener('click', openAttach);

      const ask = (text, kind, image) => {
        if (S.aiLeft <= 0) return ST.go('ai-out', null, { mode: 'fade', replace: true });
        el.querySelector('#sugg')?.remove();
        chat.querySelector('.stack.center')?.remove();
        if (text || image) {
          const body = text ? `<div>${ST.esc(text).replace(/\$(.+?)\$/g, (m, t) => ST.tex(t))}</div>` : '';
          chat.insertAdjacentHTML('beforeend', `<div class="msg me ${image ? 'has-img' : ''}">${image ? `<button class="msg-img" aria-label="View photo"><img src="${image.url}" alt="Question photo"></button>` : ''}${body}</div>`);
          if (image) chat.lastElementChild.querySelector('.msg-img').onclick = () => ST.viewImage(image.url, 'Question photo');
        }
        S.aiLeft--; quota.innerHTML = `${I('sparkle', 1)} <span class="tnum">${S.aiLeft} of ${S.aiMax}</span> left today`; quota.classList.toggle('out', !S.aiLeft);
        quota.classList.remove('pop'); void quota.offsetWidth; quota.classList.add('pop');
        chat.insertAdjacentHTML('beforeend', `<div class="msg ai"><div class="txt"><span class="typing"><i></i><i></i><i></i></span></div></div>`);
        const bub = chat.lastElementChild; chat.scrollTop = 1e6;
        setTimeout(() => stream(bub, REPLY[kind] || REPLY.default, () => {
          bub.insertAdjacentHTML('beforeend', `<div class="msg-tools"><button class="icon-btn" aria-label="Copy" data-toast="Copied">${I('copy')}</button><button class="icon-btn" aria-label="Helpful" data-toast="Thanks for the feedback">${I('thumbs-up')}</button><button class="icon-btn" aria-label="Not helpful">${I('thumbs-down')}</button></div>`);
          if (!S.aiLeft) chat.insertAdjacentHTML('beforeend', `<div class="banner err">${I('hourglass-low', 1)}<span>That was your last free prompt today. <a href="#" data-go="ai-out" class="bold">See options</a></span></div>`);
          chat.scrollTop = 1e6;
        }), ST.reduceMotion() ? 50 : 700);
      };
      el.querySelectorAll('#sugg button').forEach(b => b.onclick = () => ask(b.dataset.s, 'default'));
      send.onclick = () => {
        const v = msg.value.trim();
        if (!v && !att) return msg.focus();
        const a = att; msg.value = ''; setAtt(null);
        ask(v, a ? 'photo' : /integr/i.test(v) ? 'integral' : 'default', a);
      };
      msg.addEventListener('keydown', e => { if (e.key === 'Enter' && !e.shiftKey) { e.preventDefault(); send.click(); } });
      if (p.q) setTimeout(() => ask(null, p.q === 'log' ? 'log' : 'integral'), 300);
    }
  });

  def('ai-out', {
    title: 'AI quota finished', group: 'AI tutor', tab: 'ai',
    render: () => `
      <div class="appbar lined"><span class="title" style="padding-left:12px">SolutionTee AI<small>Your step-by-step tutor</small></span><span class="quota out">${I('sparkle', 1)} 0 of 3 left today</span></div>
      <div class="scr-body"><div class="state">
        <div class="art gold">${I('hourglass-medium', 1)}</div>
        <h2 class="t-h2">You have used today's 3 free prompts</h2>
        <p class="muted">Your prompts reset at midnight, Lagos time. Come back in <b class="tnum" id="cd" style="color:var(--c-text)">7:35:12</b>.</p>
        <div class="card card-pad stack g3 mt4" style="width:100%;text-align:left">
          <div class="row g3"><span class="crown" style="width:40px;height:40px;border-radius:12px;background:var(--gold-400);color:var(--navy-900);display:grid;place-items:center;font-size:22px">${I('crown-simple', 1)}</span><div class="grow"><b>Premium gets 100 prompts a day</b><div class="t-cap muted">Plus every year, every exam and all videos.</div></div></div>
          <button class="btn btn-accent btn-block" data-sheet="paywall" data-reason="ai">See Premium plans</button></div>
        <button class="btn btn-ghost" data-go="study">Study past questions instead</button>
      </div></div>
      <div class="composer" style="opacity:.55"><div class="input"><textarea rows="1" disabled placeholder="Prompts reset at midnight"></textarea></div><button class="send" disabled>${I('paper-plane-right', 1)}</button></div>`,
    mount(el) {
      let s = 7 * 3600 + 35 * 60 + 12; const cd = el.querySelector('#cd');
      const iv = setInterval(() => { if (!el.isConnected) return clearInterval(iv); s--; cd.textContent = `${Math.floor(s / 3600)}:${String(Math.floor(s % 3600 / 60)).padStart(2, '0')}:${String(s % 60).padStart(2, '0')}`; }, 1000);
    }
  });

  // ---------- Profile ----------
  const chart = () => {
    const pts = [212, 228, 219, 245, 251, 249, 268, 287], W = 320, H = 130, pad = 22, min = 180, max = 320;
    const xy = pts.map((v, i) => [pad + i * (W - pad * 2) / (pts.length - 1), H - 18 - (v - min) / (max - min) * (H - 30)]);
    const line = xy.map(p => p.join(',')).join(' ');
    return `<svg viewBox="0 0 ${W} ${H}" role="img" aria-label="JAMB score trend from 212 to 287">
      ${[200, 250, 300].map(v => { const y = H - 18 - (v - min) / (max - min) * (H - 30); return `<line class="gridline" x1="${pad}" x2="${W - 6}" y1="${y}" y2="${y}"/><text class="axis" x="0" y="${y + 3}">${v}</text>`; }).join('')}
      <polygon class="area" points="${xy[0][0]},${H - 18} ${line} ${xy[xy.length - 1][0]},${H - 18}"/>
      <polyline class="line" points="${line}"/>
      ${xy.map((p, i) => `<circle class="dot ${i === xy.length - 1 ? 'last' : ''}" cx="${p[0]}" cy="${p[1]}" r="${i === xy.length - 1 ? 5 : 3.5}"/>`).join('')}
      ${['Aug', 'Sep', 'Oct'].map((m, i) => `<text class="axis" x="${pad + i * (W - pad * 2) / 2 - 8}" y="${H}">${m}</text>`).join('')}</svg>`;
  };

  def('profile', {
    title: 'Profile dashboard', group: 'Main tabs', tab: 'profile',
    render: () => `
      <div class="appbar"><span class="title" style="padding-left:12px;font-size:var(--t-h2-size)">Me</span><button class="icon-btn" aria-label="Settings" data-go="settings">${I('gear-six')}</button></div>
      <div class="scr-body">
        <div class="prof-head"><button class="avatar-edit" id="avEdit" aria-label="Change profile photo">${ST.avatar('lg')}<span class="cam">${I('camera', 1)}</span></button><div class="grow"><h1 class="t-h2">${S.name}</h1><p class="t-sm muted">Oyo · JAMB target 290</p>
          <span class="badge badge-neutral mt2">Free plan</span></div></div>
        <div class="px5 stack g5" style="padding-bottom:var(--s-8)">
          <div class="upgrade-banner"><div class="crown">${I('crown-simple', 1)}</div><div class="grow" style="position:relative;z-index:1"><b>Upgrade to Premium</b><p class="t-sm" style="color:#AFC0DD">From ${ST.naira(1500)} (sample price)</p></div><button class="btn btn-accent btn-sm" data-sheet="paywall" style="position:relative;z-index:1">Upgrade</button></div>
          <div class="grid2 enter">
            <div class="card stat"><b>24</b><span>Tests taken</span></div>
            <div class="card stat"><b>287</b><span>Best JAMB score</span></div>
            <div class="card stat"><b>${S.streak} days</b><span>Current streak</span></div>
            <div class="card stat"><b>18h 40m</b><span>Time practising</span></div>
          </div>
          <section class="card card-pad chart"><div class="row between" style="margin-bottom:8px"><h2 class="t-h3">Score trend</h2><span class="badge badge-success">${I('trend-up', 1)} +75</span></div>${chart()}</section>
          <section class="card card-pad stack g3"><h2 class="t-h3">Average by subject</h2>
            ${[['English', 74], ['Mathematics', 61], ['Physics', 68], ['Chemistry', 72]].map(([s, v]) => `<div class="subj-score"><span class="t-sm bold">${s}</span><span class="t-sm muted tnum">${v}%</span><div class="bar ${v >= 70 ? 'ok' : ''}"><i data-v="${v}%"></i></div></div>`).join('')}</section>
          <section><div class="sect-title"><h2 class="t-h3">Badges</h2><span class="t-cap muted">4 of 12</span></div>
            <div class="grid3" style="grid-template-columns:repeat(4,1fr)">
              ${[['fire', 'gold', '7-day streak'], ['target', 'blue', 'First 250+'], ['lightning', 'navy', 'Speedster'], ['star', 'gold', '100 correct'], ['trophy', '', 'Score 300'], ['moon-stars', '', 'Night owl'], ['books', '', 'Bookworm'], ['medal', '', 'Full mock']].map(([ic, c, t], k) => `<div class="badge-tile ${c ? '' : 'off'}"><span class="medal ic ${c}">${I(ic, 1)}</span>${t}</div>`).join('')}</div></section>
          <section class="card list">
            ${[['clock-counter-clockwise', 'Test history', 'test'], ['bookmark-simple', 'Bookmarks', 'empty'], ['download-simple', 'Downloads', 'offline'], ['sparkle', `AI prompts left today: ${S.aiLeft}`, 'ai'], ['video-camera', 'My classes', 'empty'], ['gear-six', 'Settings', 'settings'], ['question', 'Help & support', 'help']].map(([ic, t, go]) => `
              <button class="list-item" data-go="${go}"><span class="lead">${I(ic, 1)}</span><span class="grow t-sm bold">${t}</span>${I('caret-right').replace('class="', 'class="trail ')}</button>`).join('')}
          </section>
          <button class="btn btn-outline btn-block" data-go="welcome" data-mode="fade">${I('sign-out')} Log out</button>
        </div></div>`,
    mount(el) {
      ST.animateBars(el);
      const btn = el.querySelector('#avEdit');
      const refresh = () => { btn.querySelector('.avatar').outerHTML = ST.avatar('lg'); };
      const confirmPhoto = a => ST.sheet(`
        <h2 class="t-h3">Use this photo?</h2>
        <div class="stack center g3 mt4"><div class="avatar xl"><img src="${a.url}" alt="New profile photo preview"></div>
          <p class="t-cap muted">Shown in a circle on your profile, results and class chats. ${a.kb} KB</p></div>
        <div class="grid2 mt4"><button class="btn btn-outline" id="again">Choose another</button><button class="btn btn-primary" id="use">Use photo</button></div>`, {
        mount: w => {
          w.querySelector('#use').onclick = () => { S.avatar = a.url; ST.closeOverlay(); refresh(); ST.toast('Profile photo updated', 'user-circle'); };
          w.querySelector('#again').onclick = () => { ST.closeOverlay(true); openPicker(); };
        }
      });
      const openPicker = () => ST.sheet(`
        <h2 class="t-h3">Profile photo</h2>
        <div class="card list mt4">
          <button class="list-item" data-src="camera"><span class="lead">${I('camera', 1)}</span><span class="grow t-sm bold">Take a photo</span></button>
          <button class="list-item" data-src="gallery"><span class="lead">${I('images', 1)}</span><span class="grow t-sm bold">Choose from gallery</span></button>
          ${S.avatar ? `<button class="list-item" data-src="remove"><span class="lead" style="background:var(--c-error-soft);color:var(--c-on-error-soft)">${I('trash', 1)}</span><span class="grow t-sm bold" style="color:var(--c-error)">Remove photo</span></button>` : ''}
        </div>
        <p class="t-cap subtle mt4">Use a clear photo of your face. No photos of other people, please.</p>`, {
        mount: w => w.querySelectorAll('[data-src]').forEach(b => b.onclick = async () => {
          ST.closeOverlay(true);
          if (b.dataset.src === 'remove') { S.avatar = null; refresh(); ST.toast('Profile photo removed', 'trash'); return; }
          const a = await ST.pickImage({ camera: b.dataset.src === 'camera' });
          if (a) confirmPhoto(a);
        })
      });
      btn.onclick = openPicker;
    }
  });

  def('settings', {
    title: 'Settings', group: 'Profile',
    render: () => `
      <div class="appbar"><button class="icon-btn" data-back="profile" aria-label="Back">${I('arrow-left')}</button><span class="title">Settings</span></div>
      <div class="scr-body"><div class="pad stack g5" style="padding-top:var(--s-2)">
        <section class="stack g2"><span class="t-label">Theme</span><div class="seg" id="theme">${['system', 'light', 'dark'].map(t => `<button data-t="${t}" class="${ST.getTheme() === t ? 'on' : ''}">${t[0].toUpperCase() + t.slice(1)}</button>`).join('')}</div></section>
        <section class="card list">
          ${[['person-simple-walk', 'Reduce motion', 'Fewer animations. Also follows your phone setting.', 'rm', ST.reduceMotion()],
             ['cell-signal-low', 'Data saver', 'Low-quality videos and no auto-download.', 'ds', true]].map(([ic, t, d, id, on]) => `
            <label class="list-item" style="cursor:pointer"><span class="lead">${I(ic, 1)}</span><span class="grow"><b class="t-sm">${t}</b><div class="t-cap muted">${d}</div></span><span class="switch"><input type="checkbox" id="${id}" ${on ? 'checked' : ''}><span></span></span></label>`).join('')}
        </section>
        <section class="stack g2"><span class="t-label">Notifications</span><div class="card list">
          ${['Announcements', 'New questions added', 'Streak reminders', 'Class reminders'].map((t, k) => `<label class="list-item" style="cursor:pointer"><span class="grow t-sm bold">${t}</span><span class="switch"><input type="checkbox" ${k !== 2 ? 'checked' : ''}><span></span></span></label>`).join('')}
        </div></section>
        <section class="card list">
          <button class="list-item" data-go="setup" data-params="step=3"><span class="lead">${I('books', 1)}</span><span class="grow t-sm bold">Change JAMB subjects</span>${I('caret-right').replace('class="', 'class="trail ')}</button>
          <button class="list-item" data-go="delete"><span class="lead" style="background:var(--c-error-soft);color:var(--c-on-error-soft)">${I('trash', 1)}</span><span class="grow t-sm bold" style="color:var(--c-error)">Delete account</span>${I('caret-right').replace('class="', 'class="trail ')}</button>
        </section>
        <p class="t-cap subtle" style="text-align:center">SolutionTee CBT · version 1.0.0 (prototype)</p>
      </div></div>`,
    mount(el) {
      el.querySelectorAll('#theme button').forEach(b => b.onclick = () => { ST.setTheme(b.dataset.t); el.querySelectorAll('#theme button').forEach(x => x.classList.toggle('on', x === b)); ST.syncPanel?.(); });
      el.querySelector('#rm').onchange = e => { ST.setReduceMotion(e.target.checked); ST.syncPanel?.(); };
    }
  });

  def('help', {
    title: 'Help & support', group: 'Profile',
    render: () => `
      <div class="appbar"><button class="icon-btn" data-back="profile" aria-label="Back">${I('arrow-left')}</button><span class="title">Help & support</span></div>
      <div class="scr-body"><div class="pad stack g5" style="padding-top:var(--s-2)">
        <button class="card card-tap row g3" style="padding:var(--s-4)" data-go="tour" data-mode="fade"><span class="ic gold" style="width:44px;height:44px;border-radius:12px;display:grid;place-items:center;font-size:22px">${I('map-trifold', 1)}</span><span class="grow"><b>Replay the app tour</b><br><span class="t-cap muted">See where everything is again</span></span>${I('caret-right')}</button>
        <div class="grid2">
          <button class="card card-tap study-tile" style="min-height:104px" data-toast="Opens WhatsApp (number to be provided)"><span class="ic green">${I('whatsapp-logo', 1)}</span><b class="t-sm">WhatsApp us</b></button>
          <button class="card card-tap study-tile" style="min-height:104px" data-toast="Opens your email app"><span class="ic blue">${I('envelope-simple', 1)}</span><b class="t-sm">Email support</b></button>
        </div>
        <section class="stack g2"><span class="t-label">Questions people ask</span>
          ${[['Can I use the app without data?', 'Yes. Download a question pack in Test or Study. You can take those exams offline, and your results sync when you are back online.'],
             ['How is my JAMB score calculated?', 'Each subject is marked out of 100 and the four subjects are added to give a score out of 400, like the real UTME.'],
             ['When do my AI prompts reset?', 'Every day at midnight, Lagos time.'],
             ['I paid but Premium is not active', 'Pull down to refresh your profile. If it still does not show after 10 minutes, contact us on WhatsApp with your payment reference.']].map(([q, a]) => `
            <details class="card acc"><summary>${q}${I('caret-down')}</summary><p>${a}</p></details>`).join('')}
        </section>
        <section class="card list">
          <button class="list-item"><span class="lead">${I('file-text', 1)}</span><span class="grow t-sm bold">Terms of Service</span>${I('caret-right').replace('class="', 'class="trail ')}</button>
          <button class="list-item"><span class="lead">${I('shield-check', 1)}</span><span class="grow t-sm bold">Privacy Policy</span>${I('caret-right').replace('class="', 'class="trail ')}</button>
          <button class="list-item"><span class="lead">${I('info', 1)}</span><span class="grow t-sm bold">About SolutionTee CBT</span>${I('caret-right').replace('class="', 'class="trail ')}</button>
        </section>
        <p class="disclaimer">${ST.DISCLAIMER}</p>
      </div></div>`
  });

  def('delete', {
    title: 'Delete account', group: 'Profile',
    render: () => `
      <div class="appbar"><button class="icon-btn" data-back="settings" aria-label="Back">${I('arrow-left')}</button><span class="title">Delete account</span></div>
      <div class="scr-body"><div class="pad stack g4" style="padding-top:var(--s-2)">
        <div class="ic red" style="width:56px;height:56px;border-radius:16px;display:grid;place-items:center;font-size:28px">${I('warning', 1)}</div>
        <h1 class="t-h1">We are sad to see you go</h1>
        <p class="muted">Deleting your account is permanent. This will remove:</p>
        <div class="stack g3">${['Your profile and login', 'Your test history, scores and bookmarks', 'Your AI chat history', 'Any Premium time you have left (no refund)'].map(t => `<div class="benefit">${I('x-circle', 1).replace('class="', 'style="color:var(--c-error);font-size:20px" class="')}<span>${t}</span></div>`).join('')}</div>
        <div class="banner info">${I('info', 1)}<span>Payment records are kept for 6 years because the law requires it. They are not linked to your profile.</span></div>
        <div class="field"><label for="delc">Type <b>DELETE</b> to confirm</label><div class="input"><input id="delc" autocomplete="off" placeholder="DELETE"></div></div>
      </div></div>
      <div class="footer-cta stack g2"><button class="btn btn-danger btn-block is-disabled" id="del">Delete my account</button><button class="btn btn-ghost" data-back="settings">Cancel</button></div>`,
    mount(el) {
      const inp = el.querySelector('#delc'), b = el.querySelector('#del');
      inp.oninput = () => b.classList.toggle('is-disabled', inp.value.trim() !== 'DELETE');
      b.onclick = () => ST.dialog(`<div class="stack g3"><h2 class="t-h3">Delete account now?</h2><p class="t-sm muted">This cannot be undone.</p><div class="grid2"><button class="btn btn-outline" data-close>Cancel</button><button class="btn btn-danger" id="y">Delete</button></div></div>`,
        { mount: w => w.querySelector('#y').onclick = () => { ST.closeOverlay(true); ST.go('welcome', null, { mode: 'fade' }); setTimeout(() => ST.toast('Your account has been deleted.', 'trash'), 400); } });
    }
  });

  // ---------- System states ----------
  const G = 'States';
  def('locked', {
    title: 'Locked content', group: G,
    render: () => `
      <div class="appbar"><button class="icon-btn" data-back="study" aria-label="Back">${I('arrow-left')}</button><span class="title">JAMB 2015 Mathematics</span></div>
      <div class="scr-body"><div class="state">
        <div class="art gold">${I('lock-simple', 1)}</div>
        <h2 class="t-h2">This year is for Premium</h2>
        <p class="muted">Free accounts can practise JAMB 2000, 2001 and 2002. Go Premium to open every year from 2000 to 2025.</p>
        <button class="btn btn-accent btn-block mt4" data-sheet="paywall" data-reason="2015">${I('crown-simple', 1)} Unlock all years</button>
        <button class="btn btn-ghost" data-go="pq">Practise a free year</button>
        <p class="t-cap subtle mt4">Locked questions never download to your phone until you unlock them.</p>
      </div></div>`
  });
  def('empty', {
    title: 'Empty state (bookmarks)', group: G,
    render: () => `
      <div class="appbar"><button class="icon-btn" data-back="study" aria-label="Back">${I('arrow-left')}</button><span class="title">Bookmarks</span></div>
      <div class="scr-body"><div class="state">
        <div class="art blue">${I('bookmark-simple', 1)}</div>
        <h2 class="t-h2">No bookmarks yet</h2>
        <p class="muted">Tap the bookmark icon on any question, video or note to save it here for later.</p>
        <button class="btn btn-primary mt4" data-go="pq">Browse past questions</button>
      </div></div>`
  });
  def('offline', {
    title: 'Offline state', group: G,
    render: () => `
      <div class="appbar"><button class="icon-btn" data-back="home" aria-label="Back">${I('arrow-left')}</button><span class="title">Downloads</span></div>
      <div class="px5" style="padding-bottom:12px"><div class="banner warn">${I('wifi-slash', 1)}<span><b>You are offline.</b> You can still take downloaded exams. Results will sync later.</span></div></div>
      <div class="scr-body"><div class="pad stack g4" style="padding-top:0">
        <div class="row between"><span class="t-label">On this phone</span><span class="t-cap muted">24.6 MB used</span></div>
        <div class="card list">
          ${[['JAMB 2000 to 2002 · all subjects', '6.4 MB', 'ok'], ['Lesson notes: Mathematics', '1.1 MB', 'ok'], ['JAMB 2002 Chemistry Q14 video', '17.1 MB', 'ok']].map(([t, s]) => `
          <div class="list-item"><span class="lead" style="background:var(--c-success-soft);color:var(--c-on-success-soft)">${I('cloud-check', 1)}</span><span class="grow"><b class="t-sm">${t}</b><div class="t-cap muted">${s}</div></span><button class="icon-btn" aria-label="Remove download">${I('trash')}</button></div>`).join('')}
        </div>
        <div class="card card-pad row g3"><span class="ic gold" style="width:40px;height:40px;border-radius:10px;display:grid;place-items:center;font-size:20px">${I('arrows-clockwise', 1)}</span><div class="grow"><b class="t-sm">2 results waiting to sync</b><div class="t-cap muted">They will upload when you reconnect.</div></div></div>
        <button class="btn btn-primary btn-block" data-go="cbt" data-params="resume=1">Take an offline exam</button>
      </div></div>`
  });
  def('error', {
    title: 'Error state', group: G,
    render: () => `
      <div class="appbar"><button class="icon-btn" data-back="home" aria-label="Back">${I('arrow-left')}</button><span class="title">Video lessons</span></div>
      <div class="scr-body"><div class="state">
        <div class="art red">${I('cloud-warning', 1)}</div>
        <h2 class="t-h2">We could not load this</h2>
        <p class="muted">Something went wrong on our side or your network is slow. Your progress is safe.</p>
        <button class="btn btn-primary mt4" id="retry">${I('arrow-clockwise')} Try again</button>
        <button class="btn btn-ghost" data-go="help">Contact support</button>
        <p class="t-cap subtle">Error code: VID-503</p>
      </div></div>`,
    mount(el) { const b = el.querySelector('#retry'); b.onclick = () => { b.classList.add('is-loading'); b.innerHTML = 'Trying'; setTimeout(() => ST.go('loading', null, { mode: 'fade', replace: true }), 900); }; }
  });
  def('loading', {
    title: 'Loading skeleton', group: G, tab: 'home',
    render: () => `
      <div class="scr-body" aria-busy="true" aria-label="Loading">
        <div class="home-head"><div class="sk" style="width:44px;height:44px;border-radius:50%"></div><div class="grow stack g2"><div class="sk" style="width:40%;height:10px"></div><div class="sk" style="width:60%;height:16px"></div></div><div class="sk" style="width:56px;height:36px;border-radius:99px"></div></div>
        <div class="px5 stack g5">
          <div class="sk" style="height:96px;border-radius:16px"></div>
          <div class="sk" style="width:50%;height:16px"></div>
          ${'<div class="sk" style="height:76px;border-radius:16px"></div>'.repeat(3)}
          <div class="sk" style="height:132px;border-radius:16px"></div>
        </div></div>`,
    mount(el) { setTimeout(() => { if (ST.current() === el) ST.go('home', null, { mode: 'fade', replace: true }); }, 2200); }
  });
})();
