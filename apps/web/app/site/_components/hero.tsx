"use client";
import Link from "next/link";
import { AnimatePresence, motion, useReducedMotion, useScroll, useTransform } from "motion/react";
import { useEffect, useRef, useState } from "react";
import { ArrowRight, CheckCircle, DownloadSimple, GooglePlayLogo, Sparkle, Timer } from "@phosphor-icons/react";
import { ease } from "./motion";

/** One made-up practice question (our own, not from an exam paper) that answers itself in a loop. */
const Q = { text: "If 2x + 3 = 11, what is the value of x?", options: ["3", "4", "5", "7"], right: 1, why: "2x = 11 − 3 = 8, so x = 8 ÷ 2 = 4." };

function PhoneDemo() {
  const still = useReducedMotion();
  const [step, setStep] = useState(still ? 3 : 0); // 0 question, 1 tapped, 2 marked, 3 explanation
  const [secs, setSecs] = useState(28 * 60 + 41);
  useEffect(() => {
    if (still) return;
    const t = setInterval(() => setSecs((s) => (s > 0 ? s - 1 : 0)), 1000);
    const order = [1800, 900, 1100, 3200];
    let i = 0;
    let h: ReturnType<typeof setTimeout>;
    const next = () => {
      h = setTimeout(() => { setStep((s) => (s + 1) % 4); i++; next(); }, order[i % 4]);
    };
    next();
    return () => { clearInterval(t); clearTimeout(h); };
  }, [still]);
  const mm = String(Math.floor(secs / 60)).padStart(2, "0"), ss = String(secs % 60).padStart(2, "0");
  return (
    <div className="relative mx-auto w-[280px] sm:w-[300px]">
      <div className="absolute -inset-10 rounded-full bg-[radial-gradient(circle,rgba(242,178,51,.28),transparent_65%)] blur-2xl" aria-hidden />
      <div className="relative rounded-[44px] border border-white/15 bg-[#0B1F44] p-3 shadow-[0_40px_80px_-20px_rgba(0,0,0,.6)]">
        <div className="overflow-hidden rounded-[34px] bg-[#F4F6FA]">
          <div className="flex items-center justify-between bg-[#0B1F44] px-4 pb-3 pt-6 text-white">
            <div>
              <p className="text-[11px] font-medium text-[#C9D5EA]">JAMB practice · Mathematics</p>
              <p className="text-sm font-bold">Question 12 of 40</p>
            </div>
            <span className="inline-flex items-center gap-1 rounded-full bg-white/10 px-2.5 py-1 text-xs font-bold tabular-nums"><Timer size={14} weight="fill" className="text-[#F2B233]" />{mm}:{ss}</span>
          </div>
          <div className="h-1.5 bg-[#DCE3EF]"><div className="h-full w-[30%] rounded-r-full bg-[#2563B3]" /></div>
          <div className="space-y-2.5 p-4">
            <p className="text-[15px] font-bold leading-snug text-[#06132B]">{Q.text}</p>
            {Q.options.map((o, i) => {
              const picked = step >= 1 && i === Q.right;
              const marked = step >= 2 && i === Q.right;
              return (
                <motion.div key={o} animate={{ scale: picked && step === 1 ? 0.98 : 1 }}
                  className={`flex items-center gap-3 rounded-2xl border-2 px-3 py-2.5 text-sm font-bold transition-colors duration-300 ${marked ? "border-[#16A34A] bg-[#E8F7EE] text-[#14532D]" : picked ? "border-[#2563B3] bg-[#EEF4FC] text-[#0B1F44]" : "border-[#DCE3EF] bg-white text-[#06132B]"}`}>
                  <span className={`grid size-7 place-items-center rounded-lg text-xs ${marked ? "bg-[#16A34A] text-white" : picked ? "bg-[#2563B3] text-white" : "bg-[#EEF2F9] text-[#4F5B70]"}`}>{"ABCD"[i]}</span>
                  {o}
                  {marked ? <CheckCircle size={18} weight="fill" className="ml-auto text-[#16A34A]" /> : null}
                </motion.div>
              );
            })}
            <AnimatePresence>
              {step === 3 ? (
                <motion.div initial={{ opacity: 0, y: 8 }} animate={{ opacity: 1, y: 0 }} exit={{ opacity: 0 }} transition={{ duration: 0.4, ease }}
                  className="rounded-2xl bg-[#0B1F44] p-3 text-[13px] leading-snug text-white">
                  <p className="mb-1 flex items-center gap-1 text-xs font-bold text-[#F2B233]"><Sparkle size={14} weight="fill" /> Explanation</p>
                  {Q.why}
                </motion.div>
              ) : null}
            </AnimatePresence>
          </div>
        </div>
      </div>
    </div>
  );
}

