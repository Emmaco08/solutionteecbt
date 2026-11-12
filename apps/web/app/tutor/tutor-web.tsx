"use client";
import { useCallback, useEffect, useMemo, useState } from "react";
import type { Session } from "@supabase/supabase-js";
import { AnimatePresence, motion, useReducedMotion } from "motion/react";
import { ArrowRight, Check, CheckCircle, DeviceMobile, LockSimple, ShieldCheck, SignOut, Sparkle, SpinnerGap } from "@phosphor-icons/react";
import { createClient } from "@/lib/supabase/client";
import { cn } from "@/lib/utils";

type Plan = { id: string; name: string; description: string | null; price_kobo: number; days: number; sessions: number | null };
type Req = { id: string; status: string; goals: string; level: string; times: string | null; subjects: string | null; custom_note: string | null; custom_price_kobo: number | null; custom_days: number | null };
type Overview = { request: Req | null; plans: Plan[]; subscription: { plan: string; ends_at: string } | null; tutor: { name: string; subjects: string | null } | null };

const ngn = (k: number) => `₦${Math.round(k / 100).toLocaleString("en-NG")}`;
const LEVELS = [["jamb", "JAMB"], ["waec", "WAEC"], ["neco", "NECO"], ["post_utme", "Post-UTME"], ["other", "Other"]] as const;
const TIMES = ["Mornings", "Afternoons", "Evenings", "Weekends"];
const features = (d: string | null) => (d ?? "").split(/\n|•|·|;/).map((l) => l.replace(/^\s*[-*]\s*/, "").trim()).filter(Boolean);
const ease = [0.22, 1, 0.36, 1] as const;

