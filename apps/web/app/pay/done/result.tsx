"use client";
import Link from "next/link";
import { motion, useReducedMotion } from "motion/react";
import { useEffect, useState } from "react";
import { ArrowRight, ArrowSquareOut, Check, Copy, EnvelopeSimple, ShieldCheck, WarningCircle } from "@phosphor-icons/react";
import { createClient } from "@/lib/supabase/client";
import { payStatus, type PayStatus } from "./status";

/** The app's own link back (D-116). Chrome needs the intent: form; the plain scheme is the fallback for other browsers. */
function appLink(reference: string, plan?: string, kind?: string) {
  const q = `ref=${encodeURIComponent(reference)}${plan ? `&plan=${encodeURIComponent(plan)}` : ""}${kind === "tutor" ? "&kind=tutor" : ""}`;
  const android = typeof navigator !== "undefined" && /Android/i.test(navigator.userAgent);
  return android ? `intent://app/paid?${q}#Intent;scheme=solutiontee;package=com.solutiontee.cbt;end` : `solutiontee://app/paid?${q}`;
}

const ng = (kobo: number) => `₦${(kobo / 100).toLocaleString("en-NG")}`;
const longDay = (s: string) => new Date(s).toLocaleDateString("en-NG", { day: "numeric", month: "long", year: "numeric" });
const ease = [0.22, 1, 0.36, 1] as const;

