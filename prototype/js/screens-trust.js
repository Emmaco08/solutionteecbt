/* Referrals, one-account-per-person protection (multiple accounts, app cloners), bans,
   and the public Winners wall with proof of payment. */
(function () {
  const { def, icon: I } = ST;
  const S = ST.state;
  const G = 'Referrals & trust';

  // ---------- Referral rules (admin → Referrals). Real app: server table referral_rules. ----------
  ST.REF_DEFAULT = { step: 10, freeAt: 10, freePlan: '3 Months', cashAt: 30, cashAmount: 5000, success: 'test', monthlyCap: 50 };
  ST.refRules = () => { try { return { ...ST.REF_DEFAULT, ...JSON.parse(localStorage.getItem('st-ref') || '{}') }; } catch (e) { return { ...ST.REF_DEFAULT }; } };
  const SUCCESS_TEXT = { verify: 'signs up with your code and verifies their email and phone', test: 'signs up with your code, verifies their phone and finishes one practice test', pay: 'signs up with your code and buys Premium' };
  ST.ref = ST.ref || { code: 'TOLU-7K3P', successful: 3, usedForDiscount: 0, paidOut: 0 };

  const FRIENDS = [
    ['Ada E.', 'Took a practice test', 'success', 'check-circle'], ['Kunle B.', 'Took a practice test', 'success', 'check-circle'], ['Musa I.', 'Took a practice test', 'success', 'check-circle'],
    ['Ngozi A.', 'Signed up · needs to verify phone', 'pending', 'hourglass-medium'], ['Bisi K.', 'Joined · needs to take a test', 'pending', 'hourglass-medium'],
    ['"Tolu2"', 'Not counted: same phone as your account', 'blocked', 'prohibit']
  ];

  def('referral', {
    title: 'Invite friends (referral)', group: G,
    render: () => {
      const R = ST.refRules(), r = ST.ref, avail = r.successful - r.usedForDiscount;
      const pct = Math.min(100, avail * R.step), toFree = Math.max(0, R.freeAt - avail), cashLeft = Math.max(0, R.cashAt - r.successful);
      return `
      <div class="appbar"><button class="icon-btn" data-back="profile" aria-label="Back">${I('arrow-left')}</button><span class="title">Invite friends</span><button class="icon-btn" id="refHow" aria-label="How it works">${I('info')}</button></div>
      <div class="scr-body"><div class="pad stack g4" style="padding-top:var(--s-2)">
        <section class="ref-hero">
          <span class="t-cap" style="color:var(--gold-300);font-weight:700">Invite friends, earn rewards</span>
          <b class="ref-big">${R.step}% off for every friend</b>
          <span class="t-sm" style="color:#DCE4F2">${R.freeAt} friends = Premium free. ${R.cashAt} friends = ${ST.naira(R.cashAmount)} cash.</span>
          <div class="ref-code"><span class="t-cap" style="color:#AFC0DD">Your code</span><b class="code-input tnum" id="myCode">${r.code}</b><button class="btn btn-sm" id="copyRef">${I('copy')} Copy</button></div>
          <button class="btn btn-accent btn-block" id="shareRef">${I('whatsapp-logo', 1)} Share on WhatsApp</button>
        </section>

        <section class="card card-pad stack g3">
          <div class="row between"><b>Your discount</b><b class="tnum ref-pct">${pct}% off</b></div>
          <div class="ref-meter" role="progressbar" aria-valuenow="${pct}" aria-valuemin="0" aria-valuemax="100">${Array.from({ length: R.freeAt }, (_, k) => `<i class="${k < avail ? 'on' : ''}" style="--k:${k}"></i>`).join('')}</div>
          <p class="t-sm muted">${avail ? `${avail} successful friend${avail > 1 ? 's' : ''} so far.` : 'No successful friends yet.'} ${toFree ? `${toFree} more for Premium free (${R.freePlan}).` : `You have earned Premium free (${R.freePlan})!`}</p>
          <div class="row g2"><button class="btn btn-primary btn-sm grow" id="useDisc" ${pct ? '' : 'disabled'}>${pct >= 100 ? 'Get Premium free' : `Use my ${pct}% discount`}</button><button class="btn btn-ghost btn-sm" id="keepGoing">Keep inviting</button></div>
          <p class="t-cap subtle">Using your discount spends those friends. Your cash count below never resets.</p>
        </section>

        <section class="card card-pad stack g3">
          <div class="row between"><b>Cash reward</b><b class="tnum">${ST.naira(R.cashAmount)}</b></div>
          <div class="bar"><i data-v="${Math.min(100, Math.round(r.successful / R.cashAt * 100))}%"></i></div>
          <p class="t-sm muted">${r.successful} of ${R.cashAt} successful friends. ${cashLeft ? `${cashLeft} more and we pay ${ST.naira(R.cashAmount)} to your bank account.` : 'You reached it! Send your account details.'}</p>
        </section>

        <section class="stack g2"><div class="sect-title" style="margin:0"><h2 class="t-h3">Your friends</h2><span class="t-cap muted">${FRIENDS.length}</span></div>
          <div class="card list">${FRIENDS.map(([n, d, st, ic]) => `<div class="list-item"><span class="lead ref-st-${st}">${I(ic, 1)}</span><span class="grow"><b class="t-sm">${n}</b><div class="t-cap muted">${d}</div></span>${st === 'success' ? `<span class="badge badge-success">+${R.step}%</span>` : st === 'blocked' ? '<span class="badge badge-error">Blocked</span>' : '<span class="badge badge-neutral">Pending</span>'}</div>`).join('')}</div></section>
        <p class="t-cap subtle" style="text-align:center">A friend counts when they ${SUCCESS_TEXT[R.success]}, on their own phone. Accounts on the same phone, cloned apps or fake friends never count, and can lead to a ban.</p>
      </div></div>`;
    },
    mount(el) {
      ST.animateBars(el);
      const R = ST.refRules(), r = ST.ref;
      el.querySelector('#copyRef').onclick = () => { navigator.clipboard?.writeText(`Join me on SolutionTee CBT and practise JAMB, WAEC and NECO free. Use my code ${r.code}: https://solutiontee.com/r/${r.code}`).catch(() => {}); ST.toast('Invite link copied', 'copy'); };
      el.querySelector('#shareRef').onclick = () => ST.toast('Opens WhatsApp with your invite link', 'whatsapp-logo');
      el.querySelector('#keepGoing').onclick = () => el.querySelector('#shareRef').scrollIntoView({ behavior: 'smooth', block: 'center' });
      el.querySelector('#useDisc').onclick = () => {
        const avail = r.successful - r.usedForDiscount, pct = Math.min(100, avail * R.step);
        const code = `REF-${r.code.split('-')[0]}${pct}`;
        ST.CODES[code] = pct >= 100 ? { type: 'pct', value: 100, plans: ['q'] } : { type: 'pct', value: pct, plans: ['m', 'q', 'e'] };
        ST.sheet(`<div class="stack g3" style="text-align:center;align-items:center">
          <span class="ob-trophy">${I('ticket', 1)}</span><h2 class="t-h2">${pct >= 100 ? `Premium free: ${R.freePlan}` : `Your ${pct}% discount code`}</h2>
          <div class="code-ok" style="width:100%;justify-content:center"><b class="code-input" style="font-size:20px">${code}</b></div>
          <p class="t-sm muted">${pct >= 100 ? 'You will not pay anything. Use it on the 3 Months plan.' : 'Use it at checkout. It works once and lasts 30 days.'}</p>
          <button class="btn btn-primary btn-block" id="goUse">${pct >= 100 ? 'Activate Premium' : 'Upgrade with my code'}</button></div>`, {
          mount: w => w.querySelector('#goUse').onclick = () => { r.usedForDiscount += avail; ST.closeOverlay(true); S.payFlavor = 'direct'; ST.go('checkout', { plan: pct >= 100 ? 'q' : 'q' }); setTimeout(() => ST.toast(`Tap "Have a discount code?" and enter ${code}`, 'ticket'), 500); }
        });
      };
      el.querySelector('#refHow').onclick = () => ST.sheet(`<h2 class="t-h3">How referrals work</h2><div class="stack g3 mt4 t-sm">${[
        ['share-network', `Share your code. A friend counts when they ${SUCCESS_TEXT[R.success]}.`],
        ['percent', `Each friend adds ${R.step}% off Premium. ${R.freeAt} friends = 100% off: Premium (${R.freePlan}) for free.`],
        ['money', `When ${R.cashAt} friends have joined in total, we pay you ${ST.naira(R.cashAmount)}.`],
        ['device-mobile', 'Friends must use their own phone and their own phone number. Accounts on the same phone, app cloners and fake sign-ups are blocked.'],
        ['prohibit', 'Cheating the referral programme bans every linked account and cancels all rewards.']].map(([ic, t]) => `<div class="benefit">${I(ic, 1).replace('class="', 'style="color:var(--c-secondary);font-size:20px" class="')}<span>${t}</span></div>`).join('')}</div>`);
    }
  });

  /** Small invite card for Home and Me. */
  ST.referralCard = () => `<button class="card card-tap row g3" style="padding:var(--s-4)" data-go="referral">
      <span class="ic gold" style="width:48px;height:48px;border-radius:12px;display:grid;place-items:center;font-size:24px;flex:none">${I('gift', 1)}</span>
      <span class="grow"><b style="display:block">Invite friends, get Premium free</b><span class="t-cap muted">${ST.refRules().step}% off per friend · ${ST.ref.successful} joined so far</span></span>${I('caret-right')}</button>`;

  // ---------- One account per person: protection screens ----------
  def('device-taken', {
    title: 'Blocked: phone already has an account', group: G,
    render: () => `
      <div class="appbar"><button class="icon-btn" data-back="signup" aria-label="Back">${I('arrow-left')}</button></div>
      <div class="scr-body"><div class="state">
        <div class="art navy">${I('device-mobile', 1)}</div>
        <h2 class="t-h2">This phone already has an account</h2>
        <p class="muted">SolutionTee allows one account per phone, so challenges, prizes and referrals stay fair for everyone.</p>
        <div class="card card-pad row g3 mt2" style="width:100%;text-align:left"><span class="avatar" style="width:40px;height:40px;font-size:14px">TA</span><span class="grow"><b class="t-sm">to••••@gmail.com</b><div class="t-cap muted">Created 12 Sep 2026</div></span></div>
        <button class="btn btn-primary btn-block mt2" data-go="login">Log in to that account</button>
        <button class="btn btn-ghost" data-go="forgot">I forgot the password</button>
        <p class="t-cap subtle mt2">Bought a used phone? Contact support on WhatsApp and we will move it to you.</p>
      </div></div>`
  });

  def('unsafe-app', {
    title: 'Blocked: app cloner / dual app detected', group: G, navy: true,
    render: () => `
      <div class="scr-body" style="display:flex;flex-direction:column;justify-content:center">
        <div class="state" style="color:#F4F7FC">
          <div class="art" style="background:rgba(229,72,77,.18);color:#FF8A8A">${I('copy-simple', 1)}</div>
          <h2 class="t-h2">SolutionTee can't run here</h2>
          <p style="color:#AFC0DD">We found that this copy of the app is running inside an app cloner or dual-app space (for example Parallel Space, Dual Space or App Cloner).</p>
          <div class="card card-pad stack g2 mt2" style="width:100%;text-align:left;background:rgba(255,255,255,.06);border-color:rgba(255,255,255,.1)">
            <b class="t-sm" style="color:#fff">To keep using SolutionTee</b>
            ${['Close the cloned app', 'Open SolutionTee installed from the Play Store or solutiontee.com', 'Log in to your one account'].map((t, k) => `<div class="row g2 t-sm" style="color:#DCE4F2"><b class="tnum" style="color:var(--gold-400)">${k + 1}</b>${t}</div>`).join('')}
          </div>
          <p class="t-cap mt2" style="color:#8FA3C4">Trying to make extra accounts with cloned apps leads to a ban on every linked account.</p>
          <button class="btn btn-accent btn-block mt2" data-toast="The app closes">Close app</button>
        </div>
      </div>`
  });

  def('banned', {
    title: 'Account banned', group: G,
    render: () => `
      <div class="scr-body"><div class="state">
        <div class="art red">${I('prohibit', 1)}</div>
        <h2 class="t-h2">Your account has been banned</h2>
        <p class="muted">We found several accounts on one phone used to collect referral rewards and challenge prizes. This breaks our fair-play rules.</p>
        <div class="card list mt2" style="width:100%;text-align:left">
          ${[['user-minus', 'All 4 linked accounts are banned'], ['currency-ngn', 'Unpaid rewards and prizes are cancelled'], ['device-mobile', 'This phone cannot create new accounts']].map(([ic, t]) => `<div class="list-item"><span class="lead" style="background:var(--c-error-soft);color:var(--c-on-error-soft)">${I(ic, 1)}</span><span class="grow t-sm bold">${t}</span></div>`).join('')}
        </div>
        <p class="t-sm muted mt2">Think this is a mistake? You can appeal once, within 14 days.</p>
        <button class="btn btn-outline btn-block" data-toast="Appeal form opened. We reply within 3 working days.">Appeal this ban</button>
        <p class="t-cap subtle">Ref: BAN-26-10-0193</p>
      </div></div>`
  });

  // ---------- Winners wall (proof of payment) ----------
  const SAMPLE_PROOFS = [
    { name: 'Ifeoma N.', state: 'Enugu', ch: 'Weekly Challenge #43', place: '1st', amt: 20000, date: '27 Oct 2026', ref: 'TRF_••••8KQ2', bank: 'Access Bank ••••4410' },
    { name: 'Mubarak I.', state: 'Kwara', ch: 'Weekly Challenge #43', place: '2nd', amt: 10000, date: '27 Oct 2026', ref: 'TRF_••••3MZ7', bank: 'Opay ••••9921' },
    { name: 'Zainab Y.', state: 'Kaduna', ch: 'Weekly Challenge #43', place: '3rd', amt: 5000, date: '28 Oct 2026', ref: 'TRF_••••1PD4', bank: 'Guardian · GTBank ••••0373' },
    { name: 'Chukwuemeka O.', state: 'Imo', ch: 'Referral reward (30 friends)', place: 'Referral', amt: 5000, date: '25 Oct 2026', ref: 'TRF_••••7HX1', bank: 'Kuda ••••2208' }
  ];
  ST.proofs = () => { let up = []; try { up = JSON.parse(localStorage.getItem('st-proofs') || '[]'); } catch (e) {} return [...up, ...SAMPLE_PROOFS]; };
  const receipt = p => p.img
    ? `<button class="proof-img" data-img="${p.img}" aria-label="View proof of payment"><img src="${p.img}" alt="Proof of payment for ${p.name}"></button>`
    : `<div class="proof-receipt" aria-label="Sample transfer receipt"><span class="badge badge-sample">SAMPLE RECEIPT</span><div class="row between t-cap"><span class="muted">Transfer successful</span>${I('check-circle', 1).replace('class="', 'style="color:var(--c-success);font-size:18px" class="')}</div>
        <b class="tnum" style="font-size:22px">${ST.naira(p.amt)}</b><div class="t-cap muted">To ${p.bank}</div><div class="t-cap muted">Ref ${p.ref} · ${p.date}</div></div>`;

  def('winners-wall', {
    title: 'Winners wall (proof of payment)', group: G,
    render: () => {
      const list = ST.proofs(), total = list.reduce((t, p) => t + p.amt, 0);
      return `
      <div class="appbar"><button class="icon-btn" data-back="compete" aria-label="Back">${I('arrow-left')}</button><span class="title">Winners wall<small>Proof that we pay our winners</small></span></div>
      <div class="scr-body"><div class="pad stack g4" style="padding-top:var(--s-2)">
        <section class="ch-prize-banner">${I('seal-check', 1)}<span class="grow"><span class="t-cap">Paid to winners so far</span><br><b class="tnum" style="font-size:26px">${ST.naira(total + 1240000)}</b></span><span class="t-cap" style="text-align:right">${list.length + 61} winners<br>paid</span></section>
        <div class="stack g3 enter">${list.map(p => `<article class="card proof-card">
          <div class="row g3"><span class="avatar" style="width:40px;height:40px;font-size:14px">${p.name.split(' ').map(x => x[0]).join('')}</span><span class="grow"><b class="t-sm">${p.name}</b> <span class="t-cap muted">${p.state}</span><div class="t-cap muted">${p.place} · ${p.ch}</div></span><span class="badge badge-success">${I('check', 1)} Paid</span></div>
          ${receipt(p)}${p.note ? `<p class="t-sm">“${p.note}”</p>` : ''}</article>`).join('')}</div>
        <p class="t-cap subtle" style="text-align:center">Account numbers and balances are hidden. Winners under 18 are paid through a parent or guardian and are shown by first name only.</p>
      </div></div>`;
    },
    mount(el) { el.querySelectorAll('[data-img]').forEach(b => b.onclick = () => ST.viewImage(b.dataset.img, 'Proof of payment')); }
  });
})();
