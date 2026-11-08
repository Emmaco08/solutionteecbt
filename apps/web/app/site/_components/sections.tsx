"use client";
import Link from "next/link";
import { AnimatePresence, motion, useInView, useReducedMotion, useScroll, useTransform } from "motion/react";
import { useEffect, useRef, useState } from "react";
import {
  ArrowRight, Books, CaretDown, Check, CloudArrowDown, Crown, DeviceMobile, DownloadSimple, Exam, GooglePlayLogo,
  Lightbulb, ShieldCheck, Sparkle, WifiSlash,
} from "@phosphor-icons/react";
import { CountUp, Reveal, ease } from "./motion";

/* ------------------------------------------------------------------ exam strip */
const EXAMS = [
  ["JAMB", "UTME", "#0B1F44", "#F2B233"],
  ["WAEC", "WASSCE", "#14532D", "#BBF7D0"],
  ["NECO", "SSCE", "#2563B3", "#FFFFFF"],
] as const;

export function ExamStrip({ subjects, studyItems }: { subjects: number; studyItems: number }) {
  return (
    <section className="border-b bg-card py-10">
      <div className="mx-auto flex max-w-6xl flex-col items-center gap-8 px-4 sm:px-6 lg:flex-row lg:justify-between">
        <div className="flex flex-wrap justify-center gap-3">
          {EXAMS.map(([code, exam, bg, fg], i) => (
            <Reveal key={code} delay={0.08 * i}>
              {/* Our own exam badges: plain text names, never the exam bodies' logos */}
              <div className="flex items-center gap-3 rounded-2xl border bg-background px-4 py-3">
                <span className="grid size-11 place-items-center rounded-xl text-xs font-extrabold" style={{ background: bg, color: fg }}>{code}</span>
                <span className="text-sm font-bold">{code} <span className="font-medium text-muted-foreground">{exam}</span></span>
              </div>
            </Reveal>
          ))}
        </div>
        <div className="grid grid-cols-3 gap-6 text-center">
          <div><CountUp to={subjects} className="block text-[28px] font-bold tabular-nums" /><span className="text-xs text-muted-foreground">subjects</span></div>
          <div><CountUp to={studyItems} suffix="+" className="block text-[28px] font-bold tabular-nums" /><span className="text-xs text-muted-foreground">lessons &amp; notes</span></div>
          <div><span className="block text-[28px] font-bold">24/7</span><span className="text-xs text-muted-foreground">AI tutor</span></div>
        </div>
      </div>
    </section>
  );
}

/* ------------------------------------------------------------------ features */
const FEATURES = [
  [WifiSlash, "Works offline", "Download questions and practise without data. Your results sync when you are back online."],
  [CloudArrowDown, "Light on data", "A data saver, small downloads and no heavy videos unless you tap them. Made for Nigerian networks."],
  [Lightbulb, "Question of the day", "One new question every day to keep your brain warm, with a streak to protect."],
  [ShieldCheck, "Safe for students", "No personalised ads for under-18s, a parent notice for 13 to 17, and an AI tutor that only does schoolwork."],
] as const;

export function Features() {
  return (
    <section className="bg-background pb-20 pt-4 sm:pb-28">
      <div className="mx-auto max-w-6xl px-4 sm:px-6">
        <Reveal className="mx-auto max-w-2xl text-center">
          <p className="text-sm font-bold uppercase tracking-wider text-[#2563B3]">And there’s more</p>
          <h2 className="mt-3 text-[32px] font-bold leading-tight tracking-tight sm:text-[40px]">Made for Nigerian students</h2>
        </Reveal>
        <div className="mt-14 grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
          {FEATURES.map(([Icon, title, text], i) => (
            <Reveal key={title} delay={0.05 * (i % 4)}>
              <motion.div whileHover={{ y: -6 }} transition={{ type: "spring", stiffness: 300, damping: 22 }}
                className="group h-full rounded-3xl border bg-card p-6 shadow-[var(--shadow-1)]">
                <span className="grid size-12 place-items-center rounded-2xl bg-[#EEF2F9] text-[#0B1F44] transition-colors group-hover:bg-[#F2B233] dark:bg-white/10 dark:text-white dark:group-hover:text-[#0B1F44]">
                  <Icon size={24} weight="fill" />
                </span>
                <h3 className="mt-5 text-[17px] font-bold">{title}</h3>
                <p className="mt-2 text-sm leading-6 text-muted-foreground">{text}</p>
              </motion.div>
            </Reveal>
          ))}
        </div>
      </div>
    </section>
  );
}