/** Checks every 3 s for up to 3 minutes. Each check asks Paystack itself (D-129), so it never waits for the webhook. */
export function PayResult({ reference, initial }: { reference: string; initial: PayStatus }) {
  const [s, setS] = useState(initial);
  const [tries, setTries] = useState(0);
  const still = useReducedMotion();
  const [fromApp, setFromApp] = useState(false);
  const [copied, setCopied] = useState(false);

  // Paid: the payment tab is cleared and this browser logs out (this browser only: the app stays logged in). Opened from
  // the app: straight back into the app, which shows its own "Premium is on" screen after checking with the server.
  useEffect(() => {
    if (s.status !== "success") return;
    let app = false;
    try { sessionStorage.removeItem("st-pay-pending"); app = sessionStorage.getItem("st-from-app") === "1"; sessionStorage.removeItem("st-from-app"); } catch {}
    void createClient().auth.signOut({ scope: "local" });
    if (!app) return;
    queueMicrotask(() => setFromApp(true));
    // A tutor plan counts down 3, 2, 1 on screen, then opens the app's tutor screen (D-153).
    const t = setTimeout(() => window.location.assign(appLink(reference, s.plan, s.kind)), s.kind === "tutor" ? 3000 : 2200);
    return () => clearTimeout(t);
  }, [s.status, s.plan, s.kind, reference]);
  const [count, setCount] = useState(3);
  useEffect(() => {
    if (!fromApp || s.kind !== "tutor") return;
    const t = setInterval(() => setCount((n) => Math.max(0, n - 1)), 1000);
    return () => clearInterval(t);
  }, [fromApp, s.kind]);

  useEffect(() => {
    if (s.status !== "pending" && s.status !== "abandoned" && s.status !== "unknown") return;
    if (tries > 60) return;
    const t = setTimeout(async () => { setS(await payStatus(reference)); setTries((n) => n + 1); }, tries < 10 ? 3000 : 5000);
    return () => clearTimeout(t);
  }, [s, tries, reference]);

  const rise = (d = 0) => (still ? {} : { initial: { opacity: 0, y: 10 }, animate: { opacity: 1, y: 0 }, transition: { duration: 0.4, delay: d, ease } });

  if (s.status === "success" && s.kind === "tutor") {
    const rows: [string, React.ReactNode][] = [
      ["Plan", [s.tutor_plan, s.sessions ? `${s.sessions} lessons` : null].filter(Boolean).join(" · ") || "Tutor plan"],
      ...(s.tutor_until ? [["Runs until", longDay(s.tutor_until)] as [string, React.ReactNode]] : []),
      ...(s.amount_kobo ? [["Amount paid", ng(s.amount_kobo)] as [string, React.ReactNode]] : []),
      ["Receipt", <span key="r" className="font-mono text-[13px]">{reference.slice(0, 7)}…{reference.slice(-3)}</span>],
    ];
    return (
      <div>
        <div className="flex flex-col items-center text-center">
          <SuccessMark still={Boolean(still)} />
          <motion.p {...rise(0.15)} className="mt-5 text-sm font-bold text-success">Payment confirmed{s.amount_kobo ? ` · ${ng(s.amount_kobo)}` : ""}</motion.p>
          <motion.h1 {...rise(0.2)} className="mt-1 text-[26px] font-bold leading-tight tracking-tight">Your tutor plan is on</motion.h1>
          <motion.p {...rise(0.25)} className="mt-2 max-w-sm text-[15px] leading-6 text-muted-foreground">We will match you with a tutor within 24 hours. Your app shows it the moment a tutor is assigned.</motion.p>
        </div>
        {fromApp ? (
          <motion.div {...rise(0.3)} className="mt-6 flex items-center gap-3 rounded-2xl bg-[#EEF3FB] p-3.5 dark:bg-[#10284D]">
            <span className="relative grid size-11 shrink-0 place-items-center">
              <svg viewBox="0 0 44 44" className="absolute inset-0 -rotate-90" aria-hidden>
                <circle cx="22" cy="22" r="19" fill="none" strokeWidth="4" className="stroke-[#D3DEEF] dark:stroke-[#1C2D4A]" />
                <motion.circle cx="22" cy="22" r="19" fill="none" strokeWidth="4" strokeLinecap="round" className="stroke-[#0B1F44] dark:stroke-[#F2B233]"
                  initial={{ pathLength: 0 }} animate={{ pathLength: 1 }} transition={{ duration: still ? 0 : 3, ease: "linear" }} />
              </svg>
              <b className="relative text-base tabular-nums" aria-live="polite">{count}</b>
            </span>
            <span><b className="block text-[15px]">Opening the app…</b><span className="text-[13px] text-muted-foreground">Your tutor screen opens by itself</span></span>
          </motion.div>
        ) : null}
        <motion.div {...rise(0.35)}>
          <a href={appLink(reference, s.plan, "tutor")} className="mt-4 inline-flex h-13 w-full items-center justify-center gap-2 rounded-2xl bg-[#0B1F44] px-6 text-[16px] font-bold text-white transition-transform active:scale-[.98] dark:bg-[#F2B233] dark:text-[#0B1F44]">
            <ArrowSquareOut size={19} weight="bold" /> Open SolutionTee app
          </a>
          <Link href="/tutor" className="mt-2 inline-flex h-12 w-full items-center justify-center rounded-2xl text-sm font-bold text-muted-foreground hover:text-foreground">See my tutor page</Link>
        </motion.div>
        <motion.dl {...rise(0.4)} className="mt-4 divide-y rounded-2xl border bg-muted/40 px-4 text-sm">
          {rows.map(([k, v]) => (
            <div key={k} className="flex items-center justify-between gap-4 py-3">
              <dt className="text-muted-foreground">{k}</dt>
              <dd className="min-w-0 truncate text-right font-bold">{v}</dd>
            </div>
          ))}
        </motion.dl>
        <motion.p {...rise(0.45)} className="mt-3 text-center text-xs leading-5 text-muted-foreground">
          <EnvelopeSimple size={15} className="mr-1 inline align-[-3px]" />A receipt has been sent to your email.
        </motion.p>
      </div>
    );
  }

  if (s.status === "success") {
    const what = s.kind === "xp" ? "Your XP has been added" : s.kind === "class" ? "You are in the class" : s.kind === "tutor" ? "Your tutor plan is on" : s.kind === "item" ? "Unlocked on your account" : "Premium is now on";
    const rows: [string, React.ReactNode][] = [
      ...(s.plan ? [["Plan", s.plan] as [string, React.ReactNode]] : []),
      ...(s.until ? [["Premium until", longDay(s.until)] as [string, React.ReactNode]] : []),
      ...(s.amount_kobo !== undefined ? [["Amount paid", s.amount_kobo > 0 ? ng(s.amount_kobo) : "Free (discount code)"] as [string, React.ReactNode]] : []),
      ["Reference", (
        <button key="ref" type="button" title="Copy" onClick={() => { navigator.clipboard?.writeText(reference).then(() => { setCopied(true); setTimeout(() => setCopied(false), 1500); }).catch(() => {}); }}
          className="inline-flex items-center gap-1.5 font-mono text-[13px] hover:text-foreground">
          {reference}{copied ? <Check size={14} weight="bold" className="text-success" /> : <Copy size={14} />}
        </button>
      )],
    ];
    return (
      <div>
        <div className="flex flex-col items-center text-center">
          <SuccessMark still={Boolean(still)} />
          <motion.p {...rise(0.15)} className="mt-5 text-sm font-bold text-success">Payment successful</motion.p>
          <motion.h1 {...rise(0.2)} className="mt-1 text-[26px] font-bold leading-tight tracking-tight">{what}</motion.h1>
          <motion.p {...rise(0.25)} className="mt-2 max-w-sm text-[15px] leading-6 text-muted-foreground">
            {fromApp ? "Taking you back to the app…" : s.kind === "class" ? "We will remind you in the app before it starts. Join from My classes or the app." : s.kind === "tutor" ? "A tutor will be assigned to you within 24 hours. Chat with them in the SolutionTee app: Study → My tutor." : "Open the SolutionTee app and log in with the same email. Premium is already there."}
          </motion.p>
        </div>

        <motion.dl {...rise(0.3)} className="mt-6 divide-y rounded-2xl border bg-muted/40 px-4 text-sm">
          {rows.map(([k, v]) => (
            <div key={k} className="flex items-center justify-between gap-4 py-3">
              <dt className="text-muted-foreground">{k}</dt>
              <dd className="min-w-0 truncate text-right font-bold">{v}</dd>
            </div>
          ))}
        </motion.dl>

        <motion.div {...rise(0.35)}>
          <a href={appLink(reference, s.plan)} className="relative mt-6 inline-flex h-13 w-full items-center justify-center gap-2 overflow-hidden rounded-2xl bg-[#F2B233] px-6 text-[16px] font-bold text-[#0B1F44] transition-transform active:scale-[.98]">
            {fromApp && !still ? <motion.span aria-hidden className="absolute inset-y-0 left-0 bg-black/10" initial={{ width: "0%" }} animate={{ width: "100%" }} transition={{ duration: 2.2, ease: "linear" }} /> : null}
            <ArrowSquareOut size={19} weight="bold" className="relative" /> <span className="relative">Open the SolutionTee app</span>
          </a>
          {s.kind === "class" ? <Link href="/classes/me" className="mt-2 inline-flex h-12 w-full items-center justify-center rounded-2xl border text-sm font-bold">Open My classes</Link> : null}
          <Link href="/" className="mt-2 inline-flex h-12 w-full items-center justify-center rounded-2xl text-sm font-bold text-muted-foreground hover:text-foreground">Back to the website</Link>
        </motion.div>

        <motion.p {...rise(0.4)} className="mt-3 border-t pt-4 text-center text-xs leading-5 text-muted-foreground">
          <EnvelopeSimple size={15} className="mr-1 inline align-[-3px]" />We emailed you a receipt. Questions? support@mail.solutiontee.com
        </motion.p>
      </div>
    );
  }

  if (s.status === "failed") {
    return (
      <Notice tone="error" title="The payment did not go through" text="No money was taken. You can try again, or choose another way to pay on Paystack.">
        <Link href="/pay" className="mt-6 inline-flex h-12 w-full items-center justify-center gap-2 rounded-2xl bg-[#F2B233] px-6 font-bold text-[#0B1F44]">Try again <ArrowRight size={16} weight="bold" /></Link>
      </Notice>
    );
  }
  if (s.status === "needs_review" || s.status === "refunded") {
    return (
      <Notice tone="warning" title={s.status === "refunded" ? "This payment was refunded" : "We are checking this payment"}
        text={s.status === "refunded" ? "The money went back to you." : "Our team will look at it and email you within one working day. You do not need to pay again."}>
        <p className="mt-4 text-center text-sm text-muted-foreground">Questions? support@mail.solutiontee.com</p>
      </Notice>
    );
  }

  // Waiting: three plain steps, so the student can see something is happening.
  const late = tries > 60;
  return (
    <div className="text-center">
      <div className="relative mx-auto grid size-20 place-items-center">
        <span className="absolute inset-0 rounded-full border-4 border-[#2563B3]/15" />
        <span className={`absolute inset-0 rounded-full border-4 border-transparent border-t-[#2563B3] ${still ? "" : "animate-spin"}`} />
        <ShieldCheck size={32} weight="fill" className="text-[#2563B3] dark:text-[#5B8DEF]" />
      </div>
      <h1 className="mt-5 text-2xl font-bold tracking-tight">{late ? "Still waiting for your bank" : "Confirming your payment"}</h1>
      <p className="mx-auto mt-2 max-w-sm text-[15px] leading-6 text-muted-foreground">
        {late ? "Premium turns on by itself as soon as the money arrives, even if you close this page. You do not need to pay again."
          : "We are checking with Paystack. This usually takes a few seconds. Paid by bank transfer? It can take a few minutes."}
      </p>
      <ol className="mx-auto mt-6 max-w-xs space-y-3 text-left text-sm">
        {["Payment sent to Paystack", "Checking with Paystack", "Turning on Premium"].map((t, i) => (
          <li key={t} className="flex items-center gap-3">
            <span className={`grid size-6 shrink-0 place-items-center rounded-full text-[11px] font-bold ${i === 0 ? "bg-success text-white" : i === 1 ? "bg-[#2563B3] text-white" : "bg-muted text-muted-foreground"}`}>
              {i === 0 ? <Check size={13} weight="bold" /> : i + 1}
            </span>
            <span className={i === 2 ? "text-muted-foreground" : "font-bold"}>{t}</span>
          </li>
        ))}
      </ol>
      {tries >= 8 ? (
        <Link href="/pay" className="mt-7 inline-flex h-11 items-center justify-center rounded-2xl border px-5 text-sm font-bold">Cancelled on Paystack? Go back</Link>
      ) : null}
    </div>
  );
}

