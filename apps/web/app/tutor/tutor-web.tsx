"use client";
import { useCallback, useEffect, useMemo, useState } from "react";
import type { Session } from "@supabase/supabase-js";
import { motion, useReducedMotion } from "motion/react";
import { ChalkboardTeacher, CheckCircle, Clock, DeviceMobile, SignOut, Sparkle, SpinnerGap } from "@phosphor-icons/react";
import { createClient } from "@/lib/supabase/client";

type Plan = { id: string; name: string; description: string | null; price_kobo: number; days: number; sessions: number | null };
type Req = { id: string; status: string; goals: string; custom_note: string | null; custom_price_kobo: number | null; custom_days: number | null };
type Overview = { request: Req | null; plans: Plan[]; subscription: { plan: string; ends_at: string } | null; tutor: { name: string; subjects: string | null } | null };

const ngn = (k: number) => `₦${Math.round(k / 100).toLocaleString("en-NG")}`;
const LEVELS = [["jamb", "JAMB"], ["waec", "WAEC"], ["neco", "NECO"], ["post_utme", "Post-UTME"], ["other", "Other"]] as const;

export function TutorWeb() {
  const sb = useMemo(() => createClient(), []);
  const rm = useReducedMotion();
  const [session, setSession] = useState<Session | null>(null);
  const [ready, setReady] = useState(false);
  const [email, setEmail] = useState("");
  const [codeLen, setCodeLen] = useState<number | null>(null);
  const [otp, setOtp] = useState("");
  const [o, setO] = useState<Overview | null>(null);
  const [subjects, setSubjects] = useState<{ id: number; name: string }[]>([]);
  const [form, setForm] = useState({ level: "jamb", subject: "", goals: "", times: "" });
  const [custom, setCustom] = useState("");
  const [busy, setBusy] = useState<string | null>(null);
  const [msg, setMsg] = useState<{ ok: boolean; text: string } | null>(null);

  useEffect(() => {
    // From the app (D-115 one-time code): log straight in, never mixing two accounts.
    const code = new URL(window.location.href).searchParams.get("h");
    if (code) {
      const url = new URL(window.location.href);
      url.searchParams.delete("h");
      window.history.replaceState(null, "", url.toString());
      void (async () => {
        try {
          const r = await fetch("/api/web/handoff/redeem", { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify({ code }) });
          const j = await r.json().catch(() => ({}));
          if (r.ok && j.token_hash) {
            await sb.auth.signOut({ scope: "local" });
            await sb.auth.verifyOtp({ token_hash: j.token_hash, type: "magiclink" });
          }
        } catch {}
        const { data } = await sb.auth.getSession();
        setSession(data.session); setReady(true);
      })();
    } else {
      sb.auth.getSession().then(({ data }) => { setSession(data.session); setReady(true); });
    }
    const { data } = sb.auth.onAuthStateChange((_e, s) => setSession(s));
    return () => data.subscription.unsubscribe();
  }, [sb]);
  const load = useCallback(async () => {
    const [ov, sub] = await Promise.all([sb.rpc("tutor_overview"), sb.from("subjects").select("id, name").order("sort")]);
    setO((ov.data ?? null) as unknown as Overview);
    setSubjects((sub.data ?? []) as { id: number; name: string }[]);
  }, [sb]);
  useEffect(() => { if (session) queueMicrotask(() => { void load(); }); }, [session, load]);

  async function sendCode(e: React.FormEvent) {
    e.preventDefault(); setBusy("code"); setMsg(null);
    try {
      const r = await fetch("/api/web/login-code", { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify({ email }) });
      const j = await r.json().catch(() => ({}));
      if (!r.ok) throw new Error(j.error ?? "Something went wrong. Try again.");
      setCodeLen(Number(j.codeLength ?? 6));
    } catch (x) { setMsg({ ok: false, text: x instanceof Error ? x.message : "No internet connection." }); } finally { setBusy(null); }
  }
  async function verify(e: React.FormEvent) {
    e.preventDefault(); setBusy("verify"); setMsg(null);
    const { error } = await sb.auth.verifyOtp({ email: email.trim().toLowerCase(), token: otp.trim(), type: "recovery" });
    setBusy(null);
    if (error) setMsg({ ok: false, text: "That code is wrong or has expired. Check it, or ask for a new one." });
  }
  async function request(e: React.FormEvent) {
    e.preventDefault(); setBusy("req"); setMsg(null);
    const { data } = await sb.rpc("tutor_request_create", { p_subject: Number(form.subject) || (null as unknown as number), p_level: form.level, p_goals: form.goals, p_times: form.times });
    const d = (data ?? {}) as { ok?: boolean; error?: string };
    setBusy(null);
    if (!d.ok) return setMsg({ ok: false, text: d.error === "too_many" ? "You have sent a few requests today. Try again tomorrow." : d.error === "goals" ? "Tell us a little about what you need." : "Could not send. Try again." });
    await load();
  }
  async function askCustom() {
    if (!o?.request) return;
    setBusy("custom"); setMsg(null);
    const { data } = await sb.rpc("tutor_custom_request", { p_request: o.request.id, p_note: custom });
    setBusy(null);
    if (!(data as { ok?: boolean })?.ok) return setMsg({ ok: false, text: "Tell us a little more about what you need." });
    setCustom(""); setMsg({ ok: true, text: "Sent. We will send you a price, usually within a day. You get a notification in the app." });
    await load();
  }
  async function pay(ref: string) {
    if (!session) return;
    setBusy(ref); setMsg(null);
    try {
      const origin = window.location.origin;
      const back = /^https:\/\/(cbt|admin)\.solutiontee\.com$/.test(origin) ? { callback: `${origin}/pay/done`, cancel: `${origin}/tutor` } : {};
      const r = await fetch(`${process.env.NEXT_PUBLIC_SUPABASE_URL}/functions/v1/paystack`, {
        method: "POST",
        headers: { "content-type": "application/json", authorization: `Bearer ${session.access_token}`, apikey: process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY! },
        body: JSON.stringify({ action: "start_item", kind: "item", ref, source: "web", method: "page", ...back }),
      });
      const j = await r.json().catch(() => ({}));
      if (!r.ok) throw new Error(j.error ?? "Paystack is not answering. Try again.");
      const url = String(j.url ?? "");
      if (!/^https:\/\/checkout\.paystack\.com\//.test(url)) throw new Error("Paystack did not open. Try again.");
      try { sessionStorage.setItem("st-after-pay", "/tutor"); } catch {}
      window.location.assign(url);
    } catch (x) { setMsg({ ok: false, text: x instanceof Error ? x.message : "Try again." }); setBusy(null); }
  }

  const box = "rounded-3xl border bg-card p-5 shadow-[var(--shadow-1)] sm:p-6";
  const btn = "inline-flex h-12 items-center justify-center gap-2 rounded-2xl px-5 text-[15px] font-bold disabled:opacity-60";
  const input = "h-12 w-full rounded-2xl border border-input bg-card px-4 text-[15px]";
  const rise = (d: number) => (rm ? {} : { initial: { opacity: 0, y: 12 }, animate: { opacity: 1, y: 0 }, transition: { duration: 0.35, delay: d } });

  if (!ready) return <div className="h-64 animate-pulse rounded-3xl bg-card" />;
  if (!session) {
    return (
      <motion.div {...rise(0)} className={`${box} mx-auto max-w-md`}>
        <span className="grid size-14 place-items-center rounded-2xl bg-[#F2B233] text-[#0B1F44]"><ChalkboardTeacher size={30} weight="fill" /></span>
        <h1 className="mt-4 text-2xl font-bold">Get a real tutor</h1>
        <p className="mt-1 text-muted-foreground">Log in with the email you use in the SolutionTee app. We send you a code.</p>
        {codeLen === null ? (
          <form onSubmit={sendCode} className="mt-5 space-y-3">
            <input type="email" required autoComplete="email" placeholder="you@example.com" className={input} value={email} onChange={(e) => setEmail(e.target.value.trim())} />
            <button disabled={busy !== null || !email} className={`${btn} w-full bg-[#0B1F44] text-white dark:bg-[#F2B233] dark:text-[#0B1F44]`}>{busy ? <SpinnerGap className="animate-spin" size={18} /> : null} Send me a code</button>
          </form>
        ) : (
          <form onSubmit={verify} className="mt-5 space-y-3">
            <p className="text-sm text-muted-foreground">We sent a {codeLen}-digit code to {email}. Check your spam folder too.</p>
            <input inputMode="numeric" autoComplete="one-time-code" maxLength={codeLen} required className={`${input} tracking-[.3em]`} value={otp} onChange={(e) => setOtp(e.target.value.replace(/\D/g, ""))} />
            <button disabled={busy !== null || otp.length !== codeLen} className={`${btn} w-full bg-[#0B1F44] text-white dark:bg-[#F2B233] dark:text-[#0B1F44]`}>{busy ? <SpinnerGap className="animate-spin" size={18} /> : null} Log in</button>
            <button type="button" className="w-full text-sm font-bold text-link" onClick={() => { setCodeLen(null); setOtp(""); }}>Use another email</button>
          </form>
        )}
        {msg ? <p role="alert" className={`mt-3 text-sm font-bold ${msg.ok ? "text-success" : "text-error"}`}>{msg.text}</p> : null}
      </motion.div>
    );
  }
  if (!o) return <div className="h-64 animate-pulse rounded-3xl bg-card" />;
  const r = o.request;
  const choosing = !r || ["new", "quoted", "ended", "closed"].includes(r.status);

  return (
    <div className="space-y-5">
      <div className="flex items-center gap-3">
        <h1 className="mr-auto text-3xl font-bold tracking-tight">Your tutor</h1>
        <button className="inline-flex items-center gap-1 text-sm font-bold text-muted-foreground" onClick={() => sb.auth.signOut({ scope: "local" })}><SignOut size={16} /> Log out</button>
      </div>
      {msg ? <p role="status" className={`rounded-2xl px-4 py-3 text-sm font-bold ${msg.ok ? "bg-success-soft text-on-success-soft" : "bg-error-soft text-on-error-soft"}`}>{msg.text}</p> : null}

      {r && r.status === "paid" ? (
        <motion.div {...rise(0)} className={`${box} text-center`}>
          <Clock size={48} weight="duotone" className="mx-auto text-[#2563B3]" />
          <h2 className="mt-3 text-xl font-bold">Payment received</h2>
          <p className="mt-1 text-muted-foreground">A tutor will be assigned to you within 24 hours. We will notify you in the app; then you can chat with your tutor there.</p>
        </motion.div>
      ) : null}
      {r && r.status === "matched" && o.tutor ? (
        <motion.div {...rise(0)} className={box}>
          <p className="flex items-center gap-1.5 text-sm font-bold text-success"><CheckCircle size={18} weight="fill" /> Your tutor is ready</p>
          <h2 className="mt-1 text-xl font-bold">{o.tutor.name}</h2>
          {o.tutor.subjects ? <p className="text-muted-foreground">{o.tutor.subjects}</p> : null}
          {o.subscription ? <p className="mt-2 text-sm">Plan: <b>{o.subscription.plan}</b> until {new Date(o.subscription.ends_at).toLocaleDateString("en-NG", { day: "numeric", month: "long" })}</p> : null}
          <p className="mt-3 flex items-center gap-2 rounded-2xl bg-muted px-4 py-3 text-sm"><DeviceMobile size={20} /> Chat with your tutor in the SolutionTee app: Study → My tutor.</p>
        </motion.div>
      ) : null}

      {!r || r.status === "closed" ? (
        <motion.form {...rise(0)} onSubmit={request} className={`${box} space-y-4`}>
          <div><h2 className="text-xl font-bold">What do you need help with?</h2><p className="text-sm text-muted-foreground">Then choose a plan. A tutor is assigned within 24 hours of payment.</p></div>
          <div className="flex flex-wrap gap-2">{LEVELS.map(([k, l]) => (
            <button key={k} type="button" onClick={() => setForm({ ...form, level: k })} className={`rounded-full border px-4 py-2 text-sm font-bold ${form.level === k ? "border-[#0B1F44] bg-[#0B1F44] text-white" : ""}`}>{l}</button>
          ))}</div>
          <select aria-label="Subject" className={input} value={form.subject} onChange={(e) => setForm({ ...form, subject: e.target.value })}>
            <option value="">Several subjects / not sure</option>{subjects.map((s) => <option key={s.id} value={s.id}>{s.name}</option>)}
          </select>
          <textarea required minLength={5} maxLength={1000} rows={3} placeholder="For example: I want to understand graphs in Physics and score 250+ in JAMB." className={`${input} h-auto py-3`} value={form.goals} onChange={(e) => setForm({ ...form, goals: e.target.value })} />
          <input maxLength={300} placeholder="When are you free? (optional)" className={input} value={form.times} onChange={(e) => setForm({ ...form, times: e.target.value })} />
          <button disabled={busy !== null} className={`${btn} w-full bg-[#F2B233] text-[#0B1F44]`}>{busy === "req" ? <SpinnerGap className="animate-spin" size={18} /> : null} Continue to plans</button>
        </motion.form>
      ) : null}

      {r && choosing && r.status !== "closed" ? (
        <section className="space-y-3">
          <h2 className="text-xl font-bold">{r.status === "ended" ? "Renew your tutor plan" : "Choose a plan"}</h2>
          {r.custom_price_kobo ? (
            <motion.div {...rise(0)} className={`${box} border-[#F2B233]`}>
              <p className="flex items-center gap-1.5 text-sm font-bold text-[#2563B3]"><Sparkle size={16} weight="fill" /> Your custom plan</p>
              <div className="mt-1 flex items-baseline justify-between gap-3"><b className="text-lg">{r.custom_days} days</b><b className="text-2xl tabular-nums">{ngn(r.custom_price_kobo)}</b></div>
              {r.custom_note ? <p className="mt-1 text-sm text-muted-foreground">{r.custom_note}</p> : null}
              <button disabled={busy !== null} onClick={() => pay(r.id)} className={`${btn} mt-4 w-full bg-[#F2B233] text-[#0B1F44]`}>{busy === r.id ? <SpinnerGap className="animate-spin" size={18} /> : null} Pay {ngn(r.custom_price_kobo)}</button>
            </motion.div>
          ) : null}
          {o.plans.map((p, i) => (
            <motion.div key={p.id} {...rise(0.05 * i)} className={box}>
              <div className="flex items-baseline justify-between gap-3"><b className="text-lg">{p.name}</b><b className="text-2xl tabular-nums">{ngn(p.price_kobo)}</b></div>
              <p className="text-sm text-muted-foreground">{p.days} days{p.sessions ? ` · ${p.sessions} lessons` : ""}</p>
              {p.description ? <p className="mt-1 text-sm">{p.description}</p> : null}
              <button disabled={busy !== null} onClick={() => pay(p.id)} className={`${btn} mt-4 w-full bg-[#0B1F44] text-white dark:bg-[#F2B233] dark:text-[#0B1F44]`}>{busy === p.id ? <SpinnerGap className="animate-spin" size={18} /> : null} Choose and pay</button>
            </motion.div>
          ))}
          <div className={box}>
            <b className="text-lg">Custom plan</b>
            <p className="text-sm text-muted-foreground">Need something different (more lessons, a weekend class, a group)? Tell us and we send you a price.</p>
            <textarea rows={2} maxLength={1000} className={`${input} mt-3 h-auto py-3`} placeholder="I need weekend classes for 2 months" value={custom} onChange={(e) => setCustom(e.target.value)} />
            <button disabled={busy !== null || custom.trim().length < 5} onClick={askCustom} className={`${btn} mt-3 w-full border`}>{busy === "custom" ? <SpinnerGap className="animate-spin" size={18} /> : null} Ask for a price</button>
          </div>
          <p className="text-center text-xs text-muted-foreground">Pay safely with Paystack: card, bank transfer, USSD or your bank app.</p>
        </section>
      ) : null}
    </div>
  );
}
