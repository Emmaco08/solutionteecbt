"use client";
import { useEffect, useMemo, useState } from "react";
import Link from "next/link";
import { AnimatePresence, motion, useReducedMotion } from "motion/react";
import type { Session } from "@supabase/supabase-js";
import { ArrowRight, CheckCircle, EnvelopeSimple, LockKey, ShieldCheck, SpinnerGap } from "@phosphor-icons/react";
import { createClient } from "@/lib/supabase/client";

const ease = [0.22, 1, 0.36, 1] as const;

function parts(ms: number) {
  const s = Math.max(0, Math.floor(ms / 1000));
  return { d: Math.floor(s / 86400), h: Math.floor((s % 86400) / 3600), m: Math.floor((s % 3600) / 60), s: s % 60 };
}

/** A live countdown to [to] (Lagos or not, it is absolute time). Numbers slide when they change. */
export function Countdown({ to, endsAt, size = "md", dark = false }: { to: string; endsAt?: string; size?: "sm" | "md" | "lg"; dark?: boolean }) {
  const [now, setNow] = useState<number | null>(null);
  useEffect(() => {
    const tick = () => setNow(new Date().getTime());
    tick();
    const t = setInterval(tick, 1000);
    return () => clearInterval(t);
  }, []);
  const still = useReducedMotion();
  if (now === null) return <span className="opacity-0">00:00</span>;
  const start = new Date(to).getTime(), end = endsAt ? new Date(endsAt).getTime() : start;
  const live = now >= start && now < end;
  const p = parts((live ? end : start) - now);
  const units: [number, string][] = p.d > 0 ? [[p.d, "days"], [p.h, "hrs"], [p.m, "min"]] : [[p.h, "hrs"], [p.m, "min"], [p.s, "sec"]];
  const box = size === "lg" ? "min-w-16 px-3 py-2 text-3xl" : size === "sm" ? "min-w-9 px-1.5 py-1 text-base" : "min-w-12 px-2 py-1.5 text-2xl";
  const tone = dark ? "bg-white/10 text-white ring-1 ring-white/15" : "bg-[#0B1F44] text-white";
  return (
    <span className="inline-flex flex-col gap-1.5">
      {live ? <span className={`inline-flex items-center gap-1.5 text-xs font-bold ${dark ? "text-[#FF8A8E]" : "text-[#E5484D]"}`}><span className="size-2 animate-pulse rounded-full bg-current" /> Live now · ends in</span> : null}
      <span className="inline-flex items-end gap-1.5">
        {units.map(([n, u], i) => (
          <span key={u} className="inline-flex items-end gap-1.5">
            {i > 0 ? <span className={`pb-3 font-bold ${dark ? "text-[#F2B233]" : "text-[#F2B233]"}`}>:</span> : null}
            <span className="flex flex-col items-center">
              <span className={`relative overflow-hidden rounded-xl text-center font-bold tabular-nums ${box} ${tone}`}>
                <AnimatePresence mode="popLayout" initial={false}>
                  <motion.span key={n} className="block" initial={still ? false : { y: "70%", opacity: 0 }} animate={{ y: 0, opacity: 1 }} exit={{ y: "-70%", opacity: 0 }} transition={{ duration: 0.3, ease }}>
                    {String(n).padStart(2, "0")}
                  </motion.span>
                </AnimatePresence>
              </span>
              <span className={`mt-1 text-[10px] font-bold uppercase tracking-wider ${dark ? "text-[#AFC0DD]" : "text-muted-foreground"}`}>{u}</span>
            </span>
          </span>
        ))}
      </span>
    </span>
  );
}

const ngn = (kobo: number) => `₦${Math.round(kobo / 100).toLocaleString("en-NG")}`;

/**
 * Pay for a class programme on the website: sign in with an email code (the same account as the app), then Paystack.
 * After paying the student lands on /pay/done and then My classes. Already in? It says so.
 */
