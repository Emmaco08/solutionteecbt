"use client";
import { AnimatePresence, motion, useInView, useMotionValue, useReducedMotion, useSpring, useTransform } from "motion/react";
import { useEffect, useRef, useState } from "react";
import {
  Books, CaretLeft, CaretRight, ChalkboardTeacher, Exam, GameController, House, MagnifyingGlass, PaperPlaneRight, Sparkle, Trophy, UsersThree,
} from "@phosphor-icons/react";

/* The Windows app is drawn at 1280 × 800 and scaled into the laptop screen. Colours from design/tokens.json. */
export const DESK_W = 1280;
export const DESK_H = 800;
const NAVY = "#0B1F44", BLUE = "#2563B3", GOLD = "#F2B233", BG = "#F4F6FA", BORDER = "#DCE3EF", MUTED = "#4F5B70", TEXT = "#06132B";

/**
 * A laptop: the lid opens when it scrolls into view, the screen glows on, and it tilts towards the mouse on computers.
 * No blur filters (slow on phones, D-131); still with reduce motion.
 */
export function Laptop3D({ children, width = 640 }: { children: React.ReactNode; width?: number }) {
  const still = useReducedMotion();
  const ref = useRef<HTMLDivElement>(null);
  const seen = useInView(ref, { once: true, margin: "-120px" });
  const mx = useMotionValue(0), my = useMotionValue(0);
  const rx = useSpring(useTransform(my, [-0.5, 0.5], [6, -6]), { stiffness: 110, damping: 18 });
  const ry = useSpring(useTransform(mx, [-0.5, 0.5], [-10, 10]), { stiffness: 110, damping: 18 });
  const bezel = Math.round(width * 0.022);
  const screenW = width - bezel * 2;
  const scale = screenW / DESK_W;
  const screenH = Math.round(DESK_H * scale);
  const open = still || seen;

  return (
    <div ref={ref} style={{ perspective: 2000, width }} className="relative mx-auto">
      <motion.div
        onPointerMove={(e) => {
          if (still || !ref.current || e.pointerType !== "mouse") return;
          const r = ref.current.getBoundingClientRect();
          mx.set((e.clientX - r.left) / r.width - 0.5);
          my.set((e.clientY - r.top) / r.height - 0.5);
        }}
        onPointerLeave={() => { mx.set(0); my.set(0); }}
        style={{ rotateX: still ? 0 : rx, rotateY: still ? 0 : ry, transformStyle: "preserve-3d" }}
      >
        {/* Lid */}
        <motion.div
          style={{ transformOrigin: "50% 100%", transformStyle: "preserve-3d" }}
          initial={still ? false : { rotateX: -88 }}
          animate={{ rotateX: open ? 0 : -88 }}
          transition={{ duration: 1.3, ease: [0.22, 1, 0.36, 1], delay: 0.15 }}
        >
          <div
            className="relative"
            style={{
              padding: bezel, paddingTop: bezel * 1.15, borderRadius: Math.round(width * 0.028),
              background: "linear-gradient(160deg,#2a3446 0%,#0b111d 45%,#141c2b 100%)",
              boxShadow: "0 0 0 1px rgba(255,255,255,.08) inset, 0 1px 1px rgba(255,255,255,.2) inset",
            }}
          >
            {/* Camera */}
            <span className="absolute left-1/2 -translate-x-1/2 rounded-full bg-[#1a2333] ring-1 ring-[#2e3a52]" style={{ top: bezel * 0.35, width: 6, height: 6 }} />
            <div className="relative overflow-hidden bg-black" style={{ height: screenH, borderRadius: 4 }}>
              <motion.div
                className="absolute left-0 top-0 origin-top-left"
                style={{ width: DESK_W, height: DESK_H, transform: `scale(${scale})` }}
                initial={still ? false : { opacity: 0 }}
                animate={{ opacity: open ? 1 : 0 }}
                transition={{ duration: 0.6, delay: 1.1 }}
              >
                {children}
              </motion.div>
              {/* Glass reflection */}
              <div className="pointer-events-none absolute inset-0" style={{ background: "linear-gradient(120deg,rgba(255,255,255,.10) 0%,transparent 28%,transparent 70%,rgba(255,255,255,.04) 100%)" }} />
            </div>
          </div>
        </motion.div>
        {/* Base */}
        <div className="relative mx-auto" style={{ width: width * 1.12, marginLeft: -width * 0.06 }}>
          <div style={{ height: Math.max(10, width * 0.022), borderRadius: "2px 2px 14px 14px", background: "linear-gradient(180deg,#c9d1de 0%,#8f9aad 55%,#5d687b 100%)", boxShadow: "0 40px 70px -30px rgba(3,10,25,.7)" }} />
          <span className="absolute left-1/2 top-0 -translate-x-1/2 rounded-b-lg bg-[#6f7a8d]" style={{ width: width * 0.16, height: Math.max(4, width * 0.008) }} />
        </div>
        {/* Floor shadow */}
        <div className="pointer-events-none mx-auto" style={{ marginTop: 6, width: width * 0.95, height: 36, background: "radial-gradient(closest-side, rgba(0,0,0,.28), transparent)" }} />
      </motion.div>
    </div>
  );
}