/** A green ring that draws itself, then the tick (a plain fade when the phone asks for less motion). */
function SuccessMark({ still }: { still: boolean }) {
  return (
    <span className="relative grid size-[88px] place-items-center rounded-full bg-success-soft">
      <svg viewBox="0 0 88 88" className="absolute inset-0 size-full -rotate-90 text-success" aria-hidden>
        <motion.circle cx="44" cy="44" r="41" fill="none" stroke="currentColor" strokeWidth="3" strokeLinecap="round"
          initial={still ? false : { pathLength: 0 }} animate={{ pathLength: 1 }} transition={{ duration: 0.6, ease }} />
      </svg>
      <motion.span initial={still ? false : { scale: 0.3, opacity: 0 }} animate={{ scale: 1, opacity: 1 }} transition={{ delay: 0.35, type: "spring", stiffness: 320, damping: 18 }}
        className="grid size-14 place-items-center rounded-full bg-success text-white">
        <Check size={30} weight="bold" />
      </motion.span>
    </span>
  );
}

function Notice({ tone, title, text, children }: { tone: "error" | "warning"; title: string; text: string; children?: React.ReactNode }) {
  return (
    <div className="text-center">
      <span className={`mx-auto grid size-20 place-items-center rounded-full ${tone === "error" ? "bg-error-soft text-on-error-soft" : "bg-warning-soft text-on-warning-soft"}`}>
        <WarningCircle size={40} weight="fill" />
      </span>
      <h1 className="mt-5 text-2xl font-bold tracking-tight">{title}</h1>
      <p className="mx-auto mt-2 max-w-sm text-[15px] leading-6 text-muted-foreground">{text}</p>
      {children}
    </div>
  );
}
