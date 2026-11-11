"use client";
import Link from "next/link";
import { useRouter, useSearchParams } from "next/navigation";
import { AnimatePresence, motion, useReducedMotion } from "motion/react";
import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import {
  ArrowLeft, ArrowRight, ArrowSquareOut, Bank, CalendarCheck, Check, CheckCircle, CreditCard, Crown, DeviceMobile, EnvelopeSimple, Hash,
  LockSimple, Plus, ShieldCheck, SignOut, SpinnerGap, Ticket, Wallet, XCircle,
} from "@phosphor-icons/react";
import type { Session } from "@supabase/supabase-js";
import { createClient } from "@/lib/supabase/client";
import { payStatus } from "./done/status";

type Plan = { code: string; name: string; description: string | null; price_kobo: number; duration_days: number | null; ends_on: string | null };
type Quote = {
  list_kobo: number; discount_kobo: number; fee_kobo?: number; amount_kobo: number; label?: string | null; code?: string | null; period_end?: string | null;
  codes?: { code: string; off_kobo: number; label: string }[];
};
const MAX_CODES = 3;

const ng = (kobo: number) => `₦${(kobo / 100).toLocaleString("en-NG")}`;
const day = (s: string) => new Date(s).toLocaleDateString("en-NG", { day: "numeric", month: "long", year: "numeric" });
const daysLeft = (s: string) => {
  const n = Math.max(0, Math.ceil((new Date(s).getTime() - Date.now()) / 86_400_000));
  return n <= 1 ? "Ends within a day" : `${n.toLocaleString("en-NG")} days left`;
};
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
type Mine = { tier: "premium" | "free"; expires_at: string | null; plan: string | null };

/** Opens the app's home screen (Android needs the intent: form). */
const APP_HOME = "intent://app/home#Intent;scheme=solutiontee;package=com.solutiontee.cbt;end";

const QUOTE_ERRORS: Record<string, string> = {
  not_found: "We could not find that code. Check the spelling.", expired: "This code has expired.", used_up: "This code has been used up.",
  already_used: "You have already used this code.", new_only: "This code is only for students who have never paid.",
  wrong_plan: "This code does not work on this plan.", too_many_tries: "Too many wrong codes. Please wait an hour.",
  covered: "Your Premium already covers this plan’s end date.", banned: "This account cannot make payments. Contact support.",
  plan: "This plan is not on sale any more. Pick another.", days_code: "This code gives free days: redeem it in the app (Me → Redeem a code).",
  too_many_codes: "You can use up to 3 codes on one payment.", paused: "This code is paused right now.", not_started: "This code does not work yet.",
};

const FALLBACK_BENEFITS = [
  "No ads at all: no banners, no video breaks", "Every past question year for JAMB, WAEC and NECO", "Video solutions, lessons and notes",
  "More AI tutor help every day", "Download and practise offline, without data",
];

/** What Premium gives, written from the admin's Free vs Premium rules (same words as the app's paywall). */
function premiumBenefits(a: Record<string, Record<string, unknown>>): string[] {
  const f = a.free ?? {}, p = a.premium ?? {};
  if (!a.premium) return [];
  const y = (v: unknown) => (v === "all" ? "every year" : `${v} years`);
  const out = ["No ads at all: no banners, no video breaks"];
  for (const k of ["jamb", "waec", "neco"]) {
    if (p[k] !== undefined && p[k] !== f[k]) out.push(`${k.toUpperCase()} CBT: ${y(p[k])}${typeof f[k] === "number" && (f[k] as number) > 0 ? ` (Free: ${y(f[k])})` : " (not on Free)"}`);
  }
  if (p.pq !== undefined && p.pq !== f.pq) out.push(`Past questions with answers: ${y(p.pq)} (Free: ${y(f.pq)})`);
  const feats = ([["videos", "Video solutions"], ["lessons", "Topic video lessons"], ["notes", "Lesson notes"], ["novels", "Novel summaries"]] as const)
    .filter(([k]) => p[k] === true && f[k] !== true).map(([, n]) => n);
  if (feats.length) out.push(feats.join(", "));
  if (p.ai !== undefined && p.ai !== f.ai) out.push(`${p.ai} AI tutor prompts a day (Free: ${f.ai})`);
  if (p.offline === true && f.offline !== true) out.push("Download lessons and practise offline, without data");
  return out.slice(0, 7);
}