export function Hero({ questions, firstYear, lastYear, playUrl }: { questions: number; firstYear: number; lastYear: number; playUrl: string }) {
  const ref = useRef<HTMLElement>(null);
  const still = useReducedMotion();
  const { scrollYProgress } = useScroll({ target: ref, offset: ["start start", "end start"] });
  const phoneY = useTransform(scrollYProgress, [0, 1], [0, still ? 0 : 120]);
  const words = ["Practise", "like", "it’s", "the", "real", "exam."];
  return (
    <section ref={ref} className="relative overflow-hidden bg-[#06132B] pb-20 pt-28 text-white sm:pt-32 lg:pb-28">
      <div className="pointer-events-none absolute inset-0 bg-[linear-gradient(rgba(255,255,255,.04)_1px,transparent_1px),linear-gradient(90deg,rgba(255,255,255,.04)_1px,transparent_1px)] bg-[size:44px_44px] [mask-image:radial-gradient(ellipse_at_top,black_30%,transparent_75%)]" aria-hidden />
      <div className="pointer-events-none absolute -left-40 top-20 size-[480px] rounded-full bg-[#2563B3]/30 blur-[120px]" aria-hidden />
      <div className="relative mx-auto grid max-w-6xl items-center gap-14 px-4 sm:px-6 lg:grid-cols-[1.1fr_.9fr]">
        <div>
          <motion.p initial={still ? false : { opacity: 0, y: 10 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 0.5, ease }}
            className="mb-5 inline-flex items-center gap-2 rounded-full border border-white/15 bg-white/5 px-3 py-1.5 text-xs font-bold text-[#F2B233]">
            <Sparkle size={14} weight="fill" /> JAMB · WAEC · NECO CBT practice
          </motion.p>
          <h1 className="text-[40px] font-bold leading-[1.08] tracking-tight sm:text-[56px]">
            {words.map((w, i) => (
              <motion.span key={i} className={`mr-[0.25em] inline-block ${i >= 4 ? "text-[#F2B233]" : ""}`}
                initial={still ? false : { opacity: 0, y: 28, filter: "blur(6px)" }} animate={{ opacity: 1, y: 0, filter: "blur(0px)" }}
                transition={{ duration: 0.6, delay: 0.08 * i, ease }}>{w}</motion.span>
            ))}
          </h1>
          <motion.p initial={still ? false : { opacity: 0, y: 12 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 0.6, delay: 0.5, ease }}
            className="mt-5 max-w-xl text-[17px] leading-7 text-[#C9D5EA]">
            {questions.toLocaleString("en-NG")}+ past questions from {firstYear} to {lastYear}, a timed CBT that feels like exam day, every answer explained,
            and an AI tutor that helps you understand. Learn. Think. Solve.
          </motion.p>
          <motion.div initial={still ? false : { opacity: 0, y: 12 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 0.6, delay: 0.65, ease }}
            className="mt-8 flex flex-col gap-3 sm:flex-row">
            {playUrl ? (
              <a href={playUrl} className="inline-flex h-14 items-center justify-center gap-2.5 rounded-2xl bg-white px-6 font-bold text-[#0B1F44] transition-transform hover:-translate-y-0.5">
                <GooglePlayLogo size={24} weight="fill" /> Get it on Google Play
              </a>
            ) : (
              <span className="inline-flex h-14 items-center justify-center gap-2.5 rounded-2xl border border-white/20 px-6 font-bold text-white/80">
                <GooglePlayLogo size={24} weight="fill" /> Google Play: coming soon
              </span>
            )}
            <a href="/download/apk" className="inline-flex h-14 items-center justify-center gap-2.5 rounded-2xl bg-[#F2B233] px-6 font-bold text-[#0B1F44] transition-transform hover:-translate-y-0.5">
              <DownloadSimple size={22} weight="bold" /> Download the app (APK)
            </a>
          </motion.div>
          <motion.p initial={still ? false : { opacity: 0 }} animate={{ opacity: 1 }} transition={{ delay: 0.9 }} className="mt-5 text-sm text-[#8FA2C4]">
            Already have the app? <Link href="/pay" className="inline-flex items-center gap-1 font-bold text-white underline-offset-4 hover:underline">Get Premium with card, transfer, USSD or OPay <ArrowRight size={14} weight="bold" /></Link>
          </motion.p>
        </div>
        <motion.div style={{ y: phoneY }} initial={still ? false : { opacity: 0, scale: 0.92, rotate: -4 }} animate={{ opacity: 1, scale: 1, rotate: 0 }} transition={{ duration: 0.9, delay: 0.2, ease }}>
          <PhoneDemo />
        </motion.div>
      </div>
    </section>
  );
}