export function BuyBox({ programId, price, compare, buyable, seatsLeft }: { programId: string; price: number; compare: number | null; buyable: boolean; seatsLeft: number | null }) {
  const sb = useMemo(() => createClient(), []);
  const [session, setSession] = useState<Session | null>(null);
  const [ready, setReady] = useState(false);
  const [enrolled, setEnrolled] = useState(false);
  const [step, setStep] = useState<"idle" | "email" | "code">("idle");
  const [email, setEmail] = useState("");
  const [code, setCode] = useState("");
  const [codeLen, setCodeLen] = useState(6);
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState<string | null>(null);
  const still = useReducedMotion();

  useEffect(() => {
    sb.auth.getSession().then(({ data }) => { setSession(data.session); setReady(true); });
    const { data } = sb.auth.onAuthStateChange((_e, s) => setSession(s));
    return () => data.subscription.unsubscribe();
  }, [sb]);
  useEffect(() => {
    if (!session) return;
    void sb.from("class_enrollments").select("program_id").eq("program_id", programId).maybeSingle().then(({ data }) => setEnrolled(Boolean(data)));
  }, [session, sb, programId]);

  async function pay(s: Session) {
    setBusy(true); setErr(null);
    try {
      const o = window.location.origin;
      const back = /^https:\/\/(cbt|admin)\.solutiontee\.com$/.test(o) ? { callback: `${o}/pay/done`, cancel: window.location.href } : {};
      const r = await fetch(`${process.env.NEXT_PUBLIC_SUPABASE_URL}/functions/v1/paystack`, {
        method: "POST",
        headers: { "content-type": "application/json", authorization: `Bearer ${s.access_token}`, apikey: process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY! },
        body: JSON.stringify({ action: "start_item", kind: "item", ref: programId, source: "web", method: "page", ...back }),
      });
      const j = await r.json().catch(() => ({}));
      if (j.error === "bought") { setEnrolled(true); return; }
      if (!r.ok) throw new Error(j.error === "not_for_sale" ? "This class is not taking new students right now." : (j.error ?? "Paystack is not answering. Try again."));
      const url = String(j.url ?? "");
      if (!/^https:\/\/checkout\.paystack\.com\//.test(url)) throw new Error("Paystack did not open. Try again.");
      try { sessionStorage.setItem("st-after-pay", "/classes/me"); } catch {}
      window.location.assign(url);
    } catch (e) { setErr(e instanceof Error ? e.message : "Try again."); setBusy(false); }
  }

  async function sendCode(e: React.FormEvent) {
    e.preventDefault();
    setBusy(true); setErr(null);
    try {
      const r = await fetch("/api/web/login-code", { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify({ email }) });
      const j = await r.json().catch(() => ({}));
      if (!r.ok) throw new Error(j.error ?? "Something went wrong. Try again.");
      setCodeLen(Number(j.codeLength ?? 6));
      setStep("code");
    } catch (x) { setErr(x instanceof Error ? x.message : "No internet connection."); } finally { setBusy(false); }
  }
  async function verify(e: React.FormEvent) {
    e.preventDefault();
    setBusy(true); setErr(null);
    const { data, error } = await sb.auth.verifyOtp({ email: email.trim().toLowerCase(), token: code.trim(), type: "recovery" });
    if (error || !data.session) { setBusy(false); setErr("That code is wrong or has expired. Check it, or ask for a new one."); return; }
    await pay(data.session);
  }

  const soldOut = seatsLeft === 0;
  return (
    <div className="rounded-3xl border bg-card p-5 shadow-[0_20px_60px_-30px_rgba(11,31,68,.45)]">
      <div className="flex items-end gap-3">
        <span className="text-4xl font-bold tracking-tight">{ngn(price)}</span>
        {compare && compare > price ? <s className="pb-1 text-lg text-muted-foreground">{ngn(compare)}</s> : null}
        {compare && compare > price ? <span className="mb-1.5 rounded-full bg-[#E9F8EF] px-2 py-0.5 text-xs font-bold text-[#14874F]">Save {ngn(compare - price)}</span> : null}
      </div>
      <p className="mt-1 text-sm text-muted-foreground">One payment. Join every session of this class, live, plus the recordings.</p>
      {seatsLeft !== null && seatsLeft > 0 && seatsLeft <= 30 ? <p className="mt-2 text-sm font-bold text-[#B8620A]">Only {seatsLeft} seats left</p> : null}

      <div className="mt-4">
        <AnimatePresence mode="wait" initial={false}>
          {!ready ? (
            <motion.div key="load" className="h-12 animate-pulse rounded-2xl bg-muted" />
          ) : enrolled ? (
            <motion.div key="in" initial={still ? false : { opacity: 0, y: 8 }} animate={{ opacity: 1, y: 0 }} className="space-y-3">
              <p className="flex items-center gap-2 rounded-2xl bg-[#E9F8EF] p-3 text-sm font-bold text-[#14874F]"><CheckCircle size={20} weight="fill" /> You are in this class.</p>
              <Link href="/classes/me" className="flex h-12 items-center justify-center gap-2 rounded-2xl bg-[#0B1F44] font-bold text-white">Open My classes <ArrowRight size={18} weight="bold" /></Link>
            </motion.div>
          ) : soldOut || !buyable ? (
            <motion.p key="closed" className="rounded-2xl bg-muted p-3 text-center text-sm font-bold text-muted-foreground">{soldOut ? "This class is full." : "This class is not taking new students right now."}</motion.p>
          ) : session ? (
            <motion.button key="pay" initial={still ? false : { opacity: 0, y: 8 }} animate={{ opacity: 1, y: 0 }} onClick={() => void pay(session)} disabled={busy}
              className="group flex h-14 w-full items-center justify-center gap-2 rounded-2xl bg-[#F2B233] text-lg font-bold text-[#0B1F44] shadow-[0_10px_30px_-12px_rgba(242,178,51,.8)] transition active:scale-[.98] disabled:opacity-70">
              {busy ? <SpinnerGap size={20} className="animate-spin" /> : <LockKey size={20} weight="fill" />} Pay {ngn(price)} securely
              {!busy ? <ArrowRight size={18} weight="bold" className="transition group-hover:translate-x-1" /> : null}
            </motion.button>
          ) : step === "idle" ? (
            <motion.button key="start" initial={still ? false : { opacity: 0, y: 8 }} animate={{ opacity: 1, y: 0 }} onClick={() => setStep("email")}
              className="group flex h-14 w-full items-center justify-center gap-2 rounded-2xl bg-[#F2B233] text-lg font-bold text-[#0B1F44] shadow-[0_10px_30px_-12px_rgba(242,178,51,.8)] transition active:scale-[.98]">
              Join this class <ArrowRight size={18} weight="bold" className="transition group-hover:translate-x-1" />
            </motion.button>
          ) : step === "email" ? (
            <motion.form key="email" onSubmit={sendCode} initial={still ? false : { opacity: 0, y: 8 }} animate={{ opacity: 1, y: 0 }} className="space-y-2">
              <label htmlFor="buy-email" className="text-sm font-bold">Your email</label>
              <div className="flex items-center gap-2 rounded-2xl border bg-background px-3 focus-within:ring-2 focus-within:ring-[#2563B3]">
                <EnvelopeSimple size={18} className="text-muted-foreground" />
                <input id="buy-email" type="email" required autoComplete="email" value={email} onChange={(e) => setEmail(e.target.value)} placeholder="you@example.com" className="h-12 w-full bg-transparent outline-none" />
              </div>
              <p className="text-xs text-muted-foreground">Use the email of your SolutionTee app account. New? We create your account, free.</p>
              <button disabled={busy} className="flex h-12 w-full items-center justify-center gap-2 rounded-2xl bg-[#0B1F44] font-bold text-white disabled:opacity-70">
                {busy ? <SpinnerGap size={18} className="animate-spin" /> : null} Send me a code
              </button>
            </motion.form>
          ) : (
            <motion.form key="code" onSubmit={verify} initial={still ? false : { opacity: 0, y: 8 }} animate={{ opacity: 1, y: 0 }} className="space-y-2">
              <label htmlFor="buy-code" className="text-sm font-bold">Enter the {codeLen}-digit code we sent to {email}</label>
              <input id="buy-code" inputMode="numeric" autoComplete="one-time-code" maxLength={codeLen} value={code} onChange={(e) => setCode(e.target.value.replace(/\D/g, ""))}
                className="h-14 w-full rounded-2xl border bg-background text-center text-2xl font-bold tracking-[.5em] outline-none focus:ring-2 focus:ring-[#2563B3]" />
              <button disabled={busy || code.length < codeLen} className="flex h-12 w-full items-center justify-center gap-2 rounded-2xl bg-[#F2B233] font-bold text-[#0B1F44] disabled:opacity-60">
                {busy ? <SpinnerGap size={18} className="animate-spin" /> : <LockKey size={18} weight="fill" />} Continue to payment
              </button>
              <button type="button" className="w-full text-sm text-muted-foreground underline" onClick={() => { setStep("email"); setCode(""); }}>Use another email</button>
            </motion.form>
          )}
        </AnimatePresence>
        {err ? <p className="mt-2 text-sm font-semibold text-[#C2333A]">{err}</p> : null}
      </div>

      <ul className="mt-5 space-y-2 border-t pt-4 text-sm">
        <li className="flex items-center gap-2"><ShieldCheck size={18} weight="fill" className="text-[#14874F]" /> Secure payment by Paystack (card, bank transfer, USSD)</li>
        <li className="flex items-center gap-2"><CheckCircle size={18} weight="fill" className="text-[#14874F]" /> Receipt sent to your email</li>
        <li className="flex items-center gap-2"><CheckCircle size={18} weight="fill" className="text-[#14874F]" /> Join from the SolutionTee app or this website</li>
      </ul>
    </div>
  );
}
