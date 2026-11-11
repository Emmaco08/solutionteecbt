"use client";
import { useCallback, useEffect, useMemo, useState } from "react";
import Link from "next/link";
import { useSearchParams } from "next/navigation";
import type { Session } from "@supabase/supabase-js";
import { CalendarBlank, CheckCircle, FileText, PlayCircle, SignOut, SpinnerGap, VideoCamera } from "@phosphor-icons/react";
import { createClient } from "@/lib/supabase/client";

type Assignment = { id: string; title: string; instructions: string | null; due_at: string | null; max_score: number; answer: string | null; submitted_at: string | null; score: number | null; feedback: string | null };
type Mine = { id: string; title: string; teacher: string; starts_at: string; minutes: number; access: string; status: string; registered: boolean; has_recording: boolean; materials: { title: string; url: string }[]; assignments: Assignment[] };
type Pub = { id: string; title: string; teacher: string; starts_at: string; minutes: number; access: "free" | "premium" | "paid"; price_kobo: number | null; seats_left: number | null };

const ngn = (kobo: number) => `₦${(kobo / 100).toLocaleString("en-NG")}`;
const when = (iso: string) => new Date(iso).toLocaleString("en-NG", { timeZone: "Africa/Lagos", weekday: "short", day: "numeric", month: "short", hour: "numeric", minute: "2-digit" });
const end = (c: { starts_at: string; minutes: number }) => new Date(c.starts_at).getTime() + c.minutes * 60000;
const ERR: Record<string, string> = {
  early: "The class opens 15 minutes before it starts.", ended: "This class has ended.", no_link: "The teacher has not added the link yet. Try again in a minute.",
  pay: "Register and pay to join this class.", premium: "This class is for Premium students. Get Premium on the Premium page.", full: "This class is full.",
  no_recording: "The recording is not ready yet.", locked: "This is for students of the class.", late: "The time to hand this in has passed.",
  marked: "This was already marked, so it cannot change.", length: "Write your answer first.",
};

