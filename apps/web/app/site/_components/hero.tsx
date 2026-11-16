"use client";
import Link from "next/link";
import { motion, useInView, useReducedMotion, useScroll, useTransform } from "motion/react";
import { useRef } from "react";
import { ArrowRight, CheckCircle, DownloadSimple, Fire, GooglePlayLogo, Sparkle, TrendUp, WindowsLogo } from "@phosphor-icons/react";
import { ease, useDesktopMotion } from "./motion";
import { PHONE_RATIO, Phone3D, fitPhone, useScreen } from "./phone";
import { CbtScreen, ResultScreen } from "./screens";

function Chip({ children, className, delay = 0 }: { children: React.ReactNode; className: string; delay?: number }) {
  const still = useReducedMotion();
  return (
    <motion.div className={`absolute z-20 ${className}`}
      initial={still ? false : { opacity: 0, scale: 0.6, y: 20 }} animate={still ? undefined : { opacity: 1, scale: 1, y: 0 }}
      transition={still ? undefined : { opacity: { delay, duration: 0.5 }, scale: { delay, type: "spring" }, y: { delay, duration: 0.5 } }}>
      {/* The gentle bob is a CSS loop (D-131); no backdrop blur (slow on phones, and the chip is solid anyway). */}
      <div className="st-float-sm flex items-center gap-2 whitespace-nowrap rounded-2xl border border-white/15 bg-white px-3 py-2 text-[13px] font-bold text-[#0B1F44] shadow-[0_20px_40px_-12px_rgba(0,0,0,.45)] sm:px-3.5 sm:py-2.5 sm:text-sm" style={{ animationDelay: `${delay}s` }}>
        {children}
      </div>
    </motion.div>
  );
}