/* ------------------------------------------------------------------ subjects ribbon */
const SUBJECTS = ["Use of English", "Mathematics", "Physics", "Chemistry", "Biology", "Government", "Economics", "Literature in English",
  "Commerce", "Accounting", "Geography", "CRS", "IRS", "Agricultural Science", "History"];

export function SubjectMarquee() {
  const still = useReducedMotion();
  const row = (dir: 1 | -1, list: string[]) => (
    <div className="flex overflow-hidden [mask-image:linear-gradient(90deg,transparent,black_10%,black_90%,transparent)]">
      <motion.div className="flex shrink-0 gap-3 pr-3" animate={still ? undefined : { x: dir === 1 ? ["0%", "-50%"] : ["-50%", "0%"] }} transition={{ duration: 40, repeat: Infinity, ease: "linear" }}>
        {[...list, ...list].map((t, i) => (
          <span key={i} className="whitespace-nowrap rounded-full border bg-card px-4 py-2 text-sm font-bold shadow-[var(--shadow-1)]">{t}</span>
        ))}
      </motion.div>
    </div>
  );
  return (
    <section className="space-y-3 border-b bg-[#F4F6FA] py-8 dark:bg-[#0A1730]" aria-label="Subjects">
      {row(1, SUBJECTS)}
      {row(-1, [...SUBJECTS].reverse())}
    </section>
  );
}

/* ------------------------------------------------------------------ AI tutor */
const CHAT: { me: boolean; text: string }[] = [
  { me: true, text: "I don’t understand how to find the gradient of a line 😩" },
  { me: false, text: "No problem! The gradient tells you how steep a line is. Pick two points on it, (x₁, y₁) and (x₂, y₂)…" },
  { me: false, text: "Then gradient m = (y₂ − y₁) ÷ (x₂ − x₁). For (1, 2) and (3, 8): m = (8 − 2) ÷ (3 − 1) = 3." },
  { me: true, text: "Ohhh. Give me 3 quick questions to try?" },
  { me: false, text: "Here’s a 3-question quiz on gradients ✏️ Ready when you are!" },
];

export function AiShowcase() {
  const ref = useRef<HTMLDivElement>(null);
  const seen = useInView(ref, { once: true, margin: "-120px" });
  const still = useReducedMotion();
  const [n, setN] = useState(still ? CHAT.length : 0);
  useEffect(() => {
    if (!seen || still) return;
    const t = setInterval(() => setN((x) => (x >= CHAT.length ? x : x + 1)), 1100);
    return () => clearInterval(t);
  }, [seen, still]);
  return (
    <section id="ai" className="scroll-mt-20 overflow-hidden bg-[#0B1F44] py-20 text-white sm:py-28">
      <div className="mx-auto grid max-w-6xl items-center gap-12 px-4 sm:px-6 lg:grid-cols-2">
        <Reveal>
          <p className="text-sm font-bold uppercase tracking-wider text-[#F2B233]">SolutionTee AI tutor</p>
          <h2 className="mt-3 text-[32px] font-bold leading-tight tracking-tight sm:text-[40px]">Like a patient teacher in your pocket</h2>
          <p className="mt-4 text-[17px] leading-7 text-[#C9D5EA]">Ask anything from your syllabus, any time. It explains step by step, quotes your notes, builds quick quizzes and study plans, and reminds you to practise.</p>
          <ul className="mt-6 space-y-3">
            {["Snap a photo of a question and get the working", "Quizzes and study plans made for your weak topics", "Only helps with schoolwork: safe for students"].map((t) => (
              <li key={t} className="flex items-start gap-3 text-[15px]"><span className="mt-0.5 grid size-6 shrink-0 place-items-center rounded-full bg-[#F2B233] text-[#0B1F44]"><Check size={14} weight="bold" /></span>{t}</li>
            ))}
          </ul>
        </Reveal>
        <div ref={ref} className="relative mx-auto w-full max-w-md rounded-[32px] border border-white/10 bg-[#06132B] p-5 shadow-2xl">
          <div className="mb-4 flex items-center gap-3 border-b border-white/10 pb-4">
            <span className="grid size-10 place-items-center rounded-2xl bg-[#F2B233] text-[#0B1F44]"><Sparkle size={20} weight="fill" /></span>
            <div><p className="text-sm font-bold">AI tutor</p><p className="text-xs text-[#8FA2C4]">Mathematics · Coordinate geometry</p></div>
          </div>
          <div className="flex min-h-[340px] flex-col gap-3">
            <AnimatePresence>
              {CHAT.slice(0, n).map((m, i) => (
                <motion.p key={i} initial={{ opacity: 0, y: 12, scale: 0.96 }} animate={{ opacity: 1, y: 0, scale: 1 }} transition={{ duration: 0.4, ease }}
                  className={`max-w-[85%] rounded-2xl px-4 py-2.5 text-sm leading-6 ${m.me ? "self-end rounded-br-md bg-[#2563B3]" : "self-start rounded-bl-md bg-white/10"}`}>{m.text}</motion.p>
              ))}
            </AnimatePresence>
            {n < CHAT.length && n > 0 && !CHAT[n]?.me ? (
              <span className="flex gap-1 self-start rounded-2xl bg-white/10 px-4 py-3" aria-hidden>
                {[0, 1, 2].map((d) => <motion.span key={d} className="size-1.5 rounded-full bg-white/70" animate={{ opacity: [0.3, 1, 0.3] }} transition={{ duration: 1, repeat: Infinity, delay: d * 0.15 }} />)}
              </span>
            ) : null}
          </div>
        </div>
      </div>
    </section>
  );
}