/** cbt.solutiontee.com/classes/me (D-148): sign in with an email code, register or pay, join, recordings, materials and assignments. */
export function ClassDashboard() {
  const sp = useSearchParams();
  const sb = useMemo(() => createClient(), []);
  const [session, setSession] = useState<Session | null>(null);
  const [ready, setReady] = useState(false);
  const [email, setEmail] = useState("");
  const [codeLen, setCodeLen] = useState<number | null>(null);
  const [otp, setOtp] = useState("");
  const [mine, setMine] = useState<Mine[] | null>(null);
  const [pub, setPub] = useState<Pub[]>([]);
  const [busy, setBusy] = useState<string | null>(null);
  const [msg, setMsg] = useState<{ ok: boolean; text: string } | null>(null);
  const [answers, setAnswers] = useState<Record<string, string>>({});
  const [now] = useState(() => new Date().getTime());
  const want = sp.get("class");

  useEffect(() => {
    sb.auth.getSession().then(({ data }) => { setSession(data.session); setReady(true); });
    const { data } = sb.auth.onAuthStateChange((_e, s) => setSession(s));
    return () => data.subscription.unsubscribe();
  }, [sb]);

  const load = useCallback(async () => {
    const [m, p] = await Promise.all([sb.rpc("my_class_dashboard"), sb.rpc("public_classes")]);
    setMine(((m.data ?? []) as unknown as Mine[]));
    setPub(((p.data ?? []) as unknown as Pub[]));
  }, [sb]);
  useEffect(() => { if (session) queueMicrotask(() => { void load(); }); }, [session, load]);

  async function sendCode(e: React.FormEvent) {
    e.preventDefault();
    setBusy("code"); setMsg(null);
    try {
      const r = await fetch("/api/web/login-code", { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify({ email }) });
      const j = await r.json().catch(() => ({}));
      if (!r.ok) throw new Error(j.error ?? "Something went wrong. Try again.");
      setCodeLen(Number(j.codeLength ?? 6));
    } catch (x) { setMsg({ ok: false, text: x instanceof Error ? x.message : "No internet connection." }); } finally { setBusy(null); }
  }
  async function verify(e: React.FormEvent) {
    e.preventDefault();
    setBusy("verify"); setMsg(null);
    const { error } = await sb.auth.verifyOtp({ email: email.trim().toLowerCase(), token: otp.trim(), type: "recovery" });
    setBusy(null);
    if (error) setMsg({ ok: false, text: "That code is wrong or has expired. Check it, or ask for a new one." });
  }

  async function register(c: Pub) {
    if (!session) return;
    setBusy(c.id); setMsg(null);
    try {
      if (c.access === "paid") {
        const o = window.location.origin;
        const back = /^https:\/\/(cbt|admin)\.solutiontee\.com$/.test(o) ? { callback: `${o}/pay/done`, cancel: `${o}/pay` } : {};
        const r = await fetch(`${process.env.NEXT_PUBLIC_SUPABASE_URL}/functions/v1/paystack`, {
          method: "POST",
          headers: { "content-type": "application/json", authorization: `Bearer ${session.access_token}`, apikey: process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY! },
          body: JSON.stringify({ action: "start_item", kind: "item", ref: c.id, source: "web", method: "page", ...back }),
        });
        const j = await r.json().catch(() => ({}));
        if (!r.ok) throw new Error(j.error ?? "Paystack is not answering. Try again.");
        const url = String(j.url ?? "");
        if (!/^https:\/\/checkout\.paystack\.com\//.test(url)) throw new Error("Paystack did not open. Try again.");
        try { sessionStorage.setItem("st-after-pay", "/classes/me"); } catch {}
        window.location.assign(url);
        return;
      }
      const { data, error } = await sb.rpc("class_register", { p_class: c.id });
      const d = (data ?? {}) as { ok?: boolean; error?: string };
      if (error || !d.ok) throw new Error(ERR[d.error ?? ""] ?? "You cannot register for this class.");
      setMsg({ ok: true, text: "You are registered. We will remind you in the app before it starts." });
      await load();
    } catch (x) { setMsg({ ok: false, text: x instanceof Error ? x.message : "Try again." }); } finally { setBusy(null); }
  }

  async function open(id: string, fn: "class_join" | "class_recording") {
    setBusy(id + fn); setMsg(null);
    const { data, error } = await sb.rpc(fn, { p_class: id });
    setBusy(null);
    const d = (data ?? {}) as { ok?: boolean; url?: string; error?: string };
    if (error || !d.ok || !d.url?.startsWith("https://")) return setMsg({ ok: false, text: ERR[d.error ?? ""] ?? "Could not open it. Try again." });
    window.open(d.url, "_blank", "noopener,noreferrer");
    if (fn === "class_join") void load();
  }

  async function submit(a: Assignment) {
    setBusy(a.id); setMsg(null);
    const { data, error } = await sb.rpc("class_submit", { p_assignment: a.id, p_answer: answers[a.id] ?? a.answer ?? "" });
    setBusy(null);
    const d = (data ?? {}) as { ok?: boolean; error?: string };
    if (error || !d.ok) return setMsg({ ok: false, text: ERR[d.error ?? ""] ?? "Could not hand it in. Try again." });
    setMsg({ ok: true, text: "Handed in. Your teacher will mark it." });
    await load();
  }

  const box = "rounded-2xl border bg-card p-5 shadow-[var(--shadow-1)]";
  const btn = "inline-flex h-11 items-center justify-center gap-2 rounded-2xl px-5 text-sm font-bold disabled:opacity-60";
  const input = "h-12 w-full rounded-2xl border border-input bg-card px-4 text-[15px]";

  if (!ready) return <div className="h-64 animate-pulse rounded-3xl bg-card" />;
  if (!session) {
    return (
      <div className={`${box} mx-auto max-w-md`}>
        <h1 className="text-2xl font-bold">My classes</h1>
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
      </div>
    );
  }

  const mineIds = new Set((mine ?? []).filter((m) => m.registered).map((m) => m.id));
  const chosen = want ? pub.find((p) => p.id === want) : undefined;
  const upcoming = (mine ?? []).filter((m) => end(m) >= now);
  const past = (mine ?? []).filter((m) => end(m) < now);
  const toRegister = pub.filter((p) => !mineIds.has(p.id));

  return (
    <div className="space-y-6">
      <div className="flex flex-wrap items-center gap-3">
        <h1 className="mr-auto text-3xl font-bold tracking-tight">My classes</h1>
        <Link href="/classes" className="text-sm font-bold text-link">Timetable</Link>
        <button className="inline-flex items-center gap-1 text-sm font-bold text-muted-foreground" onClick={() => sb.auth.signOut({ scope: "local" })}><SignOut size={16} /> Log out</button>
      </div>
      {msg ? <p role="status" className={`rounded-2xl px-4 py-3 text-sm font-bold ${msg.ok ? "bg-success-soft text-on-success-soft" : "bg-error-soft text-on-error-soft"}`}>{msg.text}</p> : null}

      {chosen && !mineIds.has(chosen.id) ? (
        <div className={`${box} border-[#F2B233]`}>
          <p className="text-sm font-bold text-muted-foreground">Register for this class</p>
          <p className="mt-1 text-xl font-bold">{chosen.title}</p>
          <p className="text-sm text-muted-foreground">{when(chosen.starts_at)} · {chosen.minutes} min · with {chosen.teacher}</p>
          <button disabled={busy !== null} onClick={() => register(chosen)} className={`${btn} mt-4 bg-[#F2B233] text-[#0B1F44]`}>
            {busy === chosen.id ? <SpinnerGap className="animate-spin" size={18} /> : null}
            {chosen.access === "paid" ? `Register and pay ${ngn(chosen.price_kobo ?? 0)}` : chosen.access === "premium" ? "Register (Premium)" : "Register for free"}
          </button>
        </div>
      ) : null}

      {mine === null ? <div className="h-40 animate-pulse rounded-3xl bg-card" /> : null}

      {upcoming.length ? (
        <section className="space-y-3">
          <h2 className="text-xl font-bold">Coming up</h2>
          {upcoming.map((c) => {
            const live = now >= new Date(c.starts_at).getTime() - 15 * 60000;
            return (
              <div key={c.id} className={box}>
                <div className="flex flex-wrap items-start gap-3">
                  <div className="mr-auto">
                    <p className="text-lg font-bold">{c.title}</p>
                    <p className="flex items-center gap-1.5 text-sm text-muted-foreground"><CalendarBlank size={16} /> {when(c.starts_at)} · {c.minutes} min · {c.teacher}</p>
                    {c.registered ? <p className="mt-1 flex items-center gap-1 text-xs font-bold text-success"><CheckCircle size={14} weight="fill" /> Registered</p> : null}
                  </div>
                  <button disabled={busy !== null} onClick={() => open(c.id, "class_join")} className={`${btn} ${live ? "bg-[#F2B233] text-[#0B1F44]" : "border"}`}>
                    <VideoCamera size={18} weight="fill" /> {live ? "Join now" : "Opens 15 min before"}
                  </button>
                </div>
                <Extras c={c} answers={answers} setAnswers={setAnswers} submit={submit} busy={busy} />
              </div>
            );
          })}
        </section>
      ) : null}

      {mine !== null && upcoming.length === 0 && !chosen ? (
        <div className={box}><p className="font-bold">No classes yet</p><p className="text-sm text-muted-foreground">Pick a class below or on the timetable.</p></div>
      ) : null}

      {toRegister.length ? (
        <section className="space-y-3">
          <h2 className="text-xl font-bold">Other classes you can join</h2>
          <ul className="grid gap-3 sm:grid-cols-2">
            {toRegister.map((c) => (
              <li key={c.id} className={box}>
                <p className="font-bold">{c.title}</p>
                <p className="text-sm text-muted-foreground">{when(c.starts_at)} · {c.teacher}</p>
                <button disabled={busy !== null || c.seats_left === 0} onClick={() => register(c)} className={`${btn} mt-3 border`}>
                  {busy === c.id ? <SpinnerGap className="animate-spin" size={18} /> : null}
                  {c.seats_left === 0 ? "Full" : c.access === "paid" ? `Register and pay ${ngn(c.price_kobo ?? 0)}` : "Register"}
                </button>
              </li>
            ))}
          </ul>
        </section>
      ) : null}

      {past.length ? (
        <section className="space-y-3">
          <h2 className="text-xl font-bold">Past classes</h2>
          {past.map((c) => (
            <div key={c.id} className={box}>
              <div className="flex flex-wrap items-center gap-3">
                <div className="mr-auto"><p className="font-bold">{c.title}</p><p className="text-sm text-muted-foreground">{when(c.starts_at)} · {c.teacher}</p></div>
                {c.has_recording ? <button disabled={busy !== null} onClick={() => open(c.id, "class_recording")} className={`${btn} border`}><PlayCircle size={18} weight="fill" /> Watch the recording</button> : <span className="text-sm text-muted-foreground">No recording yet</span>}
              </div>
              <Extras c={c} answers={answers} setAnswers={setAnswers} submit={submit} busy={busy} />
            </div>
          ))}
        </section>
      ) : null}
    </div>
  );
}

function Extras({ c, answers, setAnswers, submit, busy }: { c: Mine; answers: Record<string, string>; setAnswers: (a: Record<string, string>) => void; submit: (a: Assignment) => void; busy: string | null }) {
  if (!c.materials.length && !c.assignments.length) return null;
  return (
    <div className="mt-4 space-y-4 border-t pt-4">
      {c.materials.length ? (
        <div>
          <p className="text-sm font-bold">Materials</p>
          <ul className="mt-1 space-y-1">
            {c.materials.map((m) => <li key={m.url}><a href={m.url} target="_blank" rel="noopener noreferrer" className="inline-flex items-center gap-1.5 text-sm font-bold text-link"><FileText size={16} /> {m.title}</a></li>)}
          </ul>
        </div>
      ) : null}
      {c.assignments.map((a) => (
        <div key={a.id} className="rounded-xl bg-muted/50 p-4">
          <p className="font-bold">{a.title}</p>
          {a.due_at ? <p className="text-xs text-muted-foreground">Hand in by {new Date(a.due_at).toLocaleString("en-NG", { timeZone: "Africa/Lagos", day: "numeric", month: "short", hour: "numeric", minute: "2-digit" })}</p> : null}
          {a.instructions ? <p className="mt-1 whitespace-pre-wrap text-sm">{a.instructions}</p> : null}
          {a.score !== null ? (
            <p className="mt-2 text-sm"><b>Mark: {a.score} / {a.max_score}</b>{a.feedback ? <span className="block text-muted-foreground">{a.feedback}</span> : null}</p>
          ) : (
            <>
              <textarea rows={4} maxLength={8000} className="mt-2 w-full rounded-xl border border-input bg-card p-3 text-sm" placeholder="Your answer"
                value={answers[a.id] ?? a.answer ?? ""} onChange={(e) => setAnswers({ ...answers, [a.id]: e.target.value })} />
              <button disabled={busy !== null} onClick={() => submit(a)} className="mt-2 inline-flex h-10 items-center gap-2 rounded-xl bg-[#0B1F44] px-4 text-sm font-bold text-white disabled:opacity-60 dark:bg-[#F2B233] dark:text-[#0B1F44]">
                {busy === a.id ? <SpinnerGap className="animate-spin" size={16} /> : null} {a.submitted_at ? "Hand in again" : "Hand in"}
              </button>
            </>
          )}
        </div>
      ))}
    </div>
  );
}