/** cbt.solutiontee.com/tutor, v3 (D-152, D-153): request a tutor, choose a plan or a custom price, pay with Paystack. */
export function TutorWeb() {
  const sb = useMemo(() => createClient(), []);
  const rm = useReducedMotion();
  const [session, setSession] = useState<Session | null>(null);
  const [ready, setReady] = useState(false);
  const [fromApp, setFromApp] = useState(false);
  const [email, setEmail] = useState("");
  const [codeLen, setCodeLen] = useState<number | null>(null);
  const [otp, setOtp] = useState("");
  const [o, setO] = useState<Overview | null>(null);
  const [subjects, setSubjects] = useState<{ id: number; name: string; code: string }[]>([]);
  const [mine, setMine] = useState<string[]>([]);
  const [form, setForm] = useState({ level: "jamb", subjects: [] as number[], goals: "", times: [] as string[] });
  const [pick, setPick] = useState<string | null>(null);
  const [custom, setCustom] = useState("");
  const [askOpen, setAskOpen] = useState(false);
  const [busy, setBusy] = useState<string | null>(null);
  const [msg, setMsg] = useState<{ ok: boolean; text: string } | null>(null);

  useEffect(() => {
    const url = new URL(window.location.href);
    // From the app: after paying, /pay/done opens the app again by itself (D-153).
    if (url.searchParams.get("from") === "app") { try { sessionStorage.setItem("st-from-app", "1"); } catch {} queueMicrotask(() => setFromApp(true)); }
    // From the app (D-115 one-time code): log straight in, never mixing two accounts.
    const code = url.searchParams.get("h");
    if (code) {
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
    const uid = (await sb.auth.getUser()).data.user?.id;
    const [ov, sub, prof] = await Promise.all([
      sb.rpc("tutor_overview"), sb.from("subjects").select("id, name, code").order("sort"),
      uid ? sb.from("profiles").select("jamb_subjects").eq("id", uid).maybeSingle() : Promise.resolve({ data: null }),
    ]);
    setO((ov.data ?? null) as unknown as Overview);
    setSubjects((sub.data ?? []) as { id: number; name: string; code: string }[]);
    setMine(((prof.data as { jamb_subjects?: string[] } | null)?.jamb_subjects ?? []).map((s) => s.toLowerCase()));
  }, [sb]);
  useEffect(() => { if (session) queueMicrotask(() => { void load(); }); }, [session, load]);

  // Live: the page follows the request (paid, tutor assigned) without a reload.
  useEffect(() => {
    if (!session) return;
    const ch = sb.channel(`tutor-web:${session.user.id}`)
      .on("postgres_changes", { event: "*", schema: "public", table: "tutor_requests", filter: `user_id=eq.${session.user.id}` }, () => void load())
      .subscribe();
    const t = setInterval(() => void load(), 30_000);
    return () => { void sb.removeChannel(ch); clearInterval(t); };
  }, [sb, session, load]);

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
    const { data } = await sb.rpc("tutor_request_create", {
      p_subject: (form.subjects[0] ?? null) as unknown as number, p_subjects: form.subjects.length ? form.subjects : undefined,
      p_level: form.level, p_goals: form.goals, p_times: TIMES.filter((t) => form.times.includes(t)).join(", "),
    });
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
    setCustom(""); setAskOpen(false); setMsg({ ok: true, text: "Sent. We will send you a price, usually within a day. You get a notification in the app." });
    await load();
  }
  async function pay(ref: string) {
    if (!session) return;
    setBusy("pay"); setMsg(null);
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

  const rise = (d = 0) => (rm ? {} : { initial: { opacity: 0, y: 12 }, animate: { opacity: 1, y: 0 }, transition: { duration: 0.4, delay: d, ease } });
  const card = "rounded-[20px] border bg-card p-4 shadow-[0_6px_20px_rgba(11,31,68,.06)] sm:p-5";
  const input = "w-full rounded-2xl border border-input bg-card px-4 text-[15px] outline-none focus-visible:ring-2 focus-visible:ring-[#2563B3]";
  const gold = "inline-flex h-[54px] w-full items-center justify-center gap-2 rounded-[18px] bg-[#F2B233] px-5 text-[16px] font-bold text-[#0B1F44] transition-transform active:scale-[.98] disabled:opacity-60";
  const navy = "inline-flex h-[54px] w-full items-center justify-center gap-2 rounded-[18px] bg-[#0B1F44] px-5 text-[16px] font-bold text-white transition-transform active:scale-[.98] disabled:opacity-60 dark:bg-[#F2B233] dark:text-[#0B1F44]";
  const chip = (on: boolean) => cn("rounded-full border px-4 py-2 text-sm font-bold transition-colors", on ? "border-[#0B1F44] bg-[#0B1F44] text-white dark:border-[#F2B233] dark:bg-[#F2B233] dark:text-[#0B1F44]" : "text-muted-foreground hover:text-foreground");

  const r = o?.request ?? null;
  const name = (session?.user.user_metadata?.full_name as string | undefined)?.split(" ")[0] ?? session?.user.email?.split("@")[0] ?? "";

  const hero = (title: string, text: string) => (
    <div className="relative overflow-hidden bg-[#0B1F44] px-4 pb-9 pt-4 text-white sm:rounded-b-[28px] sm:px-8">
      <div className="pointer-events-none absolute -bottom-20 -right-12 size-56 rounded-full bg-[#2563B3] opacity-35" />
      <div className="relative mx-auto flex max-w-2xl items-center gap-2.5">
        {/* eslint-disable-next-line @next/next/no-img-element */}
        <img src="/brand/solutiontee-mark-transparent.png" alt="SolutionTee" className="size-9 rounded-[10px] bg-white p-0.5" />
        <b className="flex-1 text-[16px]">SolutionTee CBT</b>
        {session ? (
          <button type="button" onClick={() => sb.auth.signOut({ scope: "local" })} className="flex items-center gap-2 rounded-full bg-white/12 py-1 pl-1 pr-3 text-xs font-bold hover:bg-white/20" title="Log out">
            <span className="grid size-6 place-items-center rounded-full bg-[#F2B233] text-[10px] text-[#0B1F44]">{name.slice(0, 2).toUpperCase()}</span>{name}<SignOut size={14} />
          </button>
        ) : null}
      </div>
      <div className="relative mx-auto mt-6 max-w-2xl">
        <motion.p {...rise(0.05)} className="text-xs font-bold tracking-[.08em] text-[#F2B233]">{fromApp ? "FROM YOUR APP" : "1-ON-1 TUTORING"}</motion.p>
        <motion.h1 {...rise(0.1)} className="mt-1 text-[26px] font-bold leading-tight sm:text-3xl">{title}</motion.h1>
        <motion.p {...rise(0.15)} className="mt-1.5 max-w-md text-[15px] text-[#C9D6EA]">{text}</motion.p>
      </div>
    </div>
  );

  if (!ready) return <div className="min-h-dvh bg-[#F4F6FA] dark:bg-[#060E1D]"><div className="h-48 animate-pulse bg-[#0B1F44]" /></div>;

  if (!session) {
    return (
      <div className="min-h-dvh bg-[#F4F6FA] dark:bg-[#060E1D]">
        {hero("Get a real tutor", "Log in with the email you use in the SolutionTee app. We send you a code.")}
        <div className="mx-auto -mt-4 max-w-md px-4 pb-10">
          <motion.div {...rise(0.2)} className={card}>
            {codeLen === null ? (
              <form onSubmit={sendCode} className="space-y-3">
                <label className="text-sm font-bold" htmlFor="em">Email</label>
                <input id="em" type="email" required autoComplete="email" placeholder="you@example.com" className={cn(input, "h-12")} value={email} onChange={(e) => setEmail(e.target.value.trim())} />
                <button disabled={busy !== null || !email} className={navy}>{busy ? <SpinnerGap className="animate-spin" size={18} /> : null} Send me a code</button>
              </form>
            ) : (
              <form onSubmit={verify} className="space-y-3">
                <p className="text-sm text-muted-foreground">We sent a {codeLen}-digit code to <b className="text-foreground">{email}</b>. Check your spam folder too.</p>
                <input inputMode="numeric" autoComplete="one-time-code" maxLength={codeLen} required aria-label="Code" className={cn(input, "h-14 text-center text-2xl tracking-[.4em]")} value={otp} onChange={(e) => setOtp(e.target.value.replace(/\D/g, ""))} />
                <button disabled={busy !== null || otp.length !== codeLen} className={navy}>{busy ? <SpinnerGap className="animate-spin" size={18} /> : null} Log in</button>
                <button type="button" className="w-full text-sm font-bold text-[#2563B3] dark:text-[#98B6DB]" onClick={() => { setCodeLen(null); setOtp(""); }}>Use another email</button>
              </form>
            )}
            {msg ? <p role="alert" className={`mt-3 text-sm font-bold ${msg.ok ? "text-success" : "text-error"}`}>{msg.text}</p> : null}
          </motion.div>
        </div>
      </div>
    );
  }
  if (!o) return <div className="min-h-dvh bg-[#F4F6FA] dark:bg-[#060E1D]"><div className="h-48 animate-pulse bg-[#0B1F44]" /></div>;

  const choosing = r && ["new", "quoted", "ended"].includes(r.status);
  const options = [
    ...(r?.custom_price_kobo ? [{ id: r.id, name: "Your custom plan", price: r.custom_price_kobo, line: `${r.custom_days ?? 30} days`, feats: features(r.custom_note), badge: "FOR YOU" }] : []),
    ...o.plans.map((p, i) => ({
      id: p.id, name: p.name, price: p.price_kobo,
      line: [p.sessions ? `${p.sessions} lessons` : null, `${p.days} days`, p.sessions ? `${ngn(p.price_kobo / p.sessions)} a lesson` : null].filter(Boolean).join(" · "),
      feats: features(p.description), badge: !r?.custom_price_kobo && i === (o.plans.length >= 3 ? 1 : 0) ? "MOST POPULAR" : null,
    })),
  ];
  const sel = options.find((x) => x.id === pick) ?? options.find((x) => x.badge) ?? options[0];
  const levelName = LEVELS.find(([k]) => k === r?.level)?.[1] ?? "";
  const sorted = [...subjects].sort((a, b) => Number(mine.includes(b.code.toLowerCase())) - Number(mine.includes(a.code.toLowerCase())));

  return (
    <div className="min-h-dvh bg-[#F4F6FA] pb-40 dark:bg-[#060E1D]">
      {hero(
        !r || r.status === "closed" ? "Learn with a real teacher" : r.status === "paid" ? "Payment received" : r.status === "matched" ? "Your tutor is ready" : r.status === "ended" ? "Renew your tutor plan" : "Finish paying for your tutor",
        !r || r.status === "closed" ? "Chat, voice notes and live classes with a tutor who knows your exam." : r.status === "paid" ? "A tutor will be assigned to you within 24 hours. This page and your app change by themselves." : r.status === "matched" ? "Chat with your tutor in the SolutionTee app." : fromApp ? "You will go straight back to the app when payment is done." : "Choose a plan and pay safely with Paystack.")}
      <div className="mx-auto -mt-4 max-w-2xl space-y-3 px-4">
        <AnimatePresence>{msg ? (
          <motion.p initial={rm ? false : { opacity: 0, y: -6 }} animate={{ opacity: 1, y: 0 }} exit={{ opacity: 0 }} role="status"
            className={`rounded-2xl px-4 py-3 text-sm font-bold ${msg.ok ? "bg-success-soft text-on-success-soft" : "bg-error-soft text-on-error-soft"}`}>{msg.text}</motion.p>
        ) : null}</AnimatePresence>

        {r && r.status === "paid" ? (
          <motion.div {...rise(0.15)} className={card}>
            {[["Payment received", o.subscription ? `${o.subscription.plan} plan until ${new Date(o.subscription.ends_at).toLocaleDateString("en-NG", { day: "numeric", month: "short", year: "numeric" })}` : "Thank you!", "done"],
              [`Matching ${r.subjects ? `a ${r.subjects}` : "you with a"} tutor`, "Usually within 24 hours", "now"], ["Say hello to your tutor", "Chat, calls and voice notes in the app", "later"]].map(([t, s, st], i) => (
              <div key={t} className="flex gap-3">
                <div className="flex flex-col items-center">
                  <span className={cn("grid size-7 place-items-center rounded-full", st === "done" ? "bg-[#1FA463] text-white" : st === "now" ? "bg-[#2563B3] shadow-[0_0_0_5px_rgba(37,99,179,.2)]" : "bg-muted")}>
                    {st === "done" ? <Check size={15} weight="bold" /> : <span className={cn("size-2 rounded-full", st === "now" ? "animate-pulse bg-white" : "bg-muted-foreground/50")} />}
                  </span>
                  {i < 2 ? <span className={cn("h-7 w-0.5", st === "done" ? "bg-[#1FA463]" : "bg-border")} /> : null}
                </div>
                <div className="pb-2"><b className={cn("text-[15px]", st === "later" && "text-muted-foreground")}>{t}</b><p className="text-sm text-muted-foreground">{s}</p></div>
              </div>
            ))}
          </motion.div>
        ) : null}

        {r && r.status === "matched" && o.tutor ? (
          <motion.div {...rise(0.15)} className={card}>
            <p className="flex items-center gap-1.5 text-sm font-bold text-[#137A48] dark:text-[#7FD8A6]"><CheckCircle size={18} weight="fill" /> Tutor assigned</p>
            <div className="mt-3 flex items-center gap-3">
              <span className="grid size-14 place-items-center rounded-full bg-[#F2B233] text-lg font-bold text-[#0B1F44]">{o.tutor.name.split(" ").map((p) => p[0]).slice(0, 2).join("")}</span>
              <div><h2 className="text-xl font-bold">{o.tutor.name}</h2>{o.tutor.subjects ? <p className="text-sm text-muted-foreground">{o.tutor.subjects}</p> : null}</div>
            </div>
            {o.subscription ? <p className="mt-3 text-sm">Plan: <b>{o.subscription.plan}</b> until {new Date(o.subscription.ends_at).toLocaleDateString("en-NG", { day: "numeric", month: "long" })}</p> : null}
            <p className="mt-3 flex items-center gap-2 rounded-2xl bg-[#EEF3FB] px-4 py-3 text-sm dark:bg-[#10284D]"><DeviceMobile size={20} /> Open the SolutionTee app: Study → My tutor.</p>
          </motion.div>
        ) : null}

        {!r || r.status === "closed" ? (
          <motion.form {...rise(0.15)} onSubmit={request} className={cn(card, "space-y-5")}>
            <div>
              <p className="mb-2 text-sm font-bold">Exam</p>
              <div className="flex flex-wrap gap-2">{LEVELS.map(([k, l]) => <button key={k} type="button" onClick={() => setForm({ ...form, level: k })} className={chip(form.level === k)}>{l}</button>)}</div>
            </div>
            <div>
              <p className="mb-2 text-sm font-bold">Subjects <span className="font-normal text-muted-foreground">· up to 4{mine.length ? ", your JAMB combination first" : ""}</span></p>
              <div className="flex flex-wrap gap-2">
                {sorted.slice(0, 16).map((s) => {
                  const on = form.subjects.includes(s.id);
                  return <button key={s.id} type="button" onClick={() => setForm({ ...form, subjects: on ? form.subjects.filter((x) => x !== s.id) : form.subjects.length < 4 ? [...form.subjects, s.id] : form.subjects })} className={chip(on)}>{s.name}</button>;
                })}
              </div>
            </div>
            <div>
              <label htmlFor="goals" className="mb-2 block text-sm font-bold">What do you want help with?</label>
              <textarea id="goals" required minLength={5} maxLength={1000} rows={3} placeholder="For example: I keep failing graphs and motion questions. I want 250+ in JAMB." className={cn(input, "py-3")} value={form.goals} onChange={(e) => setForm({ ...form, goals: e.target.value })} />
            </div>
            <div>
              <p className="mb-2 text-sm font-bold">When are you free? <span className="font-normal text-muted-foreground">· optional</span></p>
              <div className="grid grid-cols-4 gap-2">{TIMES.map((t) => {
                const on = form.times.includes(t);
                return <button key={t} type="button" onClick={() => setForm({ ...form, times: on ? form.times.filter((x) => x !== t) : [...form.times, t] })}
                  className={cn("h-12 rounded-[14px] border text-xs font-bold sm:text-sm", on ? "border-[#2563B3] bg-[#E7EEF7] text-[#13386B] dark:bg-[#10284D] dark:text-white" : "text-muted-foreground")}>{t}</button>;
              })}</div>
            </div>
            <button disabled={busy !== null} className={gold}>{busy === "req" ? <SpinnerGap className="animate-spin" size={18} /> : null} See tutor plans <ArrowRight size={18} weight="bold" /></button>
          </motion.form>
        ) : null}

        {choosing ? (
          <>
            <motion.div {...rise(0.15)} className={card}>
              <p className="text-xs font-bold tracking-[.06em] text-muted-foreground">YOUR REQUEST</p>
              <p className="mt-1.5 text-[15px] font-bold">{[r!.subjects, levelName].filter(Boolean).join(" · ") || "Tutor request"}</p>
              <p className="line-clamp-2 text-sm text-muted-foreground">{r!.times ? `${r!.times} · ` : ""}{r!.goals}</p>
            </motion.div>
            <p className="px-1 pt-2 text-sm font-bold">Choose a plan</p>
            <div className="space-y-3" role="radiogroup" aria-label="Tutor plans">
              {options.map((x, i) => {
                const on = sel?.id === x.id;
                return (
                  <motion.button key={x.id} type="button" role="radio" aria-checked={on} onClick={() => setPick(x.id)} {...rise(0.2 + 0.05 * i)}
                    className={cn("relative block w-full rounded-[18px] border bg-card p-4 text-left transition-[border-color,box-shadow]", on ? "border-2 border-[#0B1F44] shadow-[0_6px_20px_rgba(11,31,68,.1)] dark:border-[#F2B233]" : "hover:border-[#9AA8BE]", x.badge && "mt-2")}>
                    {x.badge ? <span className="absolute -top-3 right-4 rounded-[10px] bg-[#F2B233] px-2.5 py-0.5 text-[11px] font-bold tracking-wide text-[#0B1F44]">{x.badge}</span> : null}
                    <span className="flex items-center gap-3">
                      <span className={cn("grid size-[22px] shrink-0 place-items-center rounded-full", on ? "bg-[#0B1F44] dark:bg-[#F2B233]" : "border-2 border-[#9AA8BE]")}>{on ? <span className="size-2 rounded-full bg-[#F2B233] dark:bg-[#0B1F44]" /> : null}</span>
                      <span className="min-w-0 flex-1"><b className="block text-[15px]">{x.name}</b><span className="text-[13px] text-muted-foreground">{x.line}</span></span>
                      <b className="text-[17px] tabular-nums">{ngn(x.price)}</b>
                    </span>
                    <AnimatePresence initial={false}>
                      {on && x.feats.length ? (
                        <motion.ul initial={rm ? false : { height: 0, opacity: 0 }} animate={{ height: "auto", opacity: 1 }} exit={rm ? undefined : { height: 0, opacity: 0 }} className="overflow-hidden pl-[34px]">
                          {x.feats.slice(0, 5).map((f) => <li key={f} className="mt-2 flex items-start gap-2 text-sm"><Check size={16} weight="bold" className="mt-0.5 shrink-0 text-[#1FA463]" />{f}</li>)}
                        </motion.ul>
                      ) : null}
                    </AnimatePresence>
                  </motion.button>
                );
              })}
            </div>
            <motion.div {...rise(0.35)} className="rounded-[18px] border border-dashed p-4">
              {r!.custom_note && !r!.custom_price_kobo ? (
                <p className="flex items-start gap-2 text-sm"><Sparkle size={18} weight="fill" className="mt-0.5 shrink-0 text-[#D99A1E]" /><span><b>Custom plan: price coming.</b> We got &ldquo;{r!.custom_note}&rdquo;. We send a price, usually within a day.</span></p>
              ) : askOpen ? (
                <div className="space-y-3">
                  <b className="flex items-center gap-2"><Sparkle size={18} weight="fill" className="text-[#D99A1E]" /> Custom plan</b>
                  <textarea rows={2} maxLength={1000} autoFocus className={cn(input, "py-3")} placeholder="I need weekend classes for 2 months" value={custom} onChange={(e) => setCustom(e.target.value)} />
                  <div className="flex gap-2">
                    <button type="button" className="h-11 flex-1 rounded-2xl border text-sm font-bold" onClick={() => setAskOpen(false)}>Cancel</button>
                    <button type="button" disabled={busy !== null || custom.trim().length < 5} onClick={askCustom} className="inline-flex h-11 flex-1 items-center justify-center gap-2 rounded-2xl bg-[#0B1F44] text-sm font-bold text-white disabled:opacity-60 dark:bg-[#F2B233] dark:text-[#0B1F44]">{busy === "custom" ? <SpinnerGap className="animate-spin" size={16} /> : null} Ask for a price</button>
                  </div>
                </div>
              ) : (
                <button type="button" onClick={() => setAskOpen(true)} className="flex w-full items-center gap-3 text-left">
                  <span className="grid size-10 place-items-center rounded-xl bg-[#FDF3E0] text-[#B57D12] dark:bg-[#2B2210] dark:text-[#F2B233]"><Sparkle size={20} weight="fill" /></span>
                  <span className="flex-1"><b className="block">Custom plan</b><span className="text-sm text-muted-foreground">Weekend class, group, more lessons: we send a price</span></span>
                  <ArrowRight size={18} className="text-muted-foreground" />
                </button>
              )}
            </motion.div>
          </>
        ) : null}
      </div>

      {choosing && sel ? (
        <div className="fixed inset-x-0 bottom-0 z-20 border-t bg-card/95 px-4 pb-[max(16px,env(safe-area-inset-bottom))] pt-3 backdrop-blur dark:bg-[#0D1A30]/95">
          <div className="mx-auto max-w-2xl">
            <div className="mb-2.5 flex justify-between text-sm"><span className="text-muted-foreground">Total today</span><b className="tabular-nums">{ngn(sel.price)}</b></div>
            <button disabled={busy !== null} onClick={() => pay(sel.id)} className={navy}>{busy === "pay" ? <SpinnerGap className="animate-spin" size={18} /> : <LockSimple size={18} weight="fill" />} Pay {ngn(sel.price)} securely</button>
            <p className="mt-2 flex items-center justify-center gap-1.5 text-xs text-muted-foreground"><ShieldCheck size={14} weight="fill" className="text-[#1FA463]" /> Card, transfer or USSD through Paystack</p>
          </div>
        </div>
      ) : null}
    </div>
  );
}