export function Hero({ badge, title, highlight, subtitle, playUrl }: { badge: string; title: string; highlight: string; subtitle: string; playUrl: string }) {
  const ref = useRef<HTMLElement>(null);
  const still = useReducedMotion();
  // Scroll parallax only on computers (D-131): on phones it makes scrolling heavy. The demo phones stop when the hero
  // is off screen.
  const desk = useDesktopMotion();
  const live = useInView(ref);
  const { scrollYProgress } = useScroll({ target: ref, offset: ["start start", "end start"] });
  const frontY = useTransform(scrollYProgress, [0, 1], [0, still || !desk ? 0 : 140]);
  const backY = useTransform(scrollYProgress, [0, 1], [0, still || !desk ? 0 : 60]);
  // The phones follow the screen (owner, 16 Nov 2026): on a computer they fit the window height under the menu, so a
  // 1366 × 768 laptop shows them whole; on a phone they take about three quarters of the width.
  const screen = useScreen();
  const wide = screen.w >= 1024;
  const front = wide ? fitPhone(screen, { max: 340, min: 230, reserve: 150 }) : fitPhone(screen, { max: 300, min: 220, vw: 0.7 });
  const back = Math.round(front * 0.86);
  const stageH = Math.round(front * PHONE_RATIO + 24);
  const stageW = Math.round(front + back * 0.62);
  // Admin → Website: plain words, then the gold highlighted words.
  const plain = title.split(/\s+/).filter(Boolean);
  const words = [...plain, ...highlight.split(/\s+/).filter(Boolean)];
  const btn = "inline-flex h-[52px] items-center justify-center gap-2.5 whitespace-nowrap rounded-2xl px-5 text-[15px] font-bold transition-[transform,background-color] duration-200 hover:-translate-y-0.5 sm:h-14 sm:text-base";
  return (
    <section ref={ref} className="relative flex items-center overflow-hidden bg-[#06132B] pb-16 pt-24 text-white sm:pt-28 lg:min-h-[100svh] lg:pb-12 lg:pt-20">
      <div className="pointer-events-none absolute inset-0 bg-[linear-gradient(rgba(255,255,255,.045)_1px,transparent_1px),linear-gradient(90deg,rgba(255,255,255,.045)_1px,transparent_1px)] bg-[size:44px_44px] [mask-image:radial-gradient(ellipse_at_top,black_30%,transparent_75%)]" aria-hidden />
      {/* Soft glows as plain gradients: same look as a blurred circle, without the cost of a blur filter (D-131) */}
      <div className="pointer-events-none absolute -left-64 -top-20 size-[900px] bg-[radial-gradient(closest-side,rgba(37,99,179,.38),transparent)]" aria-hidden />
      <div className="pointer-events-none absolute -bottom-40 -right-56 size-[760px] bg-[radial-gradient(closest-side,rgba(242,178,51,.2),transparent)]" aria-hidden />
      <div className="st-wrap relative grid items-center gap-12 lg:grid-cols-[minmax(0,1.05fr)_minmax(0,.95fr)] lg:gap-10">
        <div className="text-center sm:text-left">
          <motion.p initial={still ? false : { opacity: 0, y: 10 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 0.5, ease }}
            className="mb-5 inline-flex items-center gap-2 rounded-full border border-white/15 bg-white/5 px-3 py-1.5 text-xs font-bold text-[#F2B233]">
            <Sparkle size={14} weight="fill" /> {badge}
          </motion.p>
          <h1 className="st-h1 font-bold">
            {words.map((w, i) => (
              <motion.span key={i} className={`mr-[0.25em] inline-block ${i >= plain.length ? "bg-gradient-to-r from-[#F2B233] to-[#FFD66B] bg-clip-text text-transparent" : ""}`}
                initial={still ? false : { opacity: 0, y: 28 }} animate={{ opacity: 1, y: 0 }}
                transition={{ duration: 0.7, delay: 0.06 * i, ease }}>{w}</motion.span>
            ))}
          </h1>
          <motion.p initial={still ? false : { opacity: 0, y: 12 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 0.6, delay: 0.45, ease }}
            className="st-lead mx-auto mt-5 max-w-xl text-[#C9D5EA] sm:mx-0">
            {subtitle}
          </motion.p>
          <motion.div initial={still ? false : { opacity: 0, y: 12 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 0.6, delay: 0.6, ease }}
            className="mt-8 flex flex-col gap-3 sm:flex-row sm:flex-wrap">
            <a href="/download/apk" className={`${btn} group relative overflow-hidden bg-[#F2B233] text-[#0B1F44] shadow-[0_14px_30px_-12px_rgba(242,178,51,.7)]`}>
              <span className="absolute inset-0 -translate-x-full bg-gradient-to-r from-transparent via-white/50 to-transparent transition-transform duration-700 group-hover:translate-x-full" aria-hidden />
              <DownloadSimple size={22} weight="bold" /> Download for Android
            </a>
            <a href="/download/windows" className={`${btn} border border-white/20 bg-white/10 text-white hover:bg-white/15`}>
              <WindowsLogo size={22} weight="fill" /> Download for Windows
            </a>
            {/* Google Play only once the admin has added the Play Store link (owner, 16 Nov 2026) */}
            {playUrl ? (
              <a href={playUrl} className={`${btn} bg-white text-[#0B1F44]`}>
                <GooglePlayLogo size={24} weight="fill" /> Get it on Google Play
              </a>
            ) : null}
          </motion.div>
          <motion.p initial={still ? false : { opacity: 0 }} animate={{ opacity: 1 }} transition={{ delay: 0.85 }} className="mt-5 text-sm text-[#8FA2C4]">
            Already have the app? <Link href="/pay" className="inline-flex items-center gap-1 font-bold text-white underline-offset-4 hover:underline">Get Premium with card, transfer, USSD or OPay <ArrowRight size={14} weight="bold" /></Link>
          </motion.p>
        </div>

        <div className="relative mx-auto" style={{ height: stageH, width: Math.min(stageW, screen.w - 32) }}>
          <motion.div style={{ y: backY }} className="absolute right-0 top-[6%] hidden sm:block"
            initial={still ? false : { opacity: 0, x: 60, rotate: 8 }} animate={{ opacity: 1, x: 0, rotate: 6 }} transition={{ duration: 1, delay: 0.4, ease }}>
            <div className="opacity-90"><Phone3D width={back} tilt={false} float><ResultScreen play={live} /></Phone3D></div>
          </motion.div>
          <motion.div style={{ y: frontY }} className="absolute left-1/2 top-0 -translate-x-1/2 sm:left-0 sm:translate-x-0"
            initial={still ? false : { opacity: 0, y: 60, rotate: -6, scale: 0.9 }} animate={{ opacity: 1, y: 0, rotate: -3, scale: 1 }} transition={{ duration: 1, delay: 0.2, ease }}>
            <Phone3D width={front}><CbtScreen play={live} /></Phone3D>
          </motion.div>
          <Chip className="right-0 top-0 hidden sm:flex" delay={1.1}><CheckCircle size={20} weight="fill" className="text-[#16A34A]" /> Every answer explained</Chip>
          <Chip className="-right-1 top-[52%] hidden min-[420px]:flex sm:-right-6" delay={1.4}><TrendUp size={20} weight="bold" className="text-[#2563B3]" /> +38 points this week</Chip>
          <Chip className="bottom-[8%] -left-1 sm:-left-8" delay={1.7}><Fire size={20} weight="fill" className="text-[#E8590C]" /> 12-day streak</Chip>
        </div>
      </div>
    </section>
  );
}