/** About how much a plan costs per month (for comparing plans; the price paid is the plan price). */
function perMonth(p: Plan): number | null {
  const days = p.duration_days ?? (p.ends_on ? Math.ceil((new Date(p.ends_on).getTime() - Date.now()) / 86_400_000) : null);
  // Whole naira, to the nearest ₦10; not for plans of a month or less.
  return days && days > 31 ? Math.round(p.price_kobo / (days / 30) / 1000) * 1000 : null;
}

const STEPS = ["Email", "Code", "Plan", "Pay"] as const;

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
  // Up to 3 discount codes on one payment (D-117). A code can also come in the link (from the app).
  const [codes, setCodes] = useState<string[]>(() => (sp.get("code") ?? "").split(/[\s,;]+/).filter(Boolean).map((c) => c.toUpperCase()).slice(0, MAX_CODES));
  const applied = codes.length ? codes.join(",") : null;
  const [quote, setQuote] = useState<Quote | null>(null);
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState<string | null>(null);
  const [note, setNote] = useState<string | null>(null);
  const [left, setLeft] = useState<Left>(null);
  const [handoff, setHandoff] = useState(Boolean(sp.get("h")));
  const [mine, setMine] = useState<Mine | null>(null);
  const [extend, setExtend] = useState(false);
  const [benefits, setBenefits] = useState<string[]>(FALLBACK_BENEFITS);
  const [feeByPaystack, setFeeByPaystack] = useState(false);
  const [codeOpen, setCodeOpen] = useState(codes.length > 0);
  const [resendAt, setResendAt] = useState(0);
  const [now, setNow] = useState(() => Date.now());

  // Public settings (no login): what Premium gives (the admin's Free vs Premium rules, same words as the app) and
  // whether Paystack adds its fee at checkout (D-132).
  useEffect(() => {
    let live = true;
    Promise.all([sb.from("access_rules").select("tier, rules"), sb.from("app_settings").select("value").eq("key", "payments").maybeSingle()])
      .then(([r, s]) => {
        if (!live) return;
        const rules = Object.fromEntries(((r.data ?? []) as { tier: string; rules: Record<string, unknown> }[]).map((x) => [x.tier, x.rules]));
        const list = premiumBenefits(rules);
        if (list.length > 1) setBenefits(list);
        const v = s.data?.value as { fees?: { paystack?: { mode?: string } } } | null;
        setFeeByPaystack(v?.fees?.paystack?.mode === "paystack");
      }, () => {});
    return () => { live = false; };
  }, [sb]);

  // "Send a new code" waits 45 seconds.
  useEffect(() => {
    if (resendAt <= now) return;
    const t = setTimeout(() => setNow(Date.now()), 1000);
    return () => clearTimeout(t);
  }, [resendAt, now]);

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

  // Opened from the app: after paying, /pay/done sends the student straight back into the app (D-116).
  useEffect(() => {
    if (sp.get("from") === "app") { try { sessionStorage.setItem("st-from-app", "1"); } catch {} }
  }, [sp]);

  // From the app (D-115): a one-time code in the link logs the student in, then is removed from the address bar.
  // Runs once per page load. Removing the code changes the search params, which re-runs effects that depend on them;
  // this one must still finish (it used to be cancelled there and the page kept loading for ever).
  const handoffRan = useRef(false);
  useEffect(() => {
    if (handoffRan.current) return;
    const code = new URL(window.location.href).searchParams.get("h");
    if (!code) return;
    handoffRan.current = true;
    const url = new URL(window.location.href);
    url.searchParams.delete("h");
    url.searchParams.delete("email");
    window.history.replaceState(null, "", url.pathname + url.search);
    (async () => {
      try {
        const r = await fetch("/api/web/handoff/redeem", { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify({ code }) });
        const j = await r.json().catch(() => ({}));
        if (!r.ok || !j.token_hash) throw new Error(j.error ?? "This link has expired. Log in with your email instead.");
        await sb.auth.signOut({ scope: "local" }); // never mix two accounts
        const { error } = await sb.auth.verifyOtp({ token_hash: j.token_hash, type: "magiclink" });
        if (error) throw new Error("This link has expired. Log in with your email instead.");
        if (j.plan) setPick(String(j.plan));
      } catch (x) {
        setErr(x instanceof Error ? x.message : "This link has expired.");
      } finally {
        setHandoff(false);
      }
    })();
  }, [sb]);

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
      .catch(async () => {
        // The session could not be used (expired, or logged out elsewhere): ask by reference instead, never spin.
        const r = await payStatus(ref).catch(() => null);
        if (!live) return;
        if (r?.status === "success" || r?.status === "needs_review") {
          try { sessionStorage.removeItem(PENDING); } catch {}
          router.replace(`/pay/done?reference=${ref}`);
          return;
        }
        setLeft(r && (r.status === "abandoned" || pressedCancel) ? { kind: "cancelled", ref } : null);
      });
    if (pressedCancel) window.history.replaceState(null, "", window.location.pathname);
    return () => { live = false; };
  }, [session, sp, edge, router]);

  // The page can come back from the browser's memory (back button): stop the spinner.
  useEffect(() => {
    const show = (e: PageTransitionEvent) => { if (e.persisted) setBusy(false); };
    window.addEventListener("pageshow", show);
    return () => window.removeEventListener("pageshow", show);
  }, []);

  // Logged out after 15 minutes without activity (shared phones and cafés). Always this browser only ("local"): a
  // global sign-out would also log the student out of the app on their phone (D-129).
  useEffect(() => {
    if (!session) return;
    let t = setTimeout(() => sb.auth.signOut({ scope: "local" }), IDLE_MS);
    const poke = () => { clearTimeout(t); t = setTimeout(() => sb.auth.signOut({ scope: "local" }), IDLE_MS); };
    const evs = ["pointerdown", "keydown", "scroll"] as const;
    evs.forEach((e) => window.addEventListener(e, poke, { passive: true }));
    return () => { clearTimeout(t); evs.forEach((e) => window.removeEventListener(e, poke)); };
  }, [session, sb]);

  useEffect(() => {
    sb.auth.getSession().then(({ data }) => { setSession(data.session); setReady(true); });
    const { data } = sb.auth.onAuthStateChange((_e, s) => setSession(s));
    return () => data.subscription.unsubscribe();
  }, [sb]);

  // Already on Premium? Show that first (with the end date), not the plans (D-129).
  useEffect(() => {
    if (!session) { queueMicrotask(() => { setMine(null); setExtend(false); }); return; }
    let live = true;
    const free: Mine = { tier: "free", expires_at: null, plan: null };
    // Never wait for ever: with no answer in 8 seconds the plans are shown (the server still refuses a plan that
    // Premium already covers).
    const t = setTimeout(() => { if (live) setMine((m) => m ?? free); }, 8000);
    sb.rpc("my_plan").then(({ data }) => { if (live) setMine((data as Mine | null) ?? free); }, () => { if (live) setMine(free); });
    return () => { live = false; clearTimeout(t); };
  }, [session, sb]);

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
    if (!r.ok) {
      const which = (r as { code?: string }).code;
      setErr(`${which ? `${which}: ` : ""}${QUOTE_ERRORS[r.error ?? ""] ?? "That code cannot be used."}`);
      return false;
    }
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
      else if (!r.ok) {
        const which = (r as { code?: string }).code;
        setErr(`${which ? `${which}: ` : ""}${QUOTE_ERRORS[r.error ?? ""] ?? "That code cannot be used."}`);
      }
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
      setCodeLen(Number(j.codeLength ?? 6)); setNote(j.message ?? null); setOtp("");
      const t = Date.now(); setNow(t); setResendAt(t + 45_000);
    } catch (x) { setErr(x instanceof Error ? x.message : "No internet connection."); } finally { setBusy(false); }
  }

  async function verify(e?: React.FormEvent, value = otp) {
    e?.preventDefault();
    if (busy) return;
    setBusy(true); setErr(null);
    const { error } = await sb.auth.verifyOtp({ email: email.trim().toLowerCase(), token: value.trim(), type: "recovery" });
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
  const premium = mine?.tier === "premium" && mine.expires_at ? mine : null;
  const step = !ready || handoff || (session && !mine) ? "load" : !session ? (codeLen ? "code" : "email") : premium && !extend && !left ? "premium" : "plan";
  const anim = { initial: still ? false : { opacity: 0, y: 12 }, animate: { opacity: 1, y: 0 }, exit: still ? undefined : { opacity: 0, y: -8 }, transition: { duration: 0.3, ease } } as const;
  const stepNo = step === "email" ? 0 : step === "code" ? 1 : 2;
  const monthly = plans.map(perMonth);
  const best = plans.length > 1 ? monthly.indexOf(Math.min(...monthly.filter((m): m is number => m !== null))) : -1;
  const wait = Math.max(0, Math.ceil((resendAt - now) / 1000));

  return (
    <div className="grid w-full max-w-5xl items-start gap-6 lg:grid-cols-[minmax(0,1fr)_460px] lg:gap-10">
      {/* Left on computers, below on phones: what Premium gives */}
      <aside className="order-2 lg:order-1 lg:sticky lg:top-10">
        <Link href="/" className="hidden items-center gap-2.5 lg:flex" aria-label="SolutionTee CBT home">
          {/* Real brand mark from /brand (never redrawn) */}
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img src="/brand/favicon.svg" alt="" className="size-10 rounded-xl" />
          <span className="text-lg font-bold">SolutionTee <span className="text-[#C88A12] dark:text-[#F2B233]">CBT</span></span>
        </Link>
        <div className="rounded-3xl bg-[#0B1F44] p-6 text-white sm:p-8 lg:mt-8 dark:bg-[#0F2650] dark:ring-1 dark:ring-white/10">
          <span className="inline-flex items-center gap-1.5 rounded-lg bg-[#F2B233] px-2.5 py-1 text-xs font-bold text-[#0B1F44]"><Crown size={14} weight="fill" /> Premium</span>
          <h2 className="mt-4 text-[26px] font-bold leading-tight tracking-tight sm:text-[30px]">Everything you need to pass, in one plan</h2>
          <ul className="mt-6 space-y-3.5">
            {benefits.map((b) => (
              <li key={b} className="flex gap-3 text-[15px] leading-6 text-white/90">
                <span className="mt-0.5 grid size-5 shrink-0 place-items-center rounded-full bg-[#F2B233]/20 text-[#F2B233]"><Check size={12} weight="bold" /></span>{b}
              </li>
            ))}
          </ul>
          <div className="mt-7 grid grid-cols-3 gap-2 border-t border-white/10 pt-5 text-center text-xs text-white/70">
            <span><ShieldCheck size={20} weight="fill" className="mx-auto mb-1 text-[#4ADE80]" />Secured by Paystack</span>
            <span><CalendarCheck size={20} weight="fill" className="mx-auto mb-1 text-[#F2B233]" />Pay once, no auto-renew</span>
            <span><DeviceMobile size={20} weight="fill" className="mx-auto mb-1 text-[#8FB6EE]" />Works on any phone you log in</span>
          </div>
        </div>
        <p className="mt-5 text-center text-xs leading-5 text-muted-foreground lg:text-left">SolutionTee CBT is an independent exam-practice platform and is not affiliated with or endorsed by JAMB, WAEC or NECO.</p>
      </aside>

      <div className="order-1 lg:order-2">
        <div className="mb-5 flex items-center justify-between">
          <Link href="/" className="flex items-center gap-2.5 lg:invisible" aria-label="SolutionTee CBT home">
            {/* eslint-disable-next-line @next/next/no-img-element */}
            <img src="/brand/favicon.svg" alt="" className="size-9 rounded-xl" />
            <span className="text-[17px] font-bold">SolutionTee <span className="text-[#C88A12] dark:text-[#F2B233]">CBT</span></span>
          </Link>
          {session ? (
            <button type="button" onClick={() => sb.auth.signOut({ scope: "local" })} className="inline-flex h-10 items-center gap-1.5 rounded-xl px-3 text-sm font-medium text-muted-foreground hover:bg-muted hover:text-foreground">
              <SignOut size={16} /> Log out
            </button>
          ) : null}
        </div>

        <section className="rounded-3xl border bg-card shadow-[var(--shadow-2,0_10px_30px_rgba(6,19,43,.08))]">
          {step !== "load" && step !== "premium" ? (
            <ol className="flex items-center gap-2 border-b px-6 py-4 sm:px-8" aria-label="Steps">
              {STEPS.map((t, i) => {
                const done = i < stepNo, on = i === stepNo;
                return (
                  <li key={t} className="flex flex-1 items-center gap-2 last:flex-none">
                    <span className={`grid size-6 shrink-0 place-items-center rounded-full text-[11px] font-bold ${done ? "bg-success text-white" : on ? "bg-[#2563B3] text-white" : "bg-muted text-muted-foreground"}`}>
                      {done ? <Check size={12} weight="bold" /> : i + 1}
                    </span>
                    <span className={`text-xs font-bold ${on ? "text-foreground" : "text-muted-foreground"} ${on ? "" : "hidden sm:inline"}`}>{t}</span>
                    {i < STEPS.length - 1 ? <span className={`h-px flex-1 ${done ? "bg-success" : "bg-border"}`} /> : null}
                  </li>
                );
              })}
            </ol>
          ) : null}

          <div className="p-6 sm:p-8">
            <AnimatePresence mode="wait" initial={false}>
              {step === "load" ? (
                <motion.div key="load" className="grid h-56 place-items-center"><SpinnerGap size={28} className="animate-spin text-muted-foreground" /></motion.div>
              ) : step === "email" ? (
                <motion.form key="email" {...anim} onSubmit={sendCode}>
                  <h1 className="text-[26px] font-bold leading-tight tracking-tight">Get SolutionTee Premium</h1>
                  <p className="mt-2 text-[15px] leading-6 text-muted-foreground">Log in with the email you use in the app. We’ll send you a 6-digit code.</p>
                  <label htmlFor="email" className="mt-6 block text-sm font-bold">Email</label>
                  <div className="mt-2 flex h-13 items-center gap-2.5 rounded-2xl border bg-background px-4 transition-shadow focus-within:border-[#2563B3] focus-within:ring-4 focus-within:ring-[#2563B3]/15">
                    <EnvelopeSimple size={20} className="text-muted-foreground" />
                    <input id="email" type="email" required autoComplete="email" inputMode="email" value={email} onChange={(e) => setEmail(e.target.value)} placeholder="tolu@gmail.com" className="h-full min-w-0 flex-1 bg-transparent text-[16px] outline-none" />
                  </div>
                  {err ? <Alert>{err}</Alert> : null}
                  <PrimaryButton busy={busy} disabled={!email}>Send my code <ArrowRight size={16} weight="bold" /></PrimaryButton>
                  <p className="mt-5 text-center text-sm text-muted-foreground">No account yet? <a href="/download/apk" className="font-bold text-foreground underline-offset-4 hover:underline">Get the app</a> and sign up first.</p>
                </motion.form>
              ) : step === "code" ? (
                <motion.form key="code" {...anim} onSubmit={(e) => verify(e)}>
                  <button type="button" onClick={() => { setCodeLen(null); setOtp(""); setErr(null); }} className="-ml-1 mb-4 inline-flex h-9 items-center gap-1 rounded-lg px-1 text-sm font-medium text-muted-foreground hover:text-foreground"><ArrowLeft size={14} /> Change email</button>
                  <h1 className="text-[26px] font-bold leading-tight tracking-tight">Check your email</h1>
                  <p className="mt-2 text-[15px] leading-6 text-muted-foreground">{note ?? <>We sent a code to <b className="text-foreground">{email}</b>.</>} It can take a minute; check spam too.</p>
                  <CodeBoxes length={codeLen ?? 6} value={otp} disabled={busy}
                    onChange={(v) => { setOtp(v); setErr(null); if (v.length === (codeLen ?? 6)) void verify(undefined, v); }} />
                  {err ? <Alert>{err}</Alert> : null}
                  <PrimaryButton busy={busy} disabled={otp.length < (codeLen ?? 6)}>Log in</PrimaryButton>
                  <button type="button" onClick={() => sendCode()} disabled={busy || wait > 0} className="mt-3 h-11 w-full rounded-2xl text-sm font-bold text-muted-foreground hover:text-foreground disabled:opacity-60">
                    {wait > 0 ? `Send a new code in ${wait}s` : "Send a new code"}
                  </button>
                </motion.form>
              ) : step === "premium" && premium ? (
                <motion.div key="premium" {...anim}>
                  <p className="text-sm text-muted-foreground">Logged in as <b className="text-foreground">{session?.user.email}</b></p>
                  <PremiumNow plan={premium.plan} until={premium.expires_at!} onMore={() => setExtend(true)} />
                </motion.div>
              ) : (
                <motion.div key="plan" {...anim}>
                  <div className="flex items-start justify-between gap-3">
                    <div className="min-w-0">
                      {premium ? (
                        <button type="button" onClick={() => setExtend(false)} className="-ml-1 mb-2 inline-flex h-8 items-center gap-1 rounded-lg px-1 text-sm font-medium text-muted-foreground hover:text-foreground"><ArrowLeft size={14} /> Back to my Premium</button>
                      ) : null}
                      <h1 className="text-[26px] font-bold leading-tight tracking-tight">{premium ? "Add more time" : "Choose your plan"}</h1>
                      <p className="mt-1 truncate text-sm text-muted-foreground">{premium ? `New time starts after ${day(premium.expires_at!)}.` : <>For <b className="text-foreground">{session?.user.email}</b></>}</p>
                    </div>
                  </div>

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
                    {plans.length === 0 ? [0, 1, 2].map((i) => <div key={i} className="h-[76px] animate-pulse rounded-2xl bg-muted" />) : null}
                    {plans.map((p, i) => {
                      const on = p.code === pick, m = monthly[i];
                      return (
                        <button key={p.code} type="button" role="radio" aria-checked={on} onClick={() => setPick(p.code)}
                          className={`relative flex w-full items-center gap-4 rounded-2xl border-2 px-4 py-4 text-left transition-[border-color,background-color,box-shadow] ${on ? "border-[#2563B3] bg-[#F3F7FD] shadow-[0_0_0_4px_rgba(37,99,179,.12)] dark:bg-[#132B55]" : "border-border hover:border-[#2563B3]/50"}`}>
                          {i === best ? <span className="absolute -top-2.5 right-4 rounded-full bg-[#F2B233] px-2.5 py-0.5 text-[11px] font-bold text-[#0B1F44]">Best value</span> : null}
                          <span className={`grid size-6 shrink-0 place-items-center rounded-full border-2 transition-colors ${on ? "border-[#2563B3] bg-[#2563B3] text-white" : "border-border"}`}>{on ? <Check size={13} weight="bold" /> : null}</span>
                          <span className="min-w-0 grow">
                            <b className="block text-[16px]">{p.name}</b>
                            <small className="text-[13px] text-muted-foreground">{p.duration_days ? `${p.duration_days} days` : p.ends_on ? `Until ${day(p.ends_on)}` : ""}</small>
                          </span>
                          <span className="text-right">
                            <b className="block text-[18px] tabular-nums">{ng(p.price_kobo)}</b>
                            {m ? <small className="text-[12px] text-muted-foreground tabular-nums">≈ {ng(m)}/month</small> : null}
                          </span>
                        </button>
                      );
                    })}
                  </div>

                  {/* Discount codes: up to 3 (D-117) */}
                  {!codeOpen ? (
                    <button type="button" onClick={() => setCodeOpen(true)} className="mt-4 inline-flex h-10 items-center gap-2 rounded-xl px-1 text-sm font-bold text-[#2563B3] hover:underline dark:text-[#8FB6EE]">
                      <Ticket size={18} /> Have a discount code?
                    </button>
                  ) : (
                    <div className="mt-4">
                      <form className="flex gap-2" onSubmit={async (e) => {
                        e.preventDefault();
                        const d = discount.trim().toUpperCase();
                        if (!d || codes.includes(d)) { setDiscount(""); return; }
                        if (codes.length >= MAX_CODES) { setErr(QUOTE_ERRORS.too_many_codes); return; }
                        const next = [...codes, d];
                        if (await loadQuote(pick, next.join(","))) { setCodes(next); setDiscount(""); }
                      }}>
                        <div className="flex h-12 min-w-0 flex-1 items-center gap-2 rounded-xl border bg-background px-3 focus-within:border-[#2563B3] focus-within:ring-4 focus-within:ring-[#2563B3]/15">
                          <Ticket size={18} className="text-muted-foreground" />
                          <input autoFocus value={discount} onChange={(e) => setDiscount(e.target.value.toUpperCase())} disabled={codes.length >= MAX_CODES}
                            placeholder={codes.length ? (codes.length >= MAX_CODES ? "3 codes added" : "Add another code") : "Enter code"} aria-label="Discount code" className="h-full min-w-0 flex-1 bg-transparent text-sm font-bold uppercase tracking-wide outline-none placeholder:font-normal placeholder:normal-case placeholder:tracking-normal" />
                        </div>
                        <button type="submit" disabled={!discount.trim() || codes.length >= MAX_CODES} className="h-12 rounded-xl bg-[#0B1F44] px-5 text-sm font-bold text-white disabled:opacity-40 dark:bg-white dark:text-[#0B1F44]">Apply</button>
                      </form>
                      {codes.length ? (
                        <div className="mt-2.5 flex flex-wrap gap-2">
                          {codes.map((c) => (
                            <motion.span key={c} layout initial={{ scale: 0.8, opacity: 0 }} animate={{ scale: 1, opacity: 1 }} className="inline-flex items-center gap-1.5 rounded-full bg-success-soft py-1 pl-3 pr-1 text-xs font-bold text-on-success-soft">
                              <CheckCircle size={14} weight="fill" /> {c}
                              <button type="button" aria-label={`Remove ${c}`} onClick={() => setCodes(codes.filter((x) => x !== c))} className="grid size-6 place-items-center rounded-full hover:bg-black/10"><XCircle size={16} weight="fill" /></button>
                            </motion.span>
                          ))}
                        </div>
                      ) : null}
                    </div>
                  )}

                  {quote && plan ? (
                    <div className="mt-5 space-y-2.5 rounded-2xl bg-muted/50 p-4 text-sm">
                      <Line k={plan.name} v={ng(quote.list_kobo)} />
                      {quote.codes?.length
                        ? quote.codes.map((c) => <Line key={c.code} k={`${c.code} · ${c.label}`} v={`−${ng(c.off_kobo)}`} good />)
                        : quote.discount_kobo > 0 ? <Line k={quote.label ?? "Discount"} v={`−${ng(quote.discount_kobo)}`} good /> : null}
                      {(quote.fee_kobo ?? 0) > 0 ? <Line k="Payment processing fee" v={`+${ng(quote.fee_kobo ?? 0)}`} /> : null}
                      <div className="flex items-baseline justify-between border-t pt-3">
                        <b className="text-base">Total</b>
                        <b className="text-[22px] tabular-nums">{ng(quote.amount_kobo)}</b>
                      </div>
                      {feeByPaystack && quote.amount_kobo > 0 ? <p className="text-xs text-muted-foreground">+ Paystack’s processing fee, shown on Paystack’s page before you pay.</p> : null}
                      {quote.period_end ? <p className="flex items-center gap-1.5 text-xs text-muted-foreground"><CalendarCheck size={14} weight="fill" className="text-success" /> Premium until {day(quote.period_end)}. Pay once, no auto-renew.</p> : null}
                    </div>
                  ) : null}

                  {err ? <Alert>{err}</Alert> : null}

                  {/* On phones the pay button stays in reach while scrolling the plans */}
                  <div className="sticky bottom-0 -mx-6 mt-5 border-t bg-card/95 px-6 pb-[max(1rem,env(safe-area-inset-bottom))] pt-4 sm:static sm:mx-0 sm:border-0 sm:bg-transparent sm:p-0">
                    <button type="button" onClick={pay} disabled={busy || !quote} className="inline-flex h-14 w-full items-center justify-center gap-2 rounded-2xl bg-[#F2B233] text-[17px] font-bold text-[#0B1F44] shadow-[0_8px_20px_-8px_rgba(242,178,51,.7)] transition-transform hover:-translate-y-0.5 active:translate-y-0 disabled:opacity-60 disabled:shadow-none">
                      {busy ? <SpinnerGap size={20} className="animate-spin" /> : <LockSimple size={20} weight="fill" />} {quote && quote.amount_kobo === 0 ? "Get Premium free" : `Pay ${quote ? ng(quote.amount_kobo) : ""} securely`}
                    </button>
                    <div className="mt-3 flex flex-wrap items-center justify-center gap-x-3 gap-y-1.5 text-[12px] text-muted-foreground">
                      {([[CreditCard, "Card"], [Bank, "Transfer"], [Hash, "USSD"], [Wallet, "OPay"], [DeviceMobile, "Bank apps"]] as const).map(([I, t]) => (
                        <span key={t} className="inline-flex items-center gap-1"><I size={14} weight="fill" />{t}</span>
                      ))}
                    </div>
                  </div>
                </motion.div>
              )}
            </AnimatePresence>
          </div>
        </section>
      </div>
    </div>
  );
}

