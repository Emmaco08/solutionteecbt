"use client";
import Link from "next/link";
import { motion, useReducedMotion, useScroll, useTransform } from "motion/react";
import { useRef } from "react";
import { ArrowRight, CheckCircle, DownloadSimple, Fire, GooglePlayLogo, Sparkle, TrendUp } from "@phosphor-icons/react";
import { ease } from "./motion";
import { Phone3D } from "./phone";
import { CbtScreen, ResultScreen } from "./screens";

function Chip({ children, className, delay = 0 }: { children: React.ReactNode; className: string; delay?: number }) {
  const still = useReducedMotion();
  return (
    <motion.div className={`absolute z-20 flex items-center gap-2 rounded-2xl border border-white/15 bg-white/95 px-3.5 py-2.5 text-sm font-bold text-[#0B1F44] shadow-[0_20px_40px_-12px_rgba(0,0,0,.45)] backdrop-blur ${className}`}
      initial={still ? false : { opacity: 0, scale: 0.6, y: 20 }} animate={still ? undefined : { opacity: 1, scale: 1, y: [0, -8, 0] }}
      transition={still ? undefined : { opacity: { delay, duration: 0.5 }, scale: { delay, type: "spring" }, y: { delay: delay + 0.5, duration: 4, repeat: Infinity, ease: "easeInOut" } }}>
      {children}
    </motion.div>
  );
}

