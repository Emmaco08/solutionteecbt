/* First launch, onboarding, authentication, profile setup, guided tour. */
(function () {
  const { def, icon: I, examLogo, mark } = ST;
  const G = 'First launch & sign-in';
  const DISCLAIMER = 'SolutionTee CBT is an independent exam-practice platform and is not affiliated with or endorsed by JAMB, WAEC or NECO.';
  ST.DISCLAIMER = DISCLAIMER;

  // ---------- Splash ----------
  def('splash', {
    title: 'Splash', group: G, navy: true,
    render: () => `
      <div class="splash">
        <div class="lot" id="lot" role="img" aria-label="SolutionTee logo"></div>
        <div class="name">SolutionTee CBT</div>
        <div class="tag"><span>Learn.</span><span>Think.</span><span>Solve.</span></div>
      </div>`,
    mount(el) {
      const box = el.querySelector('#lot');
      const done = () => { if (ST.current() === el) ST.go('welcome', null, { mode: 'fade', replace: true }); };
      if (window.lottie && !ST.reduceMotion()) {
        const anim = lottie.loadAnimation({ container: box, renderer: 'svg', loop: false, autoplay: false, path: '/brand/solutiontee-loader-dark.json' });
        anim.addEventListener('DOMLoaded', () => { anim.playSegments([0, 52], true); });
        anim.addEventListener('complete', () => { anim.loop = true; anim.playSegments([52, 149], true); });
      } else {
        box.innerHTML = `<img src="/brand/mark-dark.png" alt="" style="width:120px;margin:24px auto">`;
      }
      setTimeout(done, ST.reduceMotion() ? 1200 : 3400);
      el.addEventListener('click', done);
    }
  });

  // ---------- Welcome ----------
  def('welcome', {
    title: 'Welcome', group: G,
    render: () => `
      <div class="scr-body" style="display:flex;flex-direction:column">
        <div style="flex:1;display:grid;place-items:center;position:relative;overflow:hidden">
          <div class="art-disc fx-breathe" style="width:300px;height:300px"></div>
          <div class="art-disc gold" style="width:180px;height:180px;transform:translate(90px,-90px)"></div>
          <div class="stack center g3 pop fx-float" style="position:relative;--rot:0deg;--d:0s">
            <img src="/brand/favicon.svg" alt="SolutionTee app icon" style="width:108px;height:108px;border-radius:26px;box-shadow:var(--shadow-3)">
          </div>
        </div>
        <div class="px5 stack g4 enter" style="padding-bottom:var(--s-6)">
          <h1 class="t-display">Welcome to<br>SolutionTee CBT</h1>
          <p class="t-lg muted">Practise real JAMB, WAEC and NECO CBT questions. Learn from clear solutions. Walk into your exam ready.</p>
          <div class="row g2">${examLogo('JAMB', 'sm')}${examLogo('WAEC', 'sm')}${examLogo('NECO', 'sm')}<span class="t-sm muted" style="margin-left:4px">All three exams, one app</span></div>
          <button class="btn btn-primary btn-block mt2" data-go="onboard">Get started ${I('arrow-right')}</button>
          <button class="btn btn-ghost" data-go="login">I already have an account</button>
          <p class="disclaimer">${DISCLAIMER}</p>
        </div>
      </div>`
  });

  // ---------- Onboarding slides ----------
  // Each picture: outer .layer = position + slide-in parallax; inner .fx-* = looping "ambient" animation
  // (runs only on the visible slide, off under reduce motion; see app.css "Onboarding art motion").
  const slides = [
    { t: 'A real CBT experience', d: 'Timed exams that look and feel like JAMB, WAEC and NECO CBT. Practise until the real day feels familiar.',
      art: () => `<div class="art-disc fx-breathe"></div>
        <div class="layer l1" style="position:absolute;left:40px;top:70px"><div class="mini fx-float" style="position:static;--rot:-8deg;--d:0s">${examLogo('WAEC', 'lg')}</div></div>
        <div class="layer l2" style="position:absolute;z-index:2"><div class="mini fx-float" style="position:static;--rot:0deg;--d:-1.3s">${examLogo('JAMB', 'lg')}</div></div>
        <div class="layer l3" style="position:absolute;right:40px;top:70px"><div class="mini fx-float" style="position:static;--rot:8deg;--d:-2.6s">${examLogo('NECO', 'lg')}</div></div>
        <div class="layer l2" style="position:absolute;bottom:56px;left:70px"><div class="mini" style="position:static;padding:8px 12px"><span class="timer" style="height:30px;font-size:14px"><span class="fx-tick">${I('timer', 1)}</span> <span class="tnum" data-countdown>01:58:34</span></span></div></div>` },
    { t: 'Win cash prizes every week', d: 'Answer our weekly challenge fast and right to win money. Free and Premium students can join, and play is fair for everyone.',
      art: () => `<div class="art-disc gold fx-breathe"></div>
        <div class="layer l1" style="position:absolute;top:58px"><div class="mini fx-float" style="position:static;--rot:-3deg;--d:0s;width:230px;text-align:center;padding:14px 12px">
          <span class="ob-trophy">${I('trophy', 1)}</span><div class="t-cap muted bold mt2">Weekly Challenge</div><b class="ob-prize fx-pulse">Win ${ST.naira(20000)}</b></div></div>
        <div class="layer l2" style="position:absolute;bottom:58px;left:28px"><div class="mini" style="position:static;width:200px;padding:10px 12px">
          ${[['1', 'Chiamaka O.', '10/10'], ['2', 'You', '10/10'], ['3', 'Abdullahi M.', '9/10']].map(([r, n, s], k) => `<div class="row g2 t-cap ob-row" style="--k:${k};padding:3px 0"><b style="width:14px">${r}</b><span class="grow ${n === 'You' ? 'bold' : ''}">${n}</span><b class="tnum">${s}</b></div>`).join('')}</div></div>
        <div class="layer l3" style="position:absolute;right:24px;bottom:150px">${ST.livePill ? ST.livePill('1,284 playing') : ''}</div>` },
    { t: 'Past questions, videos and notes', d: 'Every answer comes with a clear explanation. Watch video solutions and read simple lesson notes.',
      art: () => `<div class="art-disc blue fx-breathe"></div>
        <div class="layer l1" style="position:absolute;top:60px"><div class="mini" style="position:static;width:220px;padding:8px"><div class="thumb th-1"><span class="play fx-ripple">${I('play', 1)}</span><span class="dur">6:12</span></div></div></div>
        <div class="layer l2" style="position:absolute;bottom:60px;left:30px"><div class="mini" style="position:static;width:200px"><b class="t-sm">Quadratic equations</b><div class="t-cap muted">Lesson note · 8 min read</div><div class="bar mt2"><i class="fx-fill" style="width:64%"></i></div></div></div>
        <div class="layer l3" style="position:absolute;right:28px;bottom:120px"><div class="mini fx-check" style="position:static;padding:10px">${I('check-circle', 1).replace('class="', 'style="font-size:28px;color:var(--c-success)" class="')}</div></div>` },
    { t: 'SolutionTee AI tutor', d: 'Stuck on a question? Ask our AI tutor. It explains step by step, like a patient teacher.',
      art: () => `<div class="art-disc gold fx-breathe"></div>
        <div class="layer l1" style="position:absolute;top:66px;right:36px"><div class="msg me fx-seq-me" style="white-space:nowrap;max-width:none">Solve $x^2-5x+6=0$</div></div>
        <div class="layer l2" style="position:absolute;top:126px;left:30px"><div class="msg ai fx-seq-typing" style="padding:10px 14px"><span class="typing"><i></i><i></i><i></i></span></div></div>
        <div class="layer l2" style="position:absolute;top:126px;left:30px;width:250px"><div class="msg ai fx-seq-ai" style="max-width:none"><p>Find two numbers that multiply to $6$ and add to $-5$: that is $-2$ and $-3$.</p><p>So $x=2$ or $x=3$.</p></div></div>
        <div class="layer l3" style="position:absolute;bottom:56px;right:50px"><span class="quota fx-seq-chip">${I('sparkle', 1)} Step by step</span></div>` },
    { t: 'See your progress', d: 'Track your scores, find your weak topics and practise them until they become strong.',
      art: () => `<div class="art-disc fx-breathe"></div>
        <div class="layer l1" style="position:absolute;top:70px"><div class="mini" style="position:static;width:240px"><div class="row between"><b class="t-sm">JAMB score trend</b><span class="badge badge-success fx-badge">+38</span></div>
          <svg viewBox="0 0 200 64" style="width:100%;margin-top:8px;overflow:visible"><polyline class="fx-draw" pathLength="1" points="0,52 40,46 80,48 120,32 160,26 200,12" fill="none" stroke="var(--c-secondary)" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"/><circle class="fx-dot" cx="200" cy="12" r="5" fill="var(--c-accent)"/></svg></div></div>
        <div class="layer l2" style="position:absolute;bottom:60px;left:36px"><div class="mini row g3" style="position:static">
          <div class="ring" style="--size:56px;--stroke:3.6"><svg viewBox="0 0 36 36"><circle class="track" cx="18" cy="18" r="15"/><circle class="val fx-ring" cx="18" cy="18" r="15" pathLength="1" stroke-dasharray="1" stroke-dashoffset="0.3"/></svg><span class="ring-label t-cap bold">70%</span></div>
          <div><b class="t-sm">Weak topic</b><div class="t-cap muted">Organic chemistry</div></div></div></div>` },
    { t: 'Join live JAMB classes', d: 'Learn with real teachers online. Join classes, ask questions and get study materials.',
      art: () => `<div class="art-disc blue fx-breathe"></div>
        <div class="layer l1" style="position:absolute;top:80px"><div class="mini" style="position:static;width:250px"><div class="row g3"><div class="ic blue" style="width:44px;height:44px;border-radius:12px;display:grid;place-items:center;font-size:22px">${I('video-camera', 1)}</div>
          <div class="grow"><b class="t-sm">Physics: Waves</b><div class="t-cap muted">Today · 4:00 PM</div></div>${ST.livePill ? ST.livePill() : ''}</div>
          <button class="btn btn-accent btn-sm btn-block mt3 fx-pulse" tabindex="-1">Join class</button></div></div>
        <div class="layer l2" style="position:absolute;bottom:70px;left:46px"><div class="mini t-cap bold fx-float" style="position:static;--rot:0deg;--d:-1s">${I('users-three', 1)} <span class="tnum" data-students>214</span> students</div></div>` }
  ];
  ST.onboardSlides = slides;

  def('onboard', {
    title: 'Onboarding slides (6)', group: G,
    render: p => `
      <div class="appbar"><span class="grow"></span><button class="btn btn-ghost" data-go="signup">Skip</button></div>
      <div class="ob-slides"><div class="ob-track">${slides.map((s, i) => `
        <div class="ob-slide" data-i="${i}">
          <div class="ob-art">${s.art()}</div>
          <div class="ob-copy"><h2 class="t-h1">${s.t}</h2><p class="t-lg muted mt2">${s.d}</p></div>
        </div>`).join('')}</div></div>
      <div class="footer-cta clean row between">
        <div class="ob-dots">${slides.map(() => '<i></i>').join('')}</div>
        <button class="btn btn-primary" id="obNext" style="min-width:140px">Next ${I('arrow-right')}</button>
      </div>`,
    mount(el, p) {
      let i = +(p.i || 0);
      const track = el.querySelector('.ob-track'), dots = el.querySelectorAll('.ob-dots i'), next = el.querySelector('#obNext'), sl = el.querySelectorAll('.ob-slide');
      const set = n => {
        i = Math.max(0, Math.min(slides.length - 1, n));
        track.style.transform = `translateX(${-i * 100}%)`;
        dots.forEach((d, k) => d.classList.toggle('on', k === i));
        sl.forEach((s, k) => s.classList.toggle('cur', k === i));
        next.innerHTML = i === slides.length - 1 ? 'Create account' : `Next ${I('arrow-right')}`;
        ST.math(el);
      };
      next.onclick = () => i === slides.length - 1 ? ST.go('signup') : set(i + 1);
      // Ambient counters (timer on slide 1, student count on slide 5); paused under reduce motion
      let left = 1 * 3600 + 58 * 60 + 34, students = 214;
      const tick = setInterval(() => {
        if (!el.isConnected) return clearInterval(tick);
        if (ST.reduceMotion()) return;
        left--; const t = el.querySelector('[data-countdown]');
        if (t) t.textContent = [Math.floor(left / 3600), Math.floor(left % 3600 / 60), left % 60].map(n => String(n).padStart(2, '0')).join(':');
        if (Math.random() < 0.35) { const s = el.querySelector('[data-students]'); if (s) s.textContent = ++students; }
      }, 1000);
      let x0 = null;
      track.addEventListener('pointerdown', e => { x0 = e.clientX; });
      track.addEventListener('pointerup', e => { if (x0 == null) return; const dx = e.clientX - x0; if (Math.abs(dx) > 40) set(i + (dx < 0 ? 1 : -1)); x0 = null; });
      set(i);
    }
  });

  // ---------- Auth helpers ----------
  const field = (label, type, ph, opts = {}) => `
    <div class="field ${opts.err ? 'has-error' : ''}">
      <label>${label}</label>
      <div class="input">${opts.ic ? `<i class="ph ph-${opts.ic} lead-ic"></i>` : ''}<input type="${type}" placeholder="${ph}" value="${opts.val || ''}" ${opts.attrs || ''}>
        ${type === 'password' ? `<button class="icon-btn" data-pw aria-label="Show password">${I('eye')}</button>` : ''}</div>
      ${opts.err ? `<span class="err">${I('warning-circle', 1)} ${opts.err}</span>` : opts.help ? `<span class="help">${opts.help}</span>` : ''}
    </div>`;
  const pwToggle = el => el.querySelectorAll('[data-pw]').forEach(b => b.onclick = () => {
    const inp = b.parentNode.querySelector('input'); const show = inp.type === 'password';
    inp.type = show ? 'text' : 'password'; b.innerHTML = I(show ? 'eye-slash' : 'eye'); b.setAttribute('aria-label', show ? 'Hide password' : 'Show password');
  });
  // gated = sign-up screen: Google sign-up also needs the Terms/Privacy box ticked first
  const googleBtn = (label, gated) => `<button class="btn btn-block google-btn" ${gated ? 'id="gSignup"' : 'data-toast="Google sign-in opens the native Google account picker"'}><img src="vendor/google/google-g.svg" alt="" width="20" height="20"> ${label}</button>`;

  def('signup', {
    title: 'Sign up', group: G,
    render: () => `
      <div class="appbar"><button class="icon-btn" data-back="welcome" aria-label="Back">${I('arrow-left')}</button></div>
      <div class="scr-body"><div class="auth-head stack g2"><h1 class="t-h1">Create your account</h1><p class="muted">It takes one minute. We will send a code to your email.</p></div>
        <form class="px5 stack g4 enter" onsubmit="return false" novalidate>
          ${field('Email address', 'email', 'you@example.com', { ic: 'envelope-simple', attrs: 'id="em" autocomplete="email"' })}
          ${field('Password', 'password', 'At least 8 characters', { ic: 'lock-simple', help: 'Use 8+ characters with a number.', attrs: 'id="pw" autocomplete="new-password"' })}
          <details class="ref-field" ${ST.refFromLink ? 'open' : ''}><summary class="t-sm bold">${I('gift')} Have a referral code? <span class="muted" style="font-weight:500">(optional)</span></summary>
            <div class="field mt3" id="refF"><div class="input"><i class="ph ph-ticket lead-ic"></i><input id="refIn" class="code-input" placeholder="e.g. TOLU-7K3P" maxlength="12" autocomplete="off" value="${ST.refFromLink || ''}"></div>
            <span class="help">Your friend gets rewarded when you finish your first practice test.</span></div></details>
          <div class="consent" id="consent">
            <label class="check"><input type="checkbox" id="agree" aria-describedby="agreeErr" required> <span>I agree to the <a href="#" data-go="help">Terms</a> and <a href="#" data-go="help">Privacy Policy</a>. If I am under 18, my parent or guardian agrees too.</span></label>
            <span class="err hidden" id="agreeErr" role="alert">${I('warning-circle', 1)} Please tick the box to agree to the Terms and Privacy Policy.</span>
          </div>
          <button class="btn btn-primary btn-block" id="go">Create account</button>
          <div class="or">OR</div>
          ${googleBtn('Continue with Google', true)}
          <p class="t-sm muted" style="text-align:center;padding-bottom:24px">Already have an account? <a href="#" data-go="login" class="bold link-btn">Log in</a></p>
        </form></div>`,
    mount(el) {
      pwToggle(el);
      const agree = el.querySelector('#agree'), consent = el.querySelector('#consent'), agreeErr = el.querySelector('#agreeErr');
      const shake = () => { const f = el.querySelector('form'); f.classList.add('shake'); setTimeout(() => f.classList.remove('shake'), 400); };
      // Terms + Privacy consent is required for every way of creating an account
      const checkConsent = () => {
        const ok = agree.checked;
        consent.classList.toggle('has-error', !ok);
        agreeErr.classList.toggle('hidden', ok);
        agree.setAttribute('aria-invalid', String(!ok));
        return ok;
      };
      agree.addEventListener('change', () => { if (agree.checked) checkConsent(); });
      el.querySelector('#gSignup').onclick = () => {
        if (!checkConsent()) { shake(); agree.focus(); return; }
        ST.toast('Google sign-in opens the native Google account picker');
      };
      el.querySelector('#go').onclick = () => {
        const em = el.querySelector('#em'), pw = el.querySelector('#pw');
        el.querySelectorAll('.field').forEach(f => { f.classList.remove('has-error'); f.querySelector('.err')?.remove(); });
        let bad = false;
        const fail = (inp, msg) => { const f = inp.closest('.field'); f.classList.add('has-error'); f.querySelector('.help')?.classList.add('hidden'); f.insertAdjacentHTML('beforeend', `<span class="err">${I('warning-circle', 1)} ${msg}</span>`); bad = true; };
        if (!/^\S+@\S+\.\S+$/.test(em.value)) fail(em, 'Enter a valid email, like tolu@gmail.com');
        if (pw.value.length < 8) fail(pw, 'Password needs at least 8 characters');
        if (!checkConsent()) bad = true;
        const ref = el.querySelector('#refIn'), rf = el.querySelector('#refF');
        if (ref && ref.value && !/^[A-Z]{2,8}-[A-Z0-9]{4}$/.test(ref.value.trim().toUpperCase())) { rf.classList.add('has-error'); rf.querySelector('.err')?.remove(); rf.insertAdjacentHTML('beforeend', `<span class="err">${I('warning-circle', 1)} That referral code does not look right. Check it or leave it empty.</span>`); bad = true; }
        if (ST.deviceTaken) { ST.go('device-taken'); return; }
        if (bad) { shake(); (el.querySelector('.field.has-error input') || agree).focus(); return; }
        const b = el.querySelector('#go'); b.classList.add('is-loading'); b.textContent = 'Sending code';
        setTimeout(() => ST.go('otp', { email: em.value }), 900);
      };
    }
  });

  def('login', {
    title: 'Log in', group: G,
    render: () => `
      <div class="appbar"><button class="icon-btn" data-back="welcome" aria-label="Back">${I('arrow-left')}</button></div>
      <div class="scr-body"><div class="auth-head stack g3"><div style="height:36px">${mark(36)}</div><h1 class="t-h1">Welcome back</h1><p class="muted">Log in to continue your practice.</p></div>
        <form class="px5 stack g4 enter" onsubmit="return false">
          ${field('Email address', 'email', 'you@example.com', { ic: 'envelope-simple', val: 'tolu.adeyemi@gmail.com' })}
          ${field('Password', 'password', 'Your password', { ic: 'lock-simple', err: 'That password is not correct. Try again or reset it.', val: 'wrongpass' })}
          <a href="#" data-go="forgot" class="t-sm bold link-btn" style="align-self:flex-end">Forgot password?</a>
          <button class="btn btn-primary btn-block" data-go="welcome-back" data-mode="fade">Log in</button>
          <div class="or">OR</div>
          ${googleBtn('Continue with Google')}
          <p class="t-cap muted" style="text-align:center">If you are new, continuing with Google creates an account and means you agree to the <a href="#" data-go="help">Terms</a> and <a href="#" data-go="help">Privacy Policy</a>.</p>
          <p class="t-sm muted" style="text-align:center">New here? <a href="#" data-go="signup" class="bold link-btn">Create an account</a></p>
        </form></div>`,
    mount: pwToggle
  });

  // ---------- OTP ----------
  def('otp', {
    title: 'Verify email (OTP)', group: G,
    render: p => `
      <div class="appbar"><button class="icon-btn" data-back="signup" aria-label="Back">${I('arrow-left')}</button></div>
      <div class="scr-body"><div class="auth-head stack g3">
          <div class="ic blue" style="width:56px;height:56px;border-radius:16px;display:grid;place-items:center;font-size:28px">${I('envelope-simple-open', 1)}</div>
          <h1 class="t-h1">Check your email</h1>
          <p class="muted">Enter the 6-digit code we sent to <b style="color:var(--c-text)">${ST.esc(p.email || 'tolu.adeyemi@gmail.com')}</b>. It expires in 10 minutes.</p></div>
        <div class="px5 stack g4">
          <div class="otp" id="otp">${[0, 1, 2, 3, 4, 5].map(k => `<input inputmode="numeric" pattern="[0-9]*" maxlength="6" ${k ? 'autocomplete="off"' : 'autocomplete="one-time-code"'} aria-label="Digit ${k + 1} of 6">`).join('')}</div>
          <p class="err hidden" id="otpErr" role="alert">${I('warning-circle', 1)} <span>That code is not right. Check and try again.</span></p>
          <button class="btn btn-tonal btn-block" id="pasteCode">${I('clipboard-text', 1)} Paste code</button>
          <div class="row between t-sm"><span class="muted" id="cool">Resend code in <b class="tnum">0:60</b></span>
            <button class="btn btn-ghost btn-sm" id="resend" disabled>Resend</button></div>
          <div class="banner info">${I('info', 1)}<span>Copied the code from your email? Tap <b>Paste code</b>, or long-press a box and paste. <span class="t-cap">Prototype test code: <b>482913</b> works, any other 6 digits show the error.</span> <button class="btn btn-ghost btn-sm" id="copyTest" style="min-height:32px;padding:0 6px">Copy test code</button></span></div>
          <button class="btn btn-ghost" data-back="signup">Change email address</button>
        </div></div>`,
    mount(el) {
      const boxes = [...el.querySelectorAll('#otp input')], wrap = el.querySelector('#otp'), err = el.querySelector('#otpErr');
      const showErr = msg => { err.querySelector('span').textContent = msg; err.classList.remove('hidden'); };
      const clearErr = () => { wrap.classList.remove('bad'); err.classList.add('hidden'); };
      /** Put digits into the boxes starting at box `from` (paste, SMS/email autofill, keyboard suggestion). */
      const fill = (digits, from = 0) => {
        clearErr();
        if (digits.length >= 6) from = 0;                       // a full code always starts at the first box
        digits.slice(0, 6 - from).split('').forEach((c, k) => { const b = boxes[from + k]; b.value = c; b.classList.remove('filled'); void b.offsetWidth; b.classList.add('filled'); });
        const next = boxes.find(b => !b.value);
        (next || boxes[5]).focus();
        check();
      };
      const check = () => {
        const code = boxes.map(b => b.value).join('');
        if (code.length < 6) return;
        boxes.forEach(b => b.blur());
        if (code === '482913') { wrap.classList.add('ok'); setTimeout(() => ST.go('setup', { step: 1 }), 600); }
        else { wrap.classList.add('bad', 'shake'); showErr('That code is not right. Check and try again.');
          setTimeout(() => { wrap.classList.remove('shake'); }, 400); }
      };
      boxes.forEach((b, i) => {
        b.addEventListener('input', () => {
          clearErr();
          const d = b.value.replace(/\D/g, '');
          if (d.length > 1) { b.value = ''; return fill(d, i); }  // several digits at once = pasted or autofilled
          b.value = d; b.classList.toggle('filled', !!d);
          if (d && boxes[i + 1]) boxes[i + 1].focus(); check();
        });
        b.addEventListener('keydown', e => { if (e.key === 'Backspace' && !b.value && boxes[i - 1]) { boxes[i - 1].focus(); boxes[i - 1].value = ''; boxes[i - 1].classList.remove('filled'); } });
        b.addEventListener('paste', e => {
          e.preventDefault();
          const d = (e.clipboardData.getData('text') || '').replace(/\D/g, '');
          if (!d) return showErr('There is no code in what you copied. Copy the 6 digits from the email.');
          fill(d, i);
        });
        b.addEventListener('focus', () => b.select());
      });
      // Paste button: reads the clipboard (needs https or localhost; falls back to long-press paste)
      el.querySelector('#pasteCode').onclick = async () => {
        try {
          const t = await navigator.clipboard.readText();
          const d = (t || '').replace(/\D/g, '');
          if (d.length < 6) return showErr('Copy the 6-digit code from the email first, then tap Paste code.');
          fill(d.slice(0, 6), 0);
        } catch (e) {
          boxes[0].focus();
          ST.toast('Long-press the first box and tap Paste.', 'clipboard-text');
        }
      };
      el.querySelector('#copyTest').onclick = async () => {
        try { await navigator.clipboard.writeText('Your SolutionTee code is 482913'); ST.toast('Test code copied. Now tap Paste code.', 'copy'); }
        catch (e) { ST.toast('Copy is blocked here. Type 482913 instead.', 'info'); }
      };
      setTimeout(() => boxes[0].focus(), 350);
      let s = 60; const cool = el.querySelector('#cool b'), rb = el.querySelector('#resend');
      const iv = setInterval(() => { if (!el.isConnected) return clearInterval(iv); s--; cool.textContent = `0:${String(s).padStart(2, '0')}`;
        if (s <= 0) { clearInterval(iv); el.querySelector('#cool').textContent = "Didn't get it?"; rb.disabled = false; } }, ST.reduceMotion() ? 1000 : 1000);
      rb.onclick = () => ST.toast('New code sent. Check your inbox and spam folder.', 'paper-plane-tilt');
    }
  });

  def('forgot', {
    title: 'Forgot password', group: G,
    render: () => `
      <div class="appbar"><button class="icon-btn" data-back="login" aria-label="Back">${I('arrow-left')}</button></div>
      <div class="scr-body"><div class="auth-head stack g3">
          <div class="ic gold" style="width:56px;height:56px;border-radius:16px;display:grid;place-items:center;font-size:28px">${I('key', 1)}</div>
          <h1 class="t-h1">Reset your password</h1><p class="muted">Enter your email. We will send you a 6-digit code to set a new password.</p></div>
        <div class="px5 stack g4">${field('Email address', 'email', 'you@example.com', { ic: 'envelope-simple', val: 'tolu.adeyemi@gmail.com' })}
          <button class="btn btn-primary btn-block" data-go="reset">Send reset code</button></div></div>`
  });

  def('reset', {
    title: 'Set new password', group: G,
    render: () => `
      <div class="appbar"><button class="icon-btn" data-back="forgot" aria-label="Back">${I('arrow-left')}</button></div>
      <div class="scr-body"><div class="auth-head stack g2"><h1 class="t-h1">Create a new password</h1><p class="muted">Enter the code from your email and your new password.</p></div>
        <div class="px5 stack g4">
          ${field('6-digit code', 'text', '000000', { ic: 'hash', val: '482913', attrs: 'inputmode="numeric" maxlength="6"' })}
          ${field('New password', 'password', 'At least 8 characters', { ic: 'lock-simple', help: 'Use 8+ characters with a number.' })}
          ${field('Confirm new password', 'password', 'Type it again', { ic: 'lock-simple' })}
          <button class="btn btn-primary btn-block" data-go="login" id="rs">Save new password</button></div></div>`,
    mount(el) { pwToggle(el); el.querySelector('#rs').addEventListener('click', () => setTimeout(() => ST.toast('Password updated. Log in with your new password.'), 350)); }
  });

  // ---------- Profile setup (3 steps) ----------
  const STATES = ['Abia','Adamawa','Akwa Ibom','Anambra','Bauchi','Bayelsa','Benue','Borno','Cross River','Delta','Ebonyi','Edo','Ekiti','Enugu','FCT Abuja','Gombe','Imo','Jigawa','Kaduna','Kano','Katsina','Kebbi','Kogi','Kwara','Lagos','Nasarawa','Niger','Ogun','Ondo','Osun','Oyo','Plateau','Rivers','Sokoto','Taraba','Yobe','Zamfara'];
  const SUBJECTS = [['Mathematics','function'],['Physics','atom'],['Chemistry','flask'],['Biology','dna'],['Economics','chart-line-up'],['Government','bank'],['Literature in English','book-bookmark'],['Geography','globe-hemisphere-west'],['Commerce','storefront'],['Accounting','calculator'],['CRS','book-open'],['IRS','book-open'],['Agricultural Science','plant'],['Further Mathematics','sigma'],['History','scroll'],['Yoruba','translate']];
  def('setup', {
    title: 'Profile setup (3 steps)', group: G,
    render: p => {
      const step = +(p.step || 1);
      const steps = `<div class="steps">${[1, 2, 3].map(n => `<i class="${n <= step ? 'on' : ''}"></i>`).join('')}</div>`;
      let body = '';
      if (step === 1) body = `
        <h1 class="t-h1">Tell us about you</h1><p class="muted">This helps us personalise your practice.</p>
        <div class="stack g4 enter mt2">
          ${field('Full name', 'text', 'e.g. Tolu Adeyemi', { val: 'Tolu Adeyemi', ic: 'user' })}
          ${field('Phone number (optional)', 'tel', '0803 000 0000', { ic: 'phone', help: 'For class reminders only. We never share it.' })}
          <div class="field"><label>State</label><div class="input"><select>${STATES.map(s => `<option ${s === 'Oyo' ? 'selected' : ''}>${s}</option>`).join('')}</select><i class="ph ph-caret-down sel-caret"></i></div></div>
          ${field('School (optional)', 'text', 'e.g. Loyola College, Ibadan', { ic: 'graduation-cap' })}
        </div>`;
      if (step === 2) body = `
        <h1 class="t-h1">Which exams are you writing?</h1><p class="muted">Pick all that apply. You can change this later.</p>
        <div class="stack g3 enter mt2">
          ${['JAMB', 'WAEC', 'NECO'].map((b, k) => `<button class="subj ${k < 2 ? 'on' : ''}" data-multi style="min-height:72px">${examLogo(b)}<span><b>${b === 'JAMB' ? 'JAMB UTME' : b === 'WAEC' ? 'WAEC WASSCE' : 'NECO SSCE'}</b><br><span class="t-cap muted">${b === 'JAMB' ? '4 subjects · 180 questions · 2 hours' : 'Objective papers per subject'}</span></span><span class="tick">${I('check', 1)}</span></button>`).join('')}
          <div class="field mt2"><label>Target JAMB score</label>
            <div class="row g3"><input type="range" min="180" max="400" value="290" id="tgt" style="flex:1;accent-color:var(--c-secondary)"><b class="tnum t-h3" id="tgtv" style="width:44px;text-align:right">290</b></div>
            <span class="help">Most competitive courses need 280+.</span></div>
        </div>`;
      if (step === 3) body = `
        <h1 class="t-h1">Your JAMB subjects</h1><p class="muted">Use of English is compulsory. Choose <b>3 more</b>.</p>
        <div class="row between mt2"><span class="t-sm bold" id="cnt">2 of 3 chosen</span><span class="badge badge-soft">${I('info', 1)} English + 3</span></div>
        <div class="stack g2 mt2">
          <button class="subj on locked" aria-disabled="true">${I('book-open-text')} Use of English <span class="badge badge-neutral" style="margin-left:auto">Compulsory</span></button>
          <div class="grid2 enter">${SUBJECTS.map(([s, ic], k) => `<button class="subj ${k < 2 ? 'on' : ''}" data-pick style="font-size:13px;padding:0 10px">${I(ic)}<span style="line-height:17px">${s}</span><span class="tick">${I('check', 1)}</span></button>`).join('')}</div>
        </div>`;
      return `
        <div class="appbar"><button class="icon-btn" ${step > 1 ? `data-go="setup" data-params="step=${step - 1}" data-mode="back"` : 'data-back="otp"'} aria-label="Back">${I('arrow-left')}</button>
          <div class="grow px4">${steps}</div><span class="t-cap muted bold" style="padding-right:12px">${step}/3</span></div>
        <div class="scr-body"><div class="pad stack g2">${body}</div></div>
        <div class="footer-cta"><button class="btn btn-primary btn-block" id="cont" ${step === 3 ? 'disabled' : ''}>${step === 3 ? 'Finish setup' : 'Continue'}</button></div>`;
    },
    mount(el, p) {
      const step = +(p.step || 1);
      el.querySelectorAll('[data-multi]').forEach(b => b.onclick = () => b.classList.toggle('on'));
      const tgt = el.querySelector('#tgt'); if (tgt) tgt.oninput = () => el.querySelector('#tgtv').textContent = tgt.value;
      const cont = el.querySelector('#cont');
      if (step === 3) {
        const upd = () => { const n = el.querySelectorAll('[data-pick].on').length; el.querySelector('#cnt').textContent = `${n} of 3 chosen`; cont.disabled = n !== 3; cont.classList.toggle('is-disabled', n !== 3); };
        el.querySelectorAll('[data-pick]').forEach(b => b.onclick = () => {
          if (!b.classList.contains('on') && el.querySelectorAll('[data-pick].on').length >= 3) { ST.toast('You can pick only 3. Tap one to remove it first.', 'info'); return; }
          b.classList.toggle('on'); upd();
        });
        upd();
      }
      cont.onclick = () => {
        const S = ST.state;
        if (step === 2) {
          const ex = [...el.querySelectorAll('[data-multi].on b')].map(b => b.textContent.split(' ')[0]);
          if (!ex.length) { ST.toast('Pick at least one exam.', 'info'); return; }
          S.exams = ex; S.target = +el.querySelector('#tgt').value;
        }
        if (step === 3) S.subjects = ['Use of English', ...[...el.querySelectorAll('[data-pick].on span:not(.tick)')].map(x => x.textContent)];
        step < 3 ? ST.go('setup', { step: step + 1 }) : ST.go('welcome-new', null, { mode: 'fade' });
      };
    }
  });


  // ---------- Welcome (new account): after profile setup, before the tour ----------
  const SUBJ_IC = Object.fromEntries([['Use of English', 'book-open-text'], ...SUBJECTS]);
  def('welcome-new', {
    title: 'Welcome (new account)', group: G, cls: 'wn', // colours follow light/dark theme via --wn-* vars (app.css)
    render: () => {
      const S = ST.state, exams = S.exams || ['JAMB', 'WAEC'], subjects = S.subjects || ['Use of English', 'Mathematics', 'Physics', 'Chemistry'], target = S.target || 290;
      return `
      <canvas id="confetti"></canvas>
      <div class="scr-body" style="display:flex;flex-direction:column">
        <div class="stack center g3" style="padding:var(--s-6) var(--s-6) var(--s-5);text-align:center">
          <div class="wn-badge">
            <svg viewBox="0 0 120 120" aria-hidden="true"><circle cx="60" cy="60" r="54" class="wn-track"/><circle cx="60" cy="60" r="54" class="wn-ring" pathLength="1"/></svg>
            ${ST.avatar('xl wn-avatar')}
            <span class="wn-check">${I('check-fat', 1)}</span>
          </div>
          <h1 class="t-h1 wn-in wn-title" style="--i:1">Welcome to SolutionTee, ${S.first}!</h1>
          <p class="wn-in wn-muted" style="--i:2;max-width:30ch">Your account is ready. Here is the plan we made for you.</p>
        </div>
        <div class="px5 stack g3 enter" style="padding-bottom:var(--s-4)">
          <div class="wn-row"><span class="wn-ic">${I('exam', 1)}</span><div class="grow"><span class="wn-label">Your exams</span>
            <div class="row g2 mt2">${exams.map(b => `<span class="row g2 wn-chip">${examLogo(b, 'sm')}${b}</span>`).join('')}</div></div></div>
          <div class="wn-row"><span class="wn-ic">${I('books', 1)}</span><div class="grow"><span class="wn-label">JAMB subjects</span>
            <div class="row wrap g2 mt2">${subjects.map(x => `<span class="wn-chip">${I(SUBJ_IC[x] || 'book-open')} ${x}</span>`).join('')}</div></div></div>
          <div class="wn-row"><span class="wn-ic">${I('target', 1)}</span><div class="grow"><div class="row between"><span class="wn-label">Target score</span><b class="tnum wn-title">${target}<span class="wn-muted" style="font-weight:500"> / 400</span></b></div>
            <div class="bar mt2 wn-bar"><i class="wn-fill" style="width:${Math.round(target / 4)}%"></i></div></div></div>
          <div class="wn-row"><span class="wn-ic">${I('gift', 1)}</span><div class="grow"><span class="wn-label">Free plan</span>
            <p class="t-sm wn-body">JAMB 2000 to 2002 and 3 AI prompts a day. <a href="#" data-sheet="paywall" class="bold wn-link">See Premium</a></p></div></div>
        </div>
        <div class="footer-cta clean stack g2" style="background:transparent;margin-top:auto">
          <button class="btn btn-accent btn-block" data-go="tour" data-mode="fade">${I('map-trifold', 1)} Take a 30-second tour</button>
          <button class="btn btn-ghost wn-ghost" id="skipTour">Skip, go to Home</button>
        </div>
      </div>`;
    },
    mount(el) {
      // confetti colours read from the current theme (no white pieces on the light background)
      if (!ST.reduceMotion()) setTimeout(() => el.isConnected && ST.confetti(el.querySelector('#confetti'), ST.isDark() ? null : ['#F2B233', '#2563B3', '#0B1F44', '#7AA0D1', '#D99A1E']), 650);
      el.querySelector('#skipTour').onclick = () => { ST.go('home', null, { mode: 'fade' }); setTimeout(() => ST.toast('You can replay the tour any time from Me, then Help.', 'map-trifold'), 400); };
    }
  });

  // ---------- Welcome back: after log in ----------
  def('welcome-back', {
    title: 'Welcome back (after log in)', group: G,
    render: () => {
      const S = ST.state, h = new Date().getHours();
      const hello = h < 12 ? 'Good morning' : h < 17 ? 'Good afternoon' : 'Good evening';
      const days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'], today = (new Date().getDay() + 6) % 7, done = S.streak || 6;
      return `
      <div class="scr-body" style="display:flex;flex-direction:column">
        <div class="stack center g3" style="padding:var(--s-7) var(--s-6) var(--s-5);text-align:center">
          <div class="wb-avatar">${ST.avatar('xl')}<span class="wb-wave">${I('hand-waving', 1)}</span></div>
          <p class="muted t-lg wn-in" style="--i:1">${hello},</p>
          <h1 class="t-display wn-in" style="--i:2">Welcome back, ${S.first}</h1>
        </div>
        <div class="px5 stack g4 enter">
          <section class="card card-pad stack g3">
            <div class="row g3"><span class="wb-flame">${I('fire', 1)}</span><div class="grow"><b>${done}-day streak</b><p class="t-sm muted">Answer one question today to make it ${done + 1}.</p></div></div>
            <div class="week">${days.map((d, k) => `<span class="${k < today ? 'done' : k === today ? 'today' : ''}" style="--i:${k}"><i>${k < today ? I('check', 1) : ''}</i>${d}</span>`).join('')}</div>
          </section>
          ${ST.unfinishedCard ? ST.unfinishedCard() : ''}
          <section class="card list">
            <div class="list-item"><span class="lead" style="background:var(--c-accent-soft);color:var(--c-on-accent-soft)">${I('sparkle', 1)}</span><span class="grow"><b class="t-sm">New since your last visit</b><div class="t-cap muted">JAMB 2026 Physics is now available</div></span></div>
            <div class="list-item"><span class="lead">${I('video-camera', 1)}</span><span class="grow"><b class="t-sm">Free Maths revision class</b><div class="t-cap muted">Saturday · 10:00 AM</div></span></div>
          </section>
        </div>
        <div class="footer-cta clean stack g2" style="margin-top:auto">
          ${ST.cbtSaved && ST.attemptAnswered(ST.cbtSaved)
            ? `<button class="btn btn-primary btn-block" data-go="cbt" data-params="resume=1">Continue my test</button><button class="btn btn-ghost" data-go="home" data-mode="fade">Go to Home</button>`
            : `<button class="btn btn-primary btn-block" data-go="home" data-mode="fade">Start practising</button>`}
        </div>
      </div>`;
    },
    mount: el => ST.animateBars(el)
  });

  // ---------- Guided tour (spotlight on Home) ----------
  const TOUR = [
    { sel: '[data-tour=start]', t: 'Start a test here', d: 'Tap JAMB, WAEC or NECO to start a timed CBT practice.' },
    { sel: '[data-tour=compete]', t: 'Win cash every week', d: 'Join the weekly challenge. Fastest correct answers win money. Free for everyone.' },
    { sel: '[data-tab=study]', t: 'Study anytime', d: 'Past questions, video solutions, lesson notes, novels and syllabuses.' },
    { sel: '[data-tab=test]', t: 'All test modes', d: 'Full exam, single subject, topic drills, quick tests and practice by year.' },
    { sel: '[data-tab=ai]', t: 'Ask SolutionTee AI', d: 'Get step-by-step help on any question. Free users get 3 prompts a day.' },
    { sel: '[data-tour=upgrade]', t: 'Unlock everything', d: 'Go Premium for all years, all exams and 100 AI prompts a day.' }
  ];
  def('tour', {
    title: 'Guided tour (coach marks)', group: G, tab: 'home',
    render: p => ST.screens.home.render(p),
    mount(el) {
      ST.screens.home.mount?.(el, {});
      let k = 0;
      const ovl = document.createElement('div');
      ovl.style.cssText = 'position:absolute;inset:0;z-index:70';
      ovl.innerHTML = `<div class="tour-catch"></div><div class="tour-hole"></div><div class="tour-tip" role="dialog" aria-live="polite"></div>`;
      el.appendChild(ovl);
      const hole = ovl.querySelector('.tour-hole'), tip = ovl.querySelector('.tour-tip');
      const end = () => {
        ovl.remove();
        ST.go('home', null, { mode: 'fade', replace: true });
        setTimeout(() => ST.toast('Tour finished. Replay it any time from Me → Help.', 'flag-checkered'), 300);
      };
      const show = () => {
        const s = TOUR[k], t = el.querySelector(s.sel);
        if (!t) { k++; return k < TOUR.length ? show() : end(); }   // skip steps hidden for this student (e.g. Upgrade on Premium)
        t.scrollIntoView?.({ block: 'nearest' });
        const r = t.getBoundingClientRect(), base = el.getBoundingClientRect(), sc = base.width / el.offsetWidth;
        const x = (r.left - base.left) / sc, y = (r.top - base.top) / sc, w = r.width / sc, h = r.height / sc;
        Object.assign(hole.style, { left: x - 6 + 'px', top: y - 6 + 'px', width: w + 12 + 'px', height: h + 12 + 'px' });
        const below = y < el.offsetHeight / 2;
        tip.style.top = below ? (y + h + 22) + 'px' : 'auto';
        tip.style.bottom = below ? 'auto' : (el.offsetHeight - y + 22) + 'px';
        tip.innerHTML = `<div class="row between"><span class="t-over subtle">Step ${k + 1} of ${TOUR.length}</span><button class="btn btn-ghost btn-sm" id="tSkip">Skip tour</button></div>
          <h3 class="t-h3 mt2">${s.t}</h3><p class="muted t-sm mt2">${s.d}</p>
          <div class="row between mt4"><div class="ob-dots">${TOUR.map((_, i) => `<i class="${i === k ? 'on' : ''}"></i>`).join('')}</div>
          <button class="btn btn-primary btn-sm" id="tNext">${k === TOUR.length - 1 ? 'Done' : 'Next'}</button></div>`;
        tip.querySelector('#tSkip').onclick = end;
        tip.querySelector('#tNext').onclick = () => { k++; k < TOUR.length ? show() : end(); };
      };
      setTimeout(show, 450);
    }
  });
})();