/** Runs a script of steps in a loop while [play]; the last step when the visitor asked for less motion. */
function useScript(play: boolean, durations: number[]) {
  const still = useReducedMotion();
  const [i, setI] = useState(0);
  useEffect(() => {
    if (!play || still) return;
    const t = setTimeout(() => setI((x) => (x + 1) % durations.length), durations[i % durations.length]);
    return () => clearTimeout(t);
  }, [play, still, i, durations]);
  return still ? 2 : i;
}

const NAV = [
  ["Learn", [["Home", House], ["Study", Books], ["Test", Exam], ["AI Tutor", Sparkle]]],
  ["Play & connect", [["Game Zone", GameController], ["Community", UsersThree], ["Leaderboard", Trophy]]],
  ["More", [["Live classes", ChalkboardTeacher]]],
] as const;

// Step lengths (ms). A constant, so the 1-second exam clock re-rendering the screen does not restart the step timer.
const STEPS = [900, 700, 900, 900, 1000, 700, 700, 1500];

const QS = [
  { n: 8, q: "Find the roots of the equation x² − 5x + 6 = 0.", o: ["x = 2 or 3", "x = −2 or −3", "x = 1 or 6", "x = −1 or 6"], pick: 0 },
  { n: 9, q: "Simplify (2³ × 2⁴) ÷ 2⁵.", o: ["2", "4", "8", "16"], pick: 1 },
];

/**
 * The Windows app in a JAMB mock, played by a mouse: point at an answer and click, open the floating calculator,
 * type a sum, close it, then Next to the following question. Loops.
 */