/* ------------------------------------------------------------------ how it works */
const STEP_ICONS = [DeviceMobile, Books, Exam] as const;

export function HowItWorks({ title, steps }: { title: string; steps: { title: string; text: string }[] }) {
  const ref = useRef<HTMLDivElement>(null);
  const { scrollYProgress } = useScroll({ target: ref, offset: ["start 80%", "end 60%"] });
  const width = useTransform(scrollYProgress, [0, 1], ["0%", "100%"]);
  return (
    <section className="bg-background py-20 sm:py-24">
      <div className="mx-auto max-w-6xl px-4 sm:px-6">
        <Reveal className="text-center"><h2 className="text-[32px] font-bold tracking-tight sm:text-[40px]">{title}</h2></Reveal>
        <div ref={ref} className="relative mt-14 grid gap-10 md:grid-cols-3">
          <div className="absolute left-[16%] right-[16%] top-7 hidden h-1 rounded-full bg-border md:block" aria-hidden>
            <motion.div style={{ width }} className="h-full rounded-full bg-[#F2B233]" />
          </div>
          {steps.map(({ title, text }, i) => {
            const Icon = STEP_ICONS[i % STEP_ICONS.length]!;
            return (
            <Reveal key={i} delay={0.1 * i} className="relative text-center">
              <span className="relative mx-auto grid size-14 place-items-center rounded-2xl bg-[#0B1F44] text-white shadow-lg"><Icon size={26} weight="fill" /></span>
              <p className="mt-2 text-xs font-bold text-[#2563B3]">Step {i + 1}</p>
              <h3 className="mt-1 text-lg font-bold">{title}</h3>
              <p className="mx-auto mt-2 max-w-xs text-sm leading-6 text-muted-foreground">{text}</p>
            </Reveal>
            );
          })}
        </div>
      </div>
    </section>
  );
}

/* ------------------------------------------------------------------ pricing */
export type PricePlan = { code: string; name: string; description: string | null; price: number; fee: number; period: string };
const ng = (n: number) => `₦${n.toLocaleString("en-NG")}`;

