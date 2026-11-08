"use client";
import Link from "next/link";
import { useRouter, useSearchParams } from "next/navigation";
import { AnimatePresence, motion, useReducedMotion } from "motion/react";
import { useCallback, useEffect, useMemo, useState } from "react";
import { ArrowLeft, ArrowRight, CheckCircle, Crown, EnvelopeSimple, LockSimple, ShieldCheck, SignOut, SpinnerGap, Ticket, XCircle } from "@phosphor-icons/react";
import type { Session } from "@supabase/supabase-js";
import { createClient } from "@/lib/supabase/client";

type Plan = { code: string; name: string; description: string | null; price_kobo: number; duration_days: number | null; ends_on: string | null };
type Quote = { list_kobo: number; discount_kobo: number; fee_kobo?: number; amount_kobo: number; label?: string | null; code?: string | null; period_end?: string | null };

const ng = (kobo: number) => `₦${(kobo / 100).toLocaleString("en-NG")}`;
const day = (s: string) => new Date(s).toLocaleDateString("en-NG", { day: "numeric", month: "long", year: "numeric" });
const ease = [0.22, 1, 0.36, 1] as const;
const PENDING = "st-pay-pending"; // the payment opened in Paystack (this tab only)
const REF = /^st_[0-9a-f]{20}$/;
const IDLE_MS = 15 * 60_000; // logged out after 15 minutes without activity

/** Our own pages only: Paystack sends the student back here (the server checks these too). */
function backPages() {
  const o = window.location.origin;
  return /^https:\/\/(cbt|admin)\.solutiontee\.com$/.test(o) ? { callback: `${o}/pay/done`, cancel: `${o}/pay` } : {};
}

type Left = { kind: "checking" | "cancelled"; ref: string } | null;

const QUOTE_ERRORS: Record<string, string> = {
  not_found: "We could not find that code. Check the spelling.", expired: "This code has expired.", used_up: "This code has been used up.",
  already_used: "You have already used this code.", new_only: "This code is only for students who have never paid.",
  wrong_plan: "This code does not work on this plan.", too_many_tries: "Too many wrong codes. Please wait an hour.",
  covered: "Your Premium already covers this plan’s end date.", banned: "This account cannot make payments. Contact support.",
  plan: "This plan is not on sale any more. Pick another.", days_code: "This code gives free days: redeem it in the app (Me → Redeem a code).",
};