export function DesktopCbtScreen({ play = true }: { play?: boolean }) {
  // 0 move to answer, 1 click answer, 2 calculator opens, 3 typing, 4 result, 5 close, 6 next, 7 new question
  const step = useScript(play, STEPS);
  const still = useReducedMotion();
  const [secs, setSecs] = useState(5872);
  useEffect(() => {
    if (!play || still) return;
    const t = setInterval(() => setSecs((s) => (s > 1 ? s - 1 : 5872)), 1000);
    return () => clearInterval(t);
  }, [play, still]);
  const q = QS[step >= 7 ? 1 : 0];
  const picked = step >= 1 && step < 7 ? q.pick : -1;
  const calc = step >= 2 && step <= 4;
  const time = `${Math.floor(secs / 3600)}:${String(Math.floor((secs % 3600) / 60)).padStart(2, "0")}:${String(secs % 60).padStart(2, "0")}`;
  // Mouse pointer path (in screen pixels)
  const cursor = [
    { x: 520, y: 300 }, { x: 520, y: 300 }, { x: 920, y: 300 }, { x: 980, y: 470 }, { x: 1080, y: 600 }, { x: 1135, y: 268 }, { x: 838, y: 742 }, { x: 760, y: 520 },
  ][step];
  return (
    <div className="relative flex h-full w-full flex-col overflow-hidden" style={{ background: BG, color: TEXT }}>
      {/* Window title bar */}
      <div className="flex h-9 shrink-0 items-center gap-2 border-b bg-white px-3 text-[13px]" style={{ borderColor: BORDER }}>
        {/* eslint-disable-next-line @next/next/no-img-element */}
        <img src="/brand/favicon.svg" alt="" className="size-4 rounded" />
        <span style={{ color: MUTED }}>SolutionTee CBT</span>
        <span className="ml-auto flex items-center gap-6 pr-2" style={{ color: MUTED }}>
          <span className="block h-px w-3 bg-current" />
          <span className="block size-3 border border-current" />
          <span className="text-[15px] leading-none">✕</span>
        </span>
      </div>
      <div className="flex min-h-0 grow">
        {/* Sidebar */}
        <aside className="flex w-[252px] shrink-0 flex-col px-3 py-5 text-white" style={{ background: "linear-gradient(180deg,#0B1F44,#081734)" }}>
          <div className="flex items-center gap-3 px-2">
            {/* eslint-disable-next-line @next/next/no-img-element */}
            <img src="/brand/favicon.svg" alt="" className="size-9 rounded-xl" />
            <div><p className="text-[18px] font-bold leading-tight">SolutionTee</p><p className="text-[12px] text-[#9FB2D6]">CBT · Learn. Think. Solve.</p></div>
          </div>
          <div className="mx-1 mt-5 flex h-10 items-center gap-2 rounded-xl border border-white/10 bg-white/[.08] px-3 text-[13px] text-[#9FB2D6]">
            <MagnifyingGlass size={16} /> Search questions, topics… <span className="ml-auto rounded bg-white/10 px-1.5 text-[11px] font-bold text-[#B9C7DE]">Ctrl K</span>
          </div>
          {NAV.map(([title, items]) => (
            <div key={title} className="mt-4">
              <p className="px-3 pb-1 text-[11px] font-bold uppercase tracking-[.14em] text-[#8FA3C7]">{title}</p>
              {items.map(([label, Icon]) => {
                const on = label === "Test";
                return (
                  <div key={label} className="relative flex h-10 items-center gap-3 rounded-xl px-3 text-[15px]" style={{ background: on ? "rgba(255,255,255,.12)" : "transparent", fontWeight: on ? 700 : 500, color: on ? "#fff" : "#B9C7DE" }}>
                    {on ? <span className="absolute left-0 top-2.5 h-5 w-1 rounded" style={{ background: GOLD }} /> : null}
                    <Icon size={20} weight={on ? "fill" : "regular"} color={on ? "#FFC75A" : undefined} /> {label}
                  </div>
                );
              })}
            </div>
          ))}
          <div className="mt-auto flex items-center gap-3 rounded-2xl bg-white/[.06] p-3">
            <span className="grid size-10 place-items-center rounded-full text-sm font-bold" style={{ background: BLUE }}>TA</span>
            <div className="min-w-0"><p className="truncate text-[14px] font-bold">Tolu Adeyemi</p><p className="text-[12px] text-[#DCE4F2]">🔥 12 · ⚡ 2,480 XP</p></div>
          </div>
        </aside>
        {/* Exam */}
        <main className="flex min-w-0 grow flex-col">
          <div className="flex h-16 shrink-0 items-center gap-3 border-b bg-white px-6" style={{ borderColor: BORDER }}>
            <div className="grow"><p className="text-[16px] font-bold leading-tight">Tolu Adeyemi</p><p className="text-[12px]" style={{ color: MUTED }}>JAMB UTME Mock · Mathematics</p></div>
            <span className="flex items-center gap-2 rounded-full px-4 py-2 text-[18px] font-bold tabular-nums" style={{ background: "#EEF2F9" }}><span className="size-2.5 rounded-full" style={{ background: NAVY }} />{time}</span>
            <span className="flex items-center gap-1.5 rounded-full bg-[#C2302B] px-4 py-2 text-[14px] font-bold text-white"><PaperPlaneRight size={15} weight="fill" />Submit</span>
          </div>
          <div className="flex min-h-0 grow">
            <div className="relative min-w-0 grow px-10 pt-8">
              <AnimatePresence mode="wait">
                <motion.div key={q.n} initial={{ x: 50, opacity: 0 }} animate={{ x: 0, opacity: 1 }} exit={{ x: -50, opacity: 0 }} transition={{ duration: 0.35 }}>
                  <p className="text-[14px]"><b>Question {q.n}</b> <span style={{ color: MUTED }}>of 40</span></p>
                  <p className="mt-3 text-[22px] font-bold leading-snug">{q.q}</p>
                  <div className="mt-6 space-y-3">
                    {q.o.map((o, i) => {
                      const on = i === picked;
                      return (
                        <div key={o} className="flex items-center gap-4 rounded-2xl border-2 bg-white px-4 py-3.5 text-[17px] font-bold transition-colors" style={{ borderColor: on ? BLUE : BORDER, background: on ? "#EEF4FC" : "#fff" }}>
                          <span className="grid size-10 place-items-center rounded-xl text-[15px]" style={{ background: on ? NAVY : "#EEF2F9", color: on ? "#fff" : MUTED }}>{"ABCD"[i]}</span>
                          {o}
                        </div>
                      );
                    })}
                  </div>
                </motion.div>
              </AnimatePresence>
              {/* Floating calculator */}
              <AnimatePresence>
                {calc ? (
                  <motion.div className="absolute right-8 top-24 w-[290px] overflow-hidden rounded-2xl border bg-white shadow-2xl" style={{ borderColor: BORDER }}
                    initial={{ opacity: 0, y: 16, scale: 0.96 }} animate={{ opacity: 1, y: 0, scale: 1 }} exit={{ opacity: 0, y: 10, scale: 0.97 }} transition={{ duration: 0.25 }}>
                    <div className="flex h-10 items-center px-4 text-[14px] font-bold" style={{ background: "#EEF2F9" }}>Calculator <span className="ml-auto text-[12px] font-medium" style={{ color: MUTED }}>Drag to move ✕</span></div>
                    <div className="p-3">
                      <div className="flex h-20 flex-col items-end justify-end rounded-xl px-3 py-2" style={{ background: "#EEF2F9" }}>
                        <span className="text-[13px] tabular-nums" style={{ color: MUTED }}>{step >= 3 ? (step >= 4 ? "128 ÷ 32 =" : "128 ÷ 32") : ""}</span>
                        <span className="text-[30px] font-bold tabular-nums">{step >= 4 ? "4" : step >= 3 ? "32" : "0"}</span>
                      </div>
                      <div className="mt-2 grid grid-cols-4 gap-1.5">
                        {["C", "⌫", "%", "÷", "7", "8", "9", "×", "4", "5", "6", "−", "1", "2", "3", "+", "±", "0", ".", "="].map((k) => (
                          <span key={k} className="grid h-9 place-items-center rounded-lg text-[15px] font-bold" style={{ background: k === "=" ? NAVY : "÷×−+%".includes(k) ? "#E5EEFB" : "#EEF2F9", color: k === "=" ? "#fff" : TEXT }}>{k}</span>
                        ))}
                      </div>
                    </div>
                  </motion.div>
                ) : null}
              </AnimatePresence>
            </div>
            {/* Palette */}
            <aside className="w-[260px] shrink-0 border-l bg-white p-5" style={{ borderColor: BORDER }}>
              <p className="text-[16px] font-bold">Mathematics</p>
              <p className="text-[12px]" style={{ color: MUTED }}>{step >= 1 && step < 7 ? 8 : 7} answered · 40 questions</p>
              <div className="mt-4 grid grid-cols-5 gap-2">
                {Array.from({ length: 20 }, (_, i) => {
                  const cur = i === q.n - 1, done = i < (step >= 1 && step < 7 ? 8 : step >= 7 ? 8 : 7) && !cur;
                  return <span key={i} className="grid h-9 place-items-center rounded-lg border text-[13px] font-bold" style={{ background: done ? "#16A34A" : "#fff", color: done ? "#fff" : TEXT, borderColor: cur ? BLUE : BORDER, borderWidth: cur ? 2 : 1 }}>{i + 1}</span>;
                })}
              </div>
              <p className="mt-6 text-[13px] font-bold">Keyboard</p>
              {[["A – E", "Choose an answer"], ["← / →", "Previous / next"], ["Shift+C", "Calculator"], ["Ctrl+Enter", "Submit"]].map(([k, t]) => (
                <p key={k} className="mt-2 flex items-center gap-2 text-[12px]" style={{ color: MUTED }}><span className="rounded border px-1.5 py-0.5 font-bold" style={{ borderColor: BORDER, color: TEXT }}>{k}</span>{t}</p>
              ))}
            </aside>
          </div>
          <div className="flex h-16 shrink-0 items-center justify-between border-t bg-white px-6" style={{ borderColor: BORDER }}>
            <span className="flex h-11 items-center gap-1 rounded-xl border-2 px-4 text-[15px] font-bold" style={{ borderColor: BORDER }}><CaretLeft size={16} weight="bold" />Prev</span>
            <span className="flex h-11 items-center gap-1 rounded-xl px-5 text-[15px] font-bold text-white" style={{ background: NAVY }}>Next<CaretRight size={16} weight="bold" /></span>
          </div>
        </main>
      </div>
      {/* Mouse pointer */}
      {!still ? (
        <motion.svg className="pointer-events-none absolute left-0 top-0 z-30" width="26" height="34" viewBox="0 0 26 34" animate={{ x: cursor.x, y: cursor.y, scale: step === 1 || step === 5 || step === 6 ? 0.85 : 1 }} transition={{ duration: 0.6, ease: [0.22, 1, 0.36, 1] }}>
          <path d="M2 2 L2 27 L8.5 21 L13 31 L17.5 29 L13 19.5 L22 19.5 Z" fill="#fff" stroke="#06132B" strokeWidth="2" strokeLinejoin="round" />
        </motion.svg>
      ) : null}
    </div>
  );
}