export function Hero({ badge, title, highlight, subtitle, playUrl }: { badge: string; title: string; highlight: string; subtitle: string; playUrl: string }) {
  const ref = useRef<HTMLElement>(null);
  const still = useReducedMotion();
  const { scrollYProgress } = useScroll({ target: ref, offset: ["start start", "end start"] });
  const frontY = useTransform(scrollYProgress, [0, 1], [0, still ? 0 : 140]);
  const backY = useTransform(scrollYProgress, [0, 1], [0, still ? 0 : 60]);
  const glowScale = useTransform(scrollYProgress, [0, 1], [1, 1.4]);
  // Admin → Website: plain words, then the gold highlighted words.
  const plain = title.split(/\s+/).filter(Boolean);
  const words = [...plain, ...highlight.split(/\s+/).filter(Boolean)];
  return (
    <section ref={ref} className="relative overflow-hidden bg-[#06132B] pb-24 pt-28 text-white sm:pt-32 lg:pb-32">
      <div className="pointer-events-none absolute inset-0 bg-[linear-gradient(rgba(255,255,255,.045)_1px,transparent_1px),linear-gradient(90deg,rgba(255,255,255,.045)_1px,transparent_1px)] bg-[size:44px_44px] [mask-image:radial-gradient(ellipse_at_top,black_30%,transparent_75%)]" aria-hidden />
      <motion.div style={{ scale: glowScale }} className="pointer-events-none absolute -left-40 top-10 size-[520px] rounded-full bg-[#2563B3]/35 blur-[120px]" aria-hidden />
      <motion.div className="pointer-events-none absolute -right-32 bottom-0 size-[420px] rounded-full bg-[#F2B233]/20 blur-[120px]" aria-hidden
        animate={still ? undefined : { x: [0, -40, 0], y: [0, 30, 0] }} transition={{ duration: 12, repeat: Infinity, ease: "easeInOut" }} />
      <div className="relative mx-auto grid max-w-6xl items-center gap-16 px-4 sm:px-6 lg:grid-cols-[1.05fr_.95fr]">
        <div>
          <motion.p initial={still ? false : { opacity: 0, y: 10 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 0.5, ease }}
            className="mb-5 inline-flex items-center gap-2 rounded-full border border-white/15 bg-white/5 px-3 py-1.5 text-xs font-bold text-[#F2B233]">
            <Sparkle size={14} weight="fill" /> {badge}
          </motion.p>
          <h1 className="text-[42px] font-bold leading-[1.06] tracking-tight sm:text-[60px]">
            {words.map((w, i) => (
              <motion.span key={i} className={`mr-[0.25em] inline-block ${i >= plain.length ? "bg-gradient-to-r from-[#F2B233] to-[#FFD66B] bg-clip-text text-transparent" : ""}`}
                initial={still ? false : { opacity: 0, y: 32, rotateX: -60, filter: "blur(8px)" }} animate={{ opacity: 1, y: 0, rotateX: 0, filter: "blur(0px)" }}
                transition={{ duration: 0.7, delay: 0.08 * i, ease }}>{w}</motion.span>
            ))}
          </h1>
          <motion.p initial={still ? false : { opacity: 0, y: 12 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 0.6, delay: 0.5, ease }}
            className="mt-5 max-w-xl text-[17px] leading-7 text-[#C9D5EA]">
            {subtitle}
          </motion.p>
          <motion.div initial={still ? false : { opacity: 0, y: 12 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 0.6, delay: 0.65, ease }}
            className="mt-8 flex flex-col gap-3 sm:flex-row">
            {playUrl ? (
              <a href={playUrl} className="inline-flex h-14 items-center justify-center gap-2.5 whitespace-nowrap rounded-2xl bg-white px-5 font-bold text-[#0B1F44] transition-transform hover:-translate-y-0.5">
                <GooglePlayLogo size={24} weight="fill" /> Get it on Google Play
              </a>
            ) : (
              <span className="inline-flex h-14 items-center justify-center gap-2.5 whitespace-nowrap rounded-2xl border border-white/20 px-5 font-bold text-white/80">
                <GooglePlayLogo size={24} weight="fill" /> Google Play: coming soon
              </span>
            )}
            <a href="/download/apk" className="group relative inline-flex h-14 items-center justify-center gap-2.5 overflow-hidden whitespace-nowrap rounded-2xl bg-[#F2B233] px-5 font-bold text-[#0B1F44] transition-transform hover:-translate-y-0.5">
              <span className="absolute inset-0 -translate-x-full bg-gradient-to-r from-transparent via-white/50 to-transparent transition-transform duration-700 group-hover:translate-x-full" aria-hidden />
              <DownloadSimple size={22} weight="bold" /> Download the app (APK)
            </a>
          </motion.div>
          <motion.p initial={still ? false : { opacity: 0 }} animate={{ opacity: 1 }} transition={{ delay: 0.9 }} className="mt-5 text-sm text-[#8FA2C4]">
            Already have the app? <Link href="/pay" className="inline-flex items-center gap-1 font-bold text-white underline-offset-4 hover:underline">Get Premium with card, transfer, USSD or OPay <ArrowRight size={14} weight="bold" /></Link>
          </motion.p>
        </div>

        <div className="relative mx-auto h-[600px] w-full max-w-[460px] sm:h-[640px]">
          <motion.div style={{ y: backY }} className="absolute right-0 top-10 hidden sm:block"
            initial={still ? false : { opacity: 0, x: 60, rotate: 8 }} animate={{ opacity: 1, x: 0, rotate: 6 }} transition={{ duration: 1, delay: 0.4, ease }}>
            <div className="opacity-90"><Phone3D width={250} tilt={false} float><ResultScreen /></Phone3D></div>
          </motion.div>
          <motion.div style={{ y: frontY }} className="absolute left-1/2 top-0 -translate-x-1/2 sm:left-0 sm:translate-x-0"
            initial={still ? false : { opacity: 0, y: 60, rotate: -6, scale: 0.9 }} animate={{ opacity: 1, y: 0, rotate: -3, scale: 1 }} transition={{ duration: 1, delay: 0.2, ease }}>
            <Phone3D width={290}><CbtScreen /></Phone3D>
          </motion.div>
          <Chip className="right-2 top-0 hidden sm:flex" delay={1.1}><CheckCircle size={20} weight="fill" className="text-[#16A34A]" /> Every answer explained</Chip>
          <Chip className="right-0 top-[54%] sm:-right-6" delay={1.4}><TrendUp size={20} weight="bold" className="text-[#2563B3]" /> +38 points this week</Chip>
          <Chip className="bottom-10 left-0 sm:-left-8" delay={1.7}><Fire size={20} weight="fill" className="text-[#E8590C]" /> 12-day streak</Chip>
        </div>
      </div>
    </section>
  );
}