function Line({ k, v, good }: { k: string; v: string; good?: boolean }) {
  return <div className={`flex justify-between gap-3 ${good ? "text-[#15803D] dark:text-[#4ADE80]" : ""}`}><span className={good ? "" : "text-muted-foreground"}>{k}</span><span className="shrink-0 tabular-nums">{v}</span></div>;
}

function Alert({ children }: { children: React.ReactNode }) {
  return <p role="alert" className="mt-3 rounded-xl bg-error-soft px-3 py-2.5 text-sm text-on-error-soft">{children}</p>;
}

function PrimaryButton({ busy, disabled, children }: { busy: boolean; disabled?: boolean; children: React.ReactNode }) {
  return (
    <button type="submit" disabled={busy || disabled} className="mt-5 inline-flex h-13 w-full items-center justify-center gap-2 rounded-2xl bg-[#0B1F44] text-[16px] font-bold text-white transition-transform active:scale-[.99] disabled:opacity-50 dark:bg-white dark:text-[#0B1F44]">
      {busy ? <SpinnerGap size={18} className="animate-spin" /> : null} {children}
    </button>
  );
}

/** One box per digit over a single real input (keeps paste, SMS/email autofill and the phone keyboard working). */
function CodeBoxes({ length, value, onChange, disabled }: { length: number; value: string; onChange: (v: string) => void; disabled?: boolean }) {
  const [focus, setFocus] = useState(false);
  return (
    <div className="relative mt-6">
      <input autoFocus inputMode="numeric" autoComplete="one-time-code" maxLength={length} value={value} disabled={disabled} aria-label="Code"
        onChange={(e) => onChange(e.target.value.replace(/\D/g, "").slice(0, length))} onFocus={() => setFocus(true)} onBlur={() => setFocus(false)}
        className="absolute inset-0 z-10 h-full w-full cursor-text opacity-0" />
      <div className="flex justify-between gap-2" aria-hidden>
        {Array.from({ length }, (_, i) => {
          const ch = value[i] ?? "", active = focus && (i === value.length || (i === length - 1 && value.length === length));
          return (
            <span key={i} className={`grid h-14 flex-1 place-items-center rounded-xl border-2 bg-background text-[24px] font-bold tabular-nums transition-colors sm:h-16 ${active ? "border-[#2563B3] ring-4 ring-[#2563B3]/15" : ch ? "border-foreground/25" : "border-border"}`}>
              {ch || (active ? <span className="h-6 w-0.5 animate-pulse bg-[#2563B3]" /> : null)}
            </span>
          );
        })}
      </div>
    </div>
  );
}