export function Pricing({ plans }: { plans: PricePlan[] }) {
  const best = plans.find((p) => p.code === "three_months")?.code ?? plans[1]?.code;
  return (
    <section id="pricing" className="scroll-mt-20 bg-[#F4F6FA] py-20 dark:bg-[#0A1730] sm:py-28">
      <div className="mx-auto max-w-6xl px-4 sm:px-6">
        <Reveal className="mx-auto max-w-2xl text-center">
          <p className="text-sm font-bold uppercase tracking-wider text-[#2563B3]">Premium</p>
          <h2 className="mt-3 text-[32px] font-bold leading-tight tracking-tight sm:text-[40px]">Free to start. Premium when you’re ready.</h2>
          <p className="mt-4 text-[17px] leading-7 text-muted-foreground">Practise free every day. Premium opens every year, video solution and lesson. Pay once, no auto-renew.</p>
        </Reveal>
        {plans.length === 0 ? (
          <p className="mt-10 text-center"><Link href="/pay" className="inline-flex h-12 items-center gap-2 rounded-2xl bg-[#0B1F44] px-6 font-bold text-white dark:bg-white dark:text-[#0B1F44]">See plans and prices <ArrowRight size={16} weight="bold" /></Link></p>
        ) : null}
        <div className="mt-14 grid gap-5 md:grid-cols-3">
          {plans.map((p, i) => {
            const hot = p.code === best;
            return (
              <Reveal key={p.code} delay={0.08 * i}>
                <motion.div whileHover={{ y: -6 }} className={`relative flex h-full flex-col rounded-3xl border p-7 ${hot ? "border-[#F2B233] bg-[#0B1F44] text-white shadow-2xl" : "bg-card shadow-[var(--shadow-1)]"}`}>
                  {hot ? <span className="absolute -top-3 left-7 inline-flex items-center gap-1 rounded-full bg-[#F2B233] px-3 py-1 text-xs font-bold text-[#0B1F44]"><Crown size={14} weight="fill" /> Most popular</span> : null}
                  <h3 className="text-lg font-bold">{p.name}</h3>
                  <p className="mt-1 text-sm opacity-75">{p.period}</p>
                  <p className="mt-5 text-[40px] font-bold leading-none tabular-nums">{ng(p.price)}</p>
                  {p.fee > 0 ? <p className="mt-2 text-xs opacity-75">+ {ng(p.fee)} payment processing fee</p> : null}
                  {p.description ? <p className={`mt-4 text-sm leading-6 ${hot ? "text-[#C9D5EA]" : "text-muted-foreground"}`}>{p.description}</p> : null}
                  <div className="grow" />
                  <Link href={`/pay?plan=${encodeURIComponent(p.code)}`}
                    className={`mt-7 inline-flex h-12 items-center justify-center gap-2 rounded-2xl font-bold transition-transform hover:-translate-y-0.5 ${hot ? "bg-[#F2B233] text-[#0B1F44]" : "bg-[#0B1F44] text-white dark:bg-white dark:text-[#0B1F44]"}`}>
                    Get {p.name} <ArrowRight size={16} weight="bold" />
                  </Link>
                </motion.div>
              </Reveal>
            );
          })}
        </div>
        <Reveal className="mt-8 flex flex-wrap items-center justify-center gap-x-6 gap-y-2 text-sm text-muted-foreground">
          <span className="inline-flex items-center gap-1.5"><ShieldCheck size={18} weight="fill" className="text-[#16A34A]" /> Secure payments by Paystack</span>
          <span>Card · Bank transfer · USSD · OPay and other apps</span>
        </Reveal>
      </div>
    </section>
  );
}

/* ------------------------------------------------------------------ download */
export function Download({ playUrl, title, text }: { playUrl: string; title: string; text: string }) {
  return (
    <section id="download" className="scroll-mt-20 bg-background py-20 sm:py-24">
      <div className="mx-auto max-w-6xl px-4 sm:px-6">
        <Reveal>
          <div className="relative overflow-hidden rounded-[36px] bg-[#0B1F44] px-6 py-14 text-center text-white sm:px-12">
            <div className="pointer-events-none absolute -right-20 -top-20 size-72 rounded-full bg-[#F2B233]/25 blur-3xl" aria-hidden />
            <div className="pointer-events-none absolute -bottom-24 -left-16 size-72 rounded-full bg-[#2563B3]/40 blur-3xl" aria-hidden />
            <h2 className="relative text-[32px] font-bold tracking-tight sm:text-[40px]">{title}</h2>
            <p className="relative mx-auto mt-4 max-w-xl text-[17px] text-[#C9D5EA]">{text}</p>
            <div className="relative mt-8 flex flex-col justify-center gap-3 sm:flex-row">
              {playUrl ? (
                <a href={playUrl} className="inline-flex h-14 items-center justify-center gap-2.5 rounded-2xl bg-white px-6 font-bold text-[#0B1F44] transition-transform hover:-translate-y-0.5"><GooglePlayLogo size={24} weight="fill" /> Get it on Google Play</a>
              ) : (
                <span className="inline-flex h-14 items-center justify-center gap-2.5 rounded-2xl border border-white/25 px-6 font-bold text-white/80"><GooglePlayLogo size={24} weight="fill" /> Google Play: coming soon</span>
              )}
              <a href="/download/apk" className="inline-flex h-14 items-center justify-center gap-2.5 rounded-2xl bg-[#F2B233] px-6 font-bold text-[#0B1F44] transition-transform hover:-translate-y-0.5"><DownloadSimple size={22} weight="bold" /> Download the APK</a>
            </div>
            <p className="relative mt-4 text-xs text-[#8FA2C4]">The APK is the same app with Paystack inside (card, transfer, USSD, OPay). If Android asks, allow “Install unknown apps” for your browser.</p>
          </div>
        </Reveal>
      </div>
    </section>
  );
}