/** The payment website (D-114): log in with an email code, pick a plan, pay with Paystack (every method Paystack offers). */
export function PayFlow() {
  const sp = useSearchParams();
  const router = useRouter();
  const sb = useMemo(() => createClient(), []);
  const still = useReducedMotion();
  const [session, setSession] = useState<Session | null>(null);
  const [ready, setReady] = useState(false);
  const [email, setEmail] = useState(sp.get("email") ?? "");
  const [codeLen, setCodeLen] = useState<number | null>(null);
  const [otp, setOtp] = useState("");
  const [plans, setPlans] = useState<Plan[]>([]);
  const [pick, setPick] = useState<string>(sp.get("plan") ?? "three_months");
  const [discount, setDiscount] = useState("");
  const [applied, setApplied] = useState<string | null>(null);
  const [quote, setQuote] = useState<Quote | null>(null);
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState<string | null>(null);
  const [note, setNote] = useState<string | null>(null);
  const [left, setLeft] = useState<Left>(null);
  const [handoff, setHandoff] = useState(Boolean(sp.get("h")));

  /** Calls the Paystack Edge Function as the signed-in student. */
  const edge = useCallback(async (s: Session, body: Record<string, unknown>) => {
    const r = await fetch(`${process.env.NEXT_PUBLIC_SUPABASE_URL}/functions/v1/paystack`, {
      method: "POST",
      headers: { "content-type": "application/json", authorization: `Bearer ${s.access_token}`, apikey: process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY! },
      body: JSON.stringify(body),
    });
    const j = await r.json().catch(() => ({}));
    if (!r.ok) throw new Error(j.error ?? "Paystack is not answering. Try again in a moment.");
    return j as Record<string, unknown>;
  }, []);

  // From the app (D-115): a one-time code in the link logs the student in, then is removed from the address bar.
  useEffect(() => {
    const code = sp.get("h");
    if (!code) return;
    const url = new URL(window.location.href);
    url.searchParams.delete("h");
    url.searchParams.delete("email");
    window.history.replaceState(null, "", url.pathname + url.search);
    let live = true;
    (async () => {
      try {
        const r = await fetch("/api/web/handoff/redeem", { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify({ code }) });
        const j = await r.json().catch(() => ({}));
        if (!r.ok || !j.token_hash) throw new Error(j.error ?? "This link has expired. Log in with your email instead.");
        await sb.auth.signOut({ scope: "local" }); // never mix two accounts
        const { error } = await sb.auth.verifyOtp({ token_hash: j.token_hash, type: "magiclink" });
        if (error) throw new Error("This link has expired. Log in with your email instead.");
        if (live && j.plan) setPick(String(j.plan));
      } catch (x) {
        if (live) setErr(x instanceof Error ? x.message : "This link has expired.");
      } finally {
        if (live) setHandoff(false);
      }
    })();
    return () => { live = false; };
  }, [sp, sb]);

  // Back from Paystack without paying (Cancel on Paystack's page, or the back button): ask the server, never spin forever.
  useEffect(() => {
    if (!session) return;
    let ref = sp.get("cancelled") ?? "";
    try { ref = ref || (JSON.parse(sessionStorage.getItem(PENDING) ?? "null")?.ref ?? ""); } catch {}
    if (!REF.test(ref)) return;
    let live = true;
    const pressedCancel = Boolean(sp.get("cancelled"));
    queueMicrotask(() => { if (live) setLeft({ kind: "checking", ref }); });
    edge(session, { action: pressedCancel ? "cancel" : "check", reference: ref, reason: pressedCancel ? "pressed Cancel on Paystack" : undefined })
      .then((j) => {
        if (!live) return;
        if (j.status === "success" || j.status === "needs_review") {
          try { sessionStorage.removeItem(PENDING); } catch {}
          router.replace(`/pay/done?reference=${ref}`);
          return;
        }
        if (j.status === "pending" && !pressedCancel) { setLeft(null); setErr("Your last payment is not finished yet. If you paid by transfer, it can take a few minutes."); return; }
        try { sessionStorage.removeItem(PENDING); } catch {}
        setLeft({ kind: "cancelled", ref });
      })
      .catch(() => { if (live) setLeft(null); });
    if (pressedCancel) window.history.replaceState(null, "", window.location.pathname);
    return () => { live = false; };
  }, [session, sp, edge, router]);

  // The page can come back from the browser's memory (back button): stop the spinner.
  useEffect(() => {
    const show = (e: PageTransitionEvent) => { if (e.persisted) setBusy(false); };
    window.addEventListener("pageshow", show);
    return () => window.removeEventListener("pageshow", show);
  }, []);

  // Logged out after 15 minutes without activity (shared phones and cafés).
  useEffect(() => {
    if (!session) return;
    let t = setTimeout(() => sb.auth.signOut(), IDLE_MS);
    const poke = () => { clearTimeout(t); t = setTimeout(() => sb.auth.signOut(), IDLE_MS); };
    const evs = ["pointerdown", "keydown", "scroll"] as const;
    evs.forEach((e) => window.addEventListener(e, poke, { passive: true }));
    return () => { clearTimeout(t); evs.forEach((e) => window.removeEventListener(e, poke)); };
  }, [session, sb]);

  useEffect(() => {
    sb.auth.getSession().then(({ data }) => { setSession(data.session); setReady(true); });
    const { data } = sb.auth.onAuthStateChange((_e, s) => setSession(s));
    return () => data.subscription.unsubscribe();
  }, [sb]);

  useEffect(() => {
    if (!session) return;
    sb.from("plans").select("code, name, description, price_kobo, duration_days, ends_on").eq("is_active", true).order("sort")
      .then(({ data }) => {
        const list = (data ?? []) as Plan[];
        setPlans(list);
        if (list.length && !list.some((p) => p.code === pick)) setPick(list[0].code);
      });
  }, [session, sb, pick]);

  const loadQuote = useCallback(async (plan: string, code: string | null) => {
    const { data, error } = await sb.rpc("quote_price", { p_plan: plan, p_code: code ?? undefined });
    if (error) { setErr("Could not load the price. Check your internet and try again."); return false; }
    const r = data as unknown as Quote & { ok: boolean; error?: string };
    if (!r.ok) { setErr(QUOTE_ERRORS[r.error ?? ""] ?? "That code cannot be used."); return false; }
    setErr(null);
    setQuote(r);
    return true;
  }, [sb]);

  useEffect(() => {
    if (!session || !pick) return;
    let live = true;
    sb.rpc("quote_price", { p_plan: pick, p_code: applied ?? undefined }).then(({ data, error }) => {
      if (!live) return;
      const r = data as unknown as (Quote & { ok: boolean; error?: string }) | null;
      if (error || !r) setErr("Could not load the price. Check your internet and try again.");
      else if (!r.ok) setErr(QUOTE_ERRORS[r.error ?? ""] ?? "That code cannot be used.");
      else { setErr(null); setQuote(r); }
    });
    return () => { live = false; };
  }, [session, pick, applied, sb]);

  async function sendCode(e?: React.FormEvent) {
    e?.preventDefault();
    setBusy(true); setErr(null); setNote(null);
    try {
      const r = await fetch("/api/web/login-code", { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify({ email }) });
      const j = await r.json().catch(() => ({}));
      if (!r.ok) throw new Error(j.error ?? "Something went wrong. Try again.");
      setCodeLen(Number(j.codeLength ?? 6)); setNote(j.message ?? null);
    } catch (x) { setErr(x instanceof Error ? x.message : "No internet connection."); } finally { setBusy(false); }
  }

  async function verify(e?: React.FormEvent) {
    e?.preventDefault();
    setBusy(true); setErr(null);
    const { error } = await sb.auth.verifyOtp({ email: email.trim().toLowerCase(), token: otp.trim(), type: "recovery" });
    setBusy(false);
    if (error) setErr("That code is wrong or has expired. Check it, or ask for a new one.");
  }

  async function pay() {
    if (!session) return;
    setBusy(true); setErr(null); setLeft(null);
    try {
      const j = await edge(session, { action: "start", plan: pick, code: applied, source: "web", method: "page", ...backPages() });
      if (j.free) { router.push(`/pay/done?reference=${encodeURIComponent(String(j.reference))}`); return; }
      const url = String(j.url ?? "");
      // Only Paystack's own checkout page, never anywhere else.
      if (!/^https:\/\/checkout\.paystack\.com\//.test(url) || !REF.test(String(j.reference ?? ""))) throw new Error("Paystack did not open. Try again.");
      try { sessionStorage.setItem(PENDING, JSON.stringify({ ref: j.reference, at: Date.now() })); } catch {}
      window.location.assign(url);
    } catch (x) { setErr(x instanceof Error ? x.message : "No internet connection."); setBusy(false); }
  }

  const plan = plans.find((p) => p.code === pick);
  const step = !ready || handoff ? "load" : !session ? (codeLen ? "code" : "email") : "plan";
  const anim = { initial: still ? false : { opacity: 0, x: 24 }, animate: { opacity: 1, x: 0 }, exit: still ? undefined : { opacity: 0, x: -24 }, transition: { duration: 0.35, ease } } as const;

  return (
    <div className="w-full max-w-lg">
      <div className="mb-6 flex items-center justify-between">
        <Link href="/" className="flex items-center gap-2.5" aria-label="SolutionTee CBT home">
          {/* Real brand mark from /brand (never redrawn) */}
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img src="/brand/favicon.svg" alt="" className="size-9 rounded-xl" />
          <span className="text-[17px] font-bold">SolutionTee <span className="text-[#C88A12] dark:text-[#F2B233]">CBT</span></span>
        </Link>
        {session ? (
          <button type="button" onClick={() => sb.auth.signOut()} className="inline-flex items-center gap-1.5 rounded-xl px-3 py-2 text-sm font-medium text-muted-foreground hover:text-foreground">
            <SignOut size={16} /> Log out
          </button>
        ) : null}
      </div>
      <section className="overflow-hidden rounded-3xl border bg-card p-6 shadow-[var(--shadow-2,0_10px_30px_rgba(6,19,43,.08))] sm:p-8">
        <AnimatePresence mode="wait">
          {step === "load" ? (
            <motion.div key="load" className="grid h-48 place-items-center"><SpinnerGap size={28} className="animate-spin text-muted-foreground" /></motion.div>
          ) : step === "email" ? (
            <motion.form key="email" {...anim} onSubmit={sendCode}>
              <span className="grid size-12 place-items-center rounded-2xl bg-[#F2B233] text-[#0B1F44]"><Crown size={24} weight="fill" /></span>
              <h1 className="mt-5 text-2xl font-bold tracking-tight">Get SolutionTee Premium</h1>
              <p className="mt-2 text-[15px] leading-6 text-muted-foreground">Log in with the email you use in the app. We will send you a code. Premium shows in the app as soon as you pay.</p>
              <label htmlFor="email" className="mt-6 block text-sm font-bold">Email</label>
              <div className="mt-2 flex h-12 items-center gap-2 rounded-2xl border bg-background px-3 focus-within:ring-2 focus-within:ring-ring">
                <EnvelopeSimple size={20} className="text-muted-foreground" />
                <input id="email" type="email" required autoComplete="email" inputMode="email" value={email} onChange={(e) => setEmail(e.target.value)} placeholder="tolu@gmail.com" className="h-full min-w-0 flex-1 bg-transparent outline-none" />
              </div>
              {err ? <p className="mt-3 rounded-xl bg-error-soft px-3 py-2 text-sm text-on-error-soft">{err}</p> : null}
              <button type="submit" disabled={busy || !email} className="mt-5 inline-flex h-12 w-full items-center justify-center gap-2 rounded-2xl bg-[#0B1F44] font-bold text-white disabled:opacity-60 dark:bg-white dark:text-[#0B1F44]">
                {busy ? <SpinnerGap size={18} className="animate-spin" /> : null} Send my code <ArrowRight size={16} weight="bold" />
              </button>
              <p className="mt-4 text-center text-sm text-muted-foreground">No account yet? <a href="/download/apk" className="font-bold text-foreground underline-offset-4 hover:underline">Get the app</a> and create one first.</p>
            </motion.form>
          ) : step === "code" ? (
            <motion.form key="code" {...anim} onSubmit={verify}>
              <button type="button" onClick={() => { setCodeLen(null); setOtp(""); setErr(null); }} className="mb-4 inline-flex items-center gap-1 text-sm font-medium text-muted-foreground hover:text-foreground"><ArrowLeft size={14} /> Change email</button>
              <h1 className="text-2xl font-bold tracking-tight">Enter your code</h1>
              <p className="mt-2 text-[15px] leading-6 text-muted-foreground">{note ?? `We sent a code to ${email}.`} Check your inbox and spam folder.</p>
              <input autoFocus inputMode="numeric" autoComplete="one-time-code" maxLength={codeLen ?? 8} value={otp} onChange={(e) => setOtp(e.target.value.replace(/\D/g, ""))}
                aria-label="Code" placeholder={"•".repeat(codeLen ?? 6)} className="mt-6 h-16 w-full rounded-2xl border bg-background text-center text-3xl font-bold tracking-[0.4em] tabular-nums outline-none focus:ring-2 focus:ring-ring" />
              {err ? <p className="mt-3 rounded-xl bg-error-soft px-3 py-2 text-sm text-on-error-soft">{err}</p> : null}
              <button type="submit" disabled={busy || otp.length < (codeLen ?? 6)} className="mt-5 inline-flex h-12 w-full items-center justify-center gap-2 rounded-2xl bg-[#0B1F44] font-bold text-white disabled:opacity-60 dark:bg-white dark:text-[#0B1F44]">
                {busy ? <SpinnerGap size={18} className="animate-spin" /> : null} Log in
              </button>
              <button type="button" onClick={() => sendCode()} disabled={busy} className="mt-3 w-full text-sm font-bold text-muted-foreground hover:text-foreground">Send a new code</button>
            </motion.form>
          ) : (
            <motion.div key="plan" {...anim}>
              <p className="text-sm text-muted-foreground">Logged in as <b className="text-foreground">{session?.user.email}</b></p>
              <h1 className="mt-1 text-2xl font-bold tracking-tight">Choose your plan</h1>
              <AnimatePresence>
                {left ? (
                  <motion.div initial={{ opacity: 0, height: 0 }} animate={{ opacity: 1, height: "auto" }} exit={{ opacity: 0, height: 0 }} className="overflow-hidden">
                    <div className={`mt-4 flex items-start gap-3 rounded-2xl p-4 text-sm ${left.kind === "cancelled" ? "bg-warning-soft text-on-warning-soft" : "bg-info-soft text-on-info-soft"}`}>
                      {left.kind === "checking" ? <SpinnerGap size={20} className="mt-0.5 shrink-0 animate-spin" /> : <XCircle size={20} weight="fill" className="mt-0.5 shrink-0" />}
                      <div>
                        <b className="block">{left.kind === "checking" ? "Checking your last payment…" : "Payment cancelled"}</b>
                        {left.kind === "cancelled" ? <span>Nothing was charged. Choose a plan and try again, or pick another way to pay on Paystack.</span> : null}
                      </div>
                    </div>
                  </motion.div>
                ) : null}
              </AnimatePresence>
              <div className="mt-5 space-y-3" role="radiogroup" aria-label="Plans">
                {plans.map((p) => {
                  const on = p.code === pick;
                  return (
                    <button key={p.code} type="button" role="radio" aria-checked={on} onClick={() => { setPick(p.code); setApplied(null); setDiscount(""); }}
                      className={`flex w-full items-center gap-4 rounded-2xl border-2 p-4 text-left transition-colors ${on ? "border-[#2563B3] bg-[#EEF4FC] dark:bg-[#16284A]" : "border-border hover:border-[#2563B3]/50"}`}>
                      <span className={`grid size-6 shrink-0 place-items-center rounded-full border-2 ${on ? "border-[#2563B3] bg-[#2563B3] text-white" : "border-border"}`}>{on ? <CheckCircle size={16} weight="fill" /> : null}</span>
                      <span className="grow"><b className="block">{p.name}</b><small className="text-muted-foreground">{p.duration_days ? `${p.duration_days} days` : p.ends_on ? `Until ${day(p.ends_on)}` : ""}</small></span>
                      <b className="tabular-nums">{ng(p.price_kobo)}</b>
                    </button>
                  );
                })}
              </div>
              <div className="mt-4 flex gap-2">
                <div className="flex h-11 min-w-0 flex-1 items-center gap-2 rounded-xl border bg-background px-3">
                  <Ticket size={18} className="text-muted-foreground" />
                  <input value={discount} onChange={(e) => setDiscount(e.target.value.toUpperCase())} placeholder="Discount code (optional)" aria-label="Discount code" className="h-full min-w-0 flex-1 bg-transparent text-sm uppercase outline-none" />
                </div>
                <button type="button" disabled={!discount.trim()} onClick={async () => { if (await loadQuote(pick, discount.trim())) setApplied(discount.trim()); }} className="h-11 rounded-xl border px-4 text-sm font-bold disabled:opacity-50">Apply</button>
              </div>
              {quote && plan ? (
                <div className="mt-5 space-y-2 rounded-2xl bg-[#F4F6FA] p-4 text-sm dark:bg-white/5">
                  <div className="flex justify-between"><span className="text-muted-foreground">{plan.name}</span><span className="tabular-nums">{ng(quote.list_kobo)}</span></div>
                  {quote.discount_kobo > 0 ? <div className="flex justify-between text-[#15803D]"><span>{quote.code} · {quote.label}</span><span className="tabular-nums">−{ng(quote.discount_kobo)}</span></div> : null}
                  {(quote.fee_kobo ?? 0) > 0 ? <div className="flex justify-between"><span className="text-muted-foreground">Payment processing fee</span><span className="tabular-nums">+{ng(quote.fee_kobo ?? 0)}</span></div> : null}
                  <div className="flex justify-between border-t pt-2 text-base font-bold"><span>Total</span><span className="tabular-nums">{ng(quote.amount_kobo)}</span></div>
                  {quote.period_end ? <p className="text-xs text-muted-foreground">Premium until {day(quote.period_end)}. Pay once, no auto-renew.</p> : null}
                </div>
              ) : null}
              {err ? <p className="mt-3 rounded-xl bg-error-soft px-3 py-2 text-sm text-on-error-soft">{err}</p> : null}
              <button type="button" onClick={pay} disabled={busy || !quote} className="mt-5 inline-flex h-14 w-full items-center justify-center gap-2 rounded-2xl bg-[#F2B233] text-[17px] font-bold text-[#0B1F44] transition-transform hover:-translate-y-0.5 disabled:opacity-60">
                {busy ? <SpinnerGap size={20} className="animate-spin" /> : <LockSimple size={20} weight="fill" />} Pay {quote ? ng(quote.amount_kobo) : ""} securely
              </button>
              <p className="mt-3 flex items-center justify-center gap-1.5 text-center text-xs text-muted-foreground"><ShieldCheck size={16} weight="fill" className="text-[#16A34A]" /> Paystack · card, bank transfer, USSD, OPay and other bank apps</p>
            </motion.div>
          )}
        </AnimatePresence>
      </section>
      <p className="mt-6 text-center text-xs leading-5 text-muted-foreground">SolutionTee CBT is an independent exam-practice platform and is not affiliated with or endorsed by JAMB, WAEC or NECO.</p>
    </div>
  );
}