/** Already on Premium (D-129): the plan and its end date first; buying more time is one tap away. */
export function PremiumNow({ plan, until, onMore }: { plan: string | null; until: string; onMore: () => void }) {
  return (
    <>
      <div className="mt-4 rounded-2xl bg-[#0B1F44] p-5 text-white dark:bg-[#132B55] dark:ring-1 dark:ring-white/10">
        <span className="inline-flex items-center gap-1.5 rounded-lg bg-[#F2B233] px-2.5 py-1 text-xs font-bold text-[#0B1F44]"><Crown size={14} weight="fill" /> Premium</span>
        <h1 className="mt-3 text-[24px] font-bold leading-tight tracking-tight">You are already on Premium</h1>
        <p className="mt-1.5 text-[15px] text-white/75">{plan ? `${plan} plan` : "Your plan"} is active on this account.</p>
        <div className="mt-4 flex items-center gap-3 rounded-xl bg-white/10 px-4 py-3">
          <CalendarCheck size={22} weight="fill" className="shrink-0 text-[#F2B233]" />
          <div className="text-sm">
            <b className="block text-[15px]">Until {day(until)}</b>
            <span className="text-white/70">{daysLeft(until)}</span>
          </div>
        </div>
      </div>
      <a href={APP_HOME} className="mt-5 inline-flex h-13 w-full items-center justify-center gap-2 rounded-2xl bg-[#F2B233] text-[16px] font-bold text-[#0B1F44] transition-transform active:scale-[.98]">
        <ArrowSquareOut size={19} weight="bold" /> Open the SolutionTee app
      </a>
      <button type="button" onClick={onMore} className="mt-3 inline-flex h-12 w-full items-center justify-center gap-2 rounded-2xl border text-sm font-bold hover:bg-muted">
        <Plus size={16} weight="bold" /> Add more time
      </button>
      <p className="mt-4 text-center text-xs leading-5 text-muted-foreground">Premium works on every phone where you log in with this email. Extra time starts after {day(until)}.</p>
    </>
  );
}