/* ------------------------------------------------------------------ FAQ */
export type FaqItem = { q: string; a: string };

export function Faq({ title, items }: { title: string; items: FaqItem[] }) {
  const [open, setOpen] = useState<number | null>(0);
  return (
    <section id="faq" className="scroll-mt-20 bg-[#F4F6FA] py-20 dark:bg-[#0A1730] sm:py-24">
      <div className="mx-auto max-w-3xl px-4 sm:px-6">
        <Reveal className="text-center"><h2 className="text-[32px] font-bold tracking-tight sm:text-[40px]">{title}</h2></Reveal>
        <div className="mt-10 space-y-3">
          {items.map(({ q, a }, i) => (
            <Reveal key={q} delay={0.03 * i}>
              <div className="rounded-2xl border bg-card">
                <button type="button" className="flex w-full items-center justify-between gap-4 px-5 py-4 text-left font-bold" aria-expanded={open === i} onClick={() => setOpen(open === i ? null : i)}>
                  {q}
                  <motion.span animate={{ rotate: open === i ? 180 : 0 }} className="shrink-0"><CaretDown size={18} weight="bold" /></motion.span>
                </button>
                <AnimatePresence initial={false}>
                  {open === i ? (
                    <motion.div initial={{ height: 0, opacity: 0 }} animate={{ height: "auto", opacity: 1 }} exit={{ height: 0, opacity: 0 }} transition={{ duration: 0.3, ease }} className="overflow-hidden">
                      <p className="px-5 pb-5 text-[15px] leading-7 text-muted-foreground">{a}</p>
                    </motion.div>
                  ) : null}
                </AnimatePresence>
              </div>
            </Reveal>
          ))}
        </div>
      </div>
    </section>
  );
}

/* ------------------------------------------------------------------ footer */
export function SiteFooter({ tagline = "Learn. Think. Solve." }: { tagline?: string }) {
  return (
    <footer className="bg-[#06132B] py-12 text-[#8FA2C4]">
      <div className="mx-auto flex max-w-6xl flex-col gap-8 px-4 sm:px-6 md:flex-row md:justify-between">
        <div className="max-w-sm">
          <div className="flex items-center gap-2.5 text-white">
            {/* eslint-disable-next-line @next/next/no-img-element */}
            <img src="/brand/favicon.svg" alt="" className="size-9 rounded-xl" />
            <span className="text-[17px] font-bold">SolutionTee <span className="text-[#F2B233]">CBT</span></span>
          </div>
          <p className="mt-3 text-sm">{tagline}</p>
          <p className="mt-4 text-xs leading-5">SOLUTIONTEE EDUTECH AND ICT SERVICES, a registered Business Name, RC 9123561. Diamond Estate, 1 Obashoro St, off Command Road, Ipaja, Lagos.</p>
        </div>
        <div className="grid grid-cols-2 gap-8 text-sm">
          <div className="flex flex-col gap-2">
            <b className="text-white">App</b>
            <a href="#features" className="hover:text-white">Features</a>
            <a href="#pricing" className="hover:text-white">Pricing</a>
            <Link href="/pay" className="hover:text-white">Pay for Premium</Link>
            <a href="/download/apk" className="hover:text-white">Download APK</a>
          </div>
          <div className="flex flex-col gap-2">
            <b className="text-white">Help</b>
            <a href="mailto:support@mail.solutiontee.com" className="hover:text-white">support@mail.solutiontee.com</a>
            <a href="https://wa.me/2348122445948" className="hover:text-white">WhatsApp +234 812 244 5948</a>
          </div>
        </div>
      </div>
      <p className="mx-auto mt-10 max-w-6xl px-4 text-xs leading-5 sm:px-6">SolutionTee CBT is an independent exam-practice platform and is not affiliated with or endorsed by JAMB, WAEC or NECO. © 2026 SolutionTee.</p>
    </footer>
  );
}
