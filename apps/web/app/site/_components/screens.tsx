"use client";
import { AnimatePresence, animate, motion, useReducedMotion } from "motion/react";
import { useEffect, useState } from "react";
import {
  ArrowRight, BatteryFull, Books, Calculator, Camera, CaretLeft, CaretRight, ChartBar, Exam, FilePdf, Flag, GridFour, House,
  Lightning, NotePencil, PaperPlaneRight, Play, PlayCircle, Sparkle, SquaresFour, Student, Trophy, UserCircle, WifiHigh,
} from "@phosphor-icons/react";

/* Colours from design/tokens.json (the app's own). */
const NAVY = "#0B1F44", BLUE = "#2563B3", GOLD = "#F2B233", BG = "#F4F6FA", BORDER = "#DCE3EF", MUTED = "#4F5B70", TEXT = "#06132B";

/** Runs a script of steps in a loop while [play] is true; returns the current step. Still (last step) with reduce motion. */
function useScript(play: boolean, durations: number[]) {
  const still = useReducedMotion();
  const [i, setI] = useState(0);
  useEffect(() => {
    if (!play || still) return;
    const t = setTimeout(() => setI((x) => (x + 1) % durations.length), durations[i % durations.length]);
    return () => clearTimeout(t);
  }, [play, still, i, durations]);
  return still ? durations.length - 1 : i;
}

function StatusBar({ dark = false }: { dark?: boolean }) {
  return (
    <div className={`flex h-[46px] items-center justify-between px-7 pt-1 text-[15px] font-bold ${dark ? "text-white" : "text-[#06132B]"}`}>
      <span>9:41</span>
      <span className="flex items-center gap-1.5"><WifiHigh size={17} weight="bold" /><BatteryFull size={22} weight="fill" /></span>
    </div>
  );
}

function BottomNav({ active }: { active: "home" | "study" | "test" | "ai" | "me" }) {
  const tabs = [["home", House, "Home"], ["study", Books, "Study"], ["test", Exam, "Test"], ["ai", Sparkle, "AI Tutor"], ["me", UserCircle, "Me"]] as const;
  return (
    <div className="absolute inset-x-0 bottom-0 flex h-[78px] items-start justify-around border-t bg-white px-2 pt-2" style={{ borderColor: BORDER }}>
      {tabs.map(([k, Icon, label]) => (
        <span key={k} className="flex w-16 flex-col items-center gap-1 text-[12px] font-bold" style={{ color: k === active ? TEXT : MUTED }}>
          <span className="grid h-8 w-14 place-items-center rounded-full" style={{ background: k === active ? "#FDEBC2" : "transparent" }}>
            <Icon size={22} weight={k === active ? "fill" : "regular"} />
          </span>
          {label}
        </span>
      ))}
    </div>
  );
}

/** A finger tap: a ring that grows and fades where the screen is touched. */
function Tap({ x, y, show }: { x: number; y: number; show: boolean }) {
  return (
    <AnimatePresence>
      {show ? (
        <motion.span key={`${x}-${y}`} className="pointer-events-none absolute z-30 rounded-full" style={{ left: x - 22, top: y - 22, width: 44, height: 44, background: "rgba(37,99,179,.28)", border: "2px solid rgba(37,99,179,.55)" }}
          initial={{ scale: 0.4, opacity: 1 }} animate={{ scale: 1.5, opacity: 0 }} exit={{ opacity: 0 }} transition={{ duration: 0.6 }} />
      ) : null}
    </AnimatePresence>
  );
}

/* ------------------------------------------------------------------ CBT exam */
const QS = [
  { n: 12, subj: "Mathematics", q: "Find the roots of x² − 5x + 6 = 0.", o: ["x = 2 or 3", "x = −2 or −3", "x = 1 or 6", "x = −1 or 6"], pick: 0, done: 10 },
  { n: 13, subj: "Mathematics", q: "If log₁₀ 2 = 0.3010, find log₁₀ 8.", o: ["0.6020", "0.9030", "2.4080", "0.0753"], pick: 1, done: 11 },
];

export function CbtScreen({ play = true }: { play?: boolean }) {
  // 0 read, 1 tap answer, 2 tap Next, 3 next question, 4 tap answer, 5 open palette, 6 palette shown, 7 close
  const step = useScript(play, [1300, 900, 700, 1200, 900, 700, 1800, 600]);
  const [secs, setSecs] = useState(4358);
  const still = useReducedMotion();
  useEffect(() => {
    if (!play || still) return;
    const t = setInterval(() => setSecs((s) => (s > 1 ? s - 1 : 4358)), 1000);
    return () => clearInterval(t);
  }, [play, still]);
  const q = QS[step >= 3 ? 1 : 0];
  const picked = (step >= 1 && step < 3) || step >= 4 ? q.pick : -1;
  const time = `${Math.floor(secs / 3600)}:${String(Math.floor((secs % 3600) / 60)).padStart(2, "0")}:${String(secs % 60).padStart(2, "0")}`;
  const palette = step === 5 || step === 6;
  return (
    <div className="relative h-full w-full overflow-hidden" style={{ background: BG, color: TEXT }}>
      <div className="bg-white"><StatusBar /></div>
      <div className="flex items-center gap-3 border-b bg-white px-4 pb-3" style={{ borderColor: BORDER }}>
        <span className="grid size-10 place-items-center rounded-full text-sm font-bold text-white" style={{ background: BLUE }}>TA</span>
        <div className="min-w-0 grow"><p className="truncate whitespace-nowrap text-[15px] font-bold leading-tight">Tolu A.</p><p className="truncate whitespace-nowrap text-[12px]" style={{ color: MUTED }}>JAMB UTME Mock</p></div>
        <span className="flex shrink-0 items-center gap-1.5 rounded-full px-3 py-2 text-[16px] font-bold tabular-nums" style={{ background: "#EEF2F9" }}><span className="size-2.5 rounded-full" style={{ background: NAVY }} />{time}</span>
        <span className="flex shrink-0 items-center gap-1 rounded-full bg-[#C2302B] px-3 py-2 text-[14px] font-bold text-white"><PaperPlaneRight size={15} weight="fill" />Submit</span>
      </div>
      <div className="flex gap-2 overflow-hidden border-b bg-white px-4 py-3 text-[14px] font-bold" style={{ borderColor: BORDER }}>
        <span className="flex shrink-0 items-center gap-2 rounded-full px-3 py-2">English <span className="rounded-full px-2 py-0.5 text-[11px]" style={{ background: "#EEF2F9" }}>34/60</span></span>
        <span className="flex shrink-0 items-center gap-2 rounded-full px-3 py-2 text-white" style={{ background: NAVY }}>Mathematics <span className="rounded-full bg-white/20 px-2 py-0.5 text-[11px]">{q.done}/40</span></span>
        <span className="flex shrink-0 items-center gap-2 rounded-full px-3 py-2">Physics <span className="rounded-full px-2 py-0.5 text-[11px]" style={{ background: "#EEF2F9" }}>12/40</span></span>
      </div>
      <AnimatePresence mode="wait">
        <motion.div key={q.n} initial={{ x: 60, opacity: 0 }} animate={{ x: 0, opacity: 1 }} exit={{ x: -60, opacity: 0 }} transition={{ duration: 0.35 }} className="px-4 pt-4">
          <div className="flex justify-between text-[14px]"><b>Question {q.n} <span className="font-medium" style={{ color: MUTED }}>of 40</span></b><span style={{ color: MUTED }}>{q.subj}</span></div>
          <p className="mt-3 text-[18px] font-bold leading-snug">{q.q}</p>
          <div className="mt-4 space-y-3">
            {q.o.map((o, i) => {
              const on = i === picked;
              return (
                <motion.div key={o} animate={{ scale: on && (step === 1 || step === 4) ? 0.97 : 1 }}
                  className="flex items-center gap-4 rounded-2xl border-2 bg-white px-3 py-3 text-[16px] font-bold transition-colors"
                  style={{ borderColor: on ? BLUE : BORDER, background: on ? "#EEF4FC" : "#fff" }}>
                  <span className="grid size-10 place-items-center rounded-xl text-[15px]" style={{ background: on ? NAVY : "#EEF2F9", color: on ? "#fff" : MUTED }}>{"ABCD"[i]}</span>
                  {o}
                </motion.div>
              );
            })}
          </div>
        </motion.div>
      </AnimatePresence>
      <Tap x={200} y={step >= 3 ? 404 + 70 : 404} show={step === 1 || step === 4} />
      <Tap x={333} y={797} show={step === 2} />
      <Tap x={195} y={797} show={step === 5} />
      <div className="absolute inset-x-0 bottom-0 flex h-[82px] items-center justify-between border-t bg-white px-4 pb-3" style={{ borderColor: BORDER }}>
        <span className="flex h-12 items-center gap-1 rounded-xl border-2 px-4 text-[15px] font-bold" style={{ borderColor: BORDER }}><CaretLeft size={16} weight="bold" />Prev</span>
        <span className="flex gap-5" style={{ color: TEXT }}><Calculator size={24} /><GridFour size={24} /><Flag size={24} /></span>
        <span className="flex h-12 items-center gap-1 rounded-xl px-5 text-[15px] font-bold text-white" style={{ background: NAVY }}>Next<CaretRight size={16} weight="bold" /></span>
      </div>
      <AnimatePresence>
        {palette ? (
          <motion.div className="absolute inset-0 z-20 bg-black/30" initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }}>
            <motion.div className="absolute inset-x-0 bottom-0 rounded-t-[28px] bg-white px-5 pb-8 pt-3" initial={{ y: 420 }} animate={{ y: 0 }} exit={{ y: 420 }} transition={{ type: "spring", stiffness: 260, damping: 28 }}>
              <span className="mx-auto mb-4 block h-1.5 w-12 rounded-full" style={{ background: BORDER }} />
              <p className="text-[17px] font-bold">Mathematics · 11 of 40 answered</p>
              <div className="mt-4 grid grid-cols-8 gap-2">
                {Array.from({ length: 40 }, (_, i) => {
                  const done = i < 11, flag = i === 6, cur = i === 12;
                  return <span key={i} className="grid h-9 place-items-center rounded-lg text-[13px] font-bold" style={{ background: cur ? GOLD : done ? NAVY : "#EEF2F9", color: done && !cur ? "#fff" : TEXT, outline: flag ? `2px solid ${GOLD}` : "none" }}>{i + 1}</span>;
                })}
              </div>
              <div className="mt-4 flex gap-4 text-[12px]" style={{ color: MUTED }}><span>■ Answered</span><span style={{ color: "#C88A12" }}>■ Now</span><span>□ Not yet</span></div>
            </motion.div>
          </motion.div>
        ) : null}
      </AnimatePresence>
    </div>
  );
}

/* ------------------------------------------------------------------ Result */
export function ResultScreen({ play = true }: { play?: boolean }) {
  const still = useReducedMotion();
  const [score, setScore] = useState(still ? 287 : 0);
  const [go, setGo] = useState(still);
  useEffect(() => {
    if (!play || still) return;
    let stop = false;
    const run = () => {
      setGo(false); setScore(0);
      const c = animate(0, 287, { duration: 1.8, ease: [0.22, 1, 0.36, 1], onUpdate: (v) => setScore(Math.round(v)) });
      const t1 = setTimeout(() => setGo(true), 300);
      const t2 = setTimeout(() => { if (!stop) run(); }, 7000);
      return () => { c.stop(); clearTimeout(t1); clearTimeout(t2); };
    };
    const cleanup = run();
    return () => { stop = true; cleanup(); };
  }, [play, still]);
  const pct = score / 400, R = 92, C = 2 * Math.PI * R;
  const subjects: [string, number, string][] = [["Use of English", 78, "#16A34A"], ["Mathematics", 64, BLUE], ["Physics", 70, "#16A34A"], ["Chemistry", 75, "#16A34A"]];
  return (
    <div className="relative h-full w-full overflow-hidden" style={{ background: BG, color: TEXT }}>
      <div className="px-4 pb-24 text-center text-white" style={{ background: NAVY }}>
        <StatusBar dark />
        <p className="text-[18px] font-bold">Your result</p>
        <p className="mt-2 text-[13px] text-[#C9D5EA]">JAMB UTME Mock · 24 Oct 2026</p>
        <div className="relative mx-auto mt-4 size-[210px]">
          <svg viewBox="0 0 210 210" className="-rotate-90">
            <circle cx="105" cy="105" r={R} fill="none" stroke="rgba(255,255,255,.12)" strokeWidth="18" />
            <circle cx="105" cy="105" r={R} fill="none" stroke={GOLD} strokeWidth="18" strokeLinecap="round" strokeDasharray={C} strokeDashoffset={C * (1 - pct)} />
          </svg>
          <div className="absolute inset-0 grid place-content-center"><b className="text-[56px] leading-none tabular-nums">{score}</b><span className="text-[14px] text-[#C9D5EA]">out of 400</span></div>
        </div>
        <p className="mt-3 text-[22px] font-bold">Great work, Tolu!</p>
        <p className="mt-1 text-[14px] text-[#C9D5EA]">You beat your last score by <b style={{ color: GOLD }}>38 points</b>.</p>
      </div>
      <div className="-mt-16 grid grid-cols-3 gap-2.5 px-4">
        {[["71%", "Accuracy"], ["38s", "Per question"], ["1:54", "Time used"]].map(([v, l], i) => (
          <motion.div key={l} initial={false} animate={{ y: go ? 0 : 20, opacity: go ? 1 : 0 }} transition={{ delay: 0.15 * i }} className="rounded-2xl bg-white p-3 text-center shadow-[0_4px_14px_rgba(6,19,43,.08)]">
            <b className="block text-[22px]">{v}</b><span className="text-[12px]" style={{ color: MUTED }}>{l}</span>
          </motion.div>
        ))}
      </div>
      <div className="mx-4 mt-4 rounded-2xl bg-white p-4 shadow-[0_4px_14px_rgba(6,19,43,.06)]">
        <p className="text-[17px] font-bold">Score by subject</p>
        {subjects.map(([n, v, c], i) => (
          <div key={n} className="mt-3">
            <div className="flex justify-between text-[14px] font-bold"><span>{n}</span><span>{v}/100</span></div>
            <div className="mt-1.5 h-2 rounded-full" style={{ background: "#E7ECF4" }}>
              <motion.div className="h-full rounded-full" style={{ background: c }} initial={false} animate={{ width: go ? `${v}%` : "0%" }} transition={{ duration: 1, delay: 0.3 + 0.12 * i, ease: [0.22, 1, 0.36, 1] }} />
            </div>
          </div>
        ))}
      </div>
      <div className="mx-4 mt-4 rounded-2xl bg-white p-4 shadow-[0_4px_14px_rgba(6,19,43,.06)]">
        <p className="text-[17px] font-bold">Topics to practise</p>
        <div className="mt-3 flex flex-wrap gap-2">
          {["Integration", "Probability", "Organic chemistry", "Concord"].map((t, i) => (
            <motion.span key={t} initial={false} animate={{ scale: go ? 1 : 0.6, opacity: go ? 1 : 0 }} transition={{ delay: 0.9 + 0.1 * i, type: "spring" }} className="rounded-full border-2 px-3 py-1.5 text-[13px] font-bold" style={{ borderColor: BORDER }}>{t}</motion.span>
          ))}
        </div>
      </div>
    </div>
  );
}

/* ------------------------------------------------------------------ AI tutor */
const STEPS = ["Move 3 to the other side: 2x = 11 − 3", "So 2x = 8", "Divide both sides by 2: x = 4 ✅"];

export function AiScreen({ play = true }: { play?: boolean }) {
  // 0 empty, 1 photo sent, 2 typing, 3..5 steps, 6 chips
  const step = useScript(play, [900, 1100, 1200, 900, 900, 900, 2600]);
  return (
    <div className="relative h-full w-full overflow-hidden" style={{ background: BG, color: TEXT }}>
      <div className="bg-white">
        <StatusBar />
        <div className="flex items-center justify-between px-4 pb-3">
          <div><p className="text-[19px] font-bold">SolutionTee AI</p><p className="text-[13px]" style={{ color: MUTED }}>Your step-by-step tutor</p></div>
          <span className="flex items-center gap-1 rounded-full px-3 py-1.5 text-[13px] font-bold" style={{ background: "#FDEBC2", color: "#7A5200" }}><Sparkle size={14} weight="fill" />2 of 3 left today</span>
        </div>
        <div className="flex gap-2 px-4 pb-3 text-[14px] font-bold">
          <span className="rounded-full px-4 py-2 text-white" style={{ background: NAVY }}>Mathematics</span>
          {["Physics", "Chemistry"].map((s) => <span key={s} className="rounded-full border-2 px-4 py-2" style={{ borderColor: BORDER }}>{s}</span>)}
        </div>
      </div>
      <div className="space-y-3 px-4 pt-4">
        {step === 0 ? (
          <div className="pt-16 text-center">
            <span className="mx-auto grid size-20 place-items-center rounded-3xl" style={{ background: "#FDEBC2", color: "#7A5200" }}><Sparkle size={40} weight="fill" /></span>
            <p className="mt-4 text-[18px] font-bold">Hi Tolu, what are we solving today?</p>
            <p className="mt-2 text-[14px]" style={{ color: MUTED }}>I explain step by step, like a patient teacher.</p>
          </div>
        ) : null}
        <AnimatePresence>
          {step >= 1 ? (
            <motion.div key="me" initial={{ opacity: 0, y: 16, scale: 0.95 }} animate={{ opacity: 1, y: 0, scale: 1 }} className="ml-auto w-[78%] rounded-3xl rounded-br-lg p-2 text-white" style={{ background: BLUE }}>
              <div className="rounded-2xl bg-[#F7F3E8] p-4 text-center font-serif text-[22px] italic text-[#1F2A44]">2x + 3 = 11</div>
              <p className="px-2 pt-2 text-[15px]">Solve this for me please 🙏</p>
            </motion.div>
          ) : null}
          {step === 2 ? (
            <motion.span key="typing" initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} className="flex w-20 gap-1.5 rounded-2xl bg-white p-4">
              {[0, 1, 2].map((d) => <motion.span key={d} className="size-2 rounded-full" style={{ background: MUTED }} animate={{ y: [0, -4, 0] }} transition={{ duration: 0.6, repeat: Infinity, delay: d * 0.12 }} />)}
            </motion.span>
          ) : null}
          {step >= 3 ? (
            <motion.div key="ai" initial={{ opacity: 0, y: 16 }} animate={{ opacity: 1, y: 0 }} className="w-[88%] rounded-3xl rounded-bl-lg bg-white p-4 shadow-[0_4px_14px_rgba(6,19,43,.06)]">
              <p className="text-[15px] font-bold">Let’s solve it together 👇</p>
              <div className="mt-3 space-y-2.5">
                {STEPS.slice(0, Math.min(3, step - 2)).map((s, i) => (
                  <motion.div key={s} initial={{ opacity: 0, x: -10 }} animate={{ opacity: 1, x: 0 }} className="flex gap-3">
                    <span className="grid size-7 shrink-0 place-items-center rounded-full text-[13px] font-bold text-white" style={{ background: i === 2 ? "#16A34A" : NAVY }}>{i + 1}</span>
                    <span className="pt-0.5 text-[15px] leading-snug">{s}</span>
                  </motion.div>
                ))}
              </div>
            </motion.div>
          ) : null}
          {step >= 6 ? (
            <motion.div key="chips" initial={{ opacity: 0, y: 10 }} animate={{ opacity: 1, y: 0 }} className="flex flex-wrap gap-2">
              {["Explain step 1 again", "Give me a 3-question quiz", "Similar question"].map((c) => (
                <span key={c} className="rounded-full border-2 bg-white px-3 py-1.5 text-[13px] font-bold" style={{ borderColor: BORDER }}>{c}</span>
              ))}
            </motion.div>
          ) : null}
        </AnimatePresence>
      </div>
      <div className="absolute inset-x-0 bottom-[78px] flex items-center gap-2 bg-[#F4F6FA] px-4 py-3">
        <span className="grid size-12 place-items-center rounded-full border-2 bg-white" style={{ borderColor: BORDER }}><Camera size={22} /></span>
        <span className="flex h-12 grow items-center rounded-full border-2 bg-white px-4 text-[15px]" style={{ borderColor: BORDER, color: MUTED }}>Ask any question…</span>
        <span className="grid size-12 place-items-center rounded-full text-white" style={{ background: NAVY }}><PaperPlaneRight size={20} weight="fill" /></span>
      </div>
      <Tap x={360} y={709} show={step === 1} />
      <BottomNav active="ai" />
    </div>
  );
}

/* ------------------------------------------------------------------ Study hub */
const TILES = [
  [Exam, "Past questions", "Study mode with answers", "#EEF2F9", NAVY],
  [PlayCircle, "Video solutions", "Watch each answer", "#EEF2F9", NAVY],
  [Student, "Topic lessons", "By syllabus topic", "#E8F7EE", "#15803D"],
  [NotePencil, "Lesson notes", "Read, with formulas", "#FDF1DC", "#9A5B00"],
  [Books, "Novels", "JAMB literature texts", "#FDECEC", "#B42318"],
  [FilePdf, "Syllabus & brochure", "Free on your plan", "#EEF2F9", NAVY],
] as const;

export function StudyScreen({ play = true }: { play?: boolean }) {
  // 0 grid in, 1 tap video, 2 player, 3 player playing
  const step = useScript(play, [1600, 600, 900, 3800]);
  const [prog, setProg] = useState(0);
  const still = useReducedMotion();
  useEffect(() => {
    if (step !== 3 || still) return;
    const c = animate(0, 62, { duration: 3.6, ease: "linear", onUpdate: (v) => setProg(v) });
    return () => c.stop();
  }, [step, still]);
  const player = step >= 2;
  return (
    <div className="relative h-full w-full overflow-hidden" style={{ background: BG, color: TEXT }}>
      <AnimatePresence mode="wait">
        {!player ? (
          <motion.div key="grid" initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0, scale: 0.96 }} className="h-full">
            <StatusBar />
            <div className="flex items-center justify-between px-4"><p className="text-[24px] font-bold">Study</p></div>
            <div className="mx-4 mt-3 flex h-12 items-center rounded-2xl border-2 bg-white px-4 text-[15px]" style={{ borderColor: BORDER, color: MUTED }}>Search questions, topics, notes</div>
            <div className="mt-4 grid grid-cols-2 gap-3 px-4">
              {TILES.map(([Icon, t, s, bg, fg], i) => (
                <motion.div key={t} initial={{ opacity: 0, y: 18 }} animate={{ opacity: 1, y: 0, scale: step === 1 && i === 1 ? 0.95 : 1 }} transition={{ delay: 0.06 * i }}
                  className="rounded-2xl border bg-white p-4" style={{ borderColor: BORDER }}>
                  <span className="grid size-12 place-items-center rounded-xl" style={{ background: bg, color: fg }}><Icon size={24} weight="fill" /></span>
                  <p className="mt-4 text-[16px] font-bold">{t}</p>
                  <p className="text-[13px]" style={{ color: MUTED }}>{s}</p>
                </motion.div>
              ))}
            </div>
            <Tap x={290} y={260} show={step === 1} />
          </motion.div>
        ) : (
          <motion.div key="player" initial={{ opacity: 0, x: 60 }} animate={{ opacity: 1, x: 0 }} exit={{ opacity: 0 }} className="h-full bg-white">
            <div style={{ background: "#000" }}>
              <StatusBar dark />
              <div className="relative grid h-[220px] place-items-center overflow-hidden" style={{ background: "linear-gradient(135deg,#0B1F44,#173A7A)" }}>
                <div className="font-serif text-[30px] italic text-white/90">x² − 5x + 6 = 0</div>
                <motion.span className="absolute grid size-16 place-items-center rounded-full bg-white/90" style={{ color: NAVY }} animate={{ scale: step === 3 ? 0 : 1, opacity: step === 3 ? 0 : 1 }}><Play size={28} weight="fill" /></motion.span>
                <div className="absolute inset-x-3 bottom-3"><div className="h-1.5 rounded-full bg-white/25"><div className="h-full rounded-full" style={{ width: `${prog}%`, background: GOLD }} /></div></div>
              </div>
            </div>
            <div className="p-4">
              <p className="text-[13px] font-bold" style={{ color: BLUE }}>Video solution · JAMB 2019 · Q12</p>
              <p className="mt-1 text-[20px] font-bold leading-tight">Solving quadratic equations by factorising</p>
              <div className="mt-4 space-y-2">
                {["1. Find two numbers that multiply to 6", "2. They must add up to −5", "3. Write (x − 2)(x − 3) = 0", "4. So x = 2 or x = 3"].map((c, i) => (
                  <motion.div key={c} initial={{ opacity: 0, x: 20 }} animate={{ opacity: 1, x: 0 }} transition={{ delay: 0.15 * i }}
                    className="flex items-center justify-between rounded-xl px-3 py-3 text-[14px] font-bold" style={{ background: i <= prog / 20 ? "#EEF4FC" : BG }}>
                    {c}<span className="text-[12px]" style={{ color: MUTED }}>0:{String(15 * (i + 1)).padStart(2, "0")}</span>
                  </motion.div>
                ))}
              </div>
            </div>
          </motion.div>
        )}
      </AnimatePresence>
      {!player ? <BottomNav active="study" /> : null}
    </div>
  );
}

/* ------------------------------------------------------------------ Leaderboard */
const ROWS: [number, string, string, string, number, number][] = [
  [4, "IN", "Ifeoma N.", "Enugu", 355, 1], [5, "OB", "Oluwaseun B.", "Oyo", 351, -1], [6, "ZY", "Zainab Y.", "Kaduna", 348, 0], [7, "EC", "Ebuka C.", "Imo", 344, 4],
];

export function LeaderScreen({ play = true }: { play?: boolean }) {
  const step = useScript(play, [400, 5600]);
  const up = step >= 1 || !play;
  const podium: [string, string, string, number, number, string][] = [
    ["AM", "Abdullahi M.", "Kano", 366, 2, "#DCE3EF"], ["CO", "Chiamaka O.", "Anambra", 372, 1, GOLD], ["TA", "Temiloluwa A.", "Lagos", 361, 3, "#E9B48A"],
  ];
  return (
    <div className="relative h-full w-full overflow-hidden" style={{ background: BG, color: TEXT }}>
      <div className="bg-white">
        <StatusBar />
        <div className="px-4 pb-3"><p className="text-[20px] font-bold">Leaderboard</p><p className="text-[13px]" style={{ color: MUTED }}>Best full JAMB mock score this season</p></div>
        <div className="mx-4 mb-3 grid grid-cols-2 rounded-2xl p-1 text-center text-[14px] font-bold" style={{ background: "#EEF2F9" }}>
          <span className="rounded-xl bg-white py-2 shadow">Nigeria</span><span className="py-2" style={{ color: MUTED }}>My state (Oyo)</span>
        </div>
      </div>
      <div className="flex items-end justify-center gap-3 px-4 pt-6">
        {podium.map(([ini, name, state, score, rank, c], i) => (
          <div key={ini} className="flex w-[110px] flex-col items-center">
            <motion.span initial={false} animate={{ scale: up ? 1 : 0 }} transition={{ delay: 0.2 + 0.15 * i, type: "spring" }} className="relative grid place-items-center rounded-full font-bold" style={{ width: rank === 1 ? 76 : 60, height: rank === 1 ? 76 : 60, background: c, fontSize: rank === 1 ? 24 : 19 }}>
              {ini}<span className="absolute -bottom-1 -right-1 grid size-7 place-items-center rounded-full text-[13px] text-white" style={{ background: NAVY }}>{rank}</span>
            </motion.span>
            <p className="mt-2 text-[13px] font-bold">{name}</p><p className="text-[12px]" style={{ color: MUTED }}>{state}</p>
            <motion.div initial={false} animate={{ height: up ? (rank === 1 ? 110 : rank === 2 ? 80 : 64) : 0 }} transition={{ duration: 0.8, delay: 0.1 * i, ease: [0.22, 1, 0.36, 1] }}
              className="mt-2 grid w-full place-items-start justify-center overflow-hidden rounded-t-2xl pt-3 text-[18px] font-bold" style={{ background: rank === 1 ? "#FDF1DC" : "#E7ECF4" }}>{score}</motion.div>
          </div>
        ))}
      </div>
      <div className="mx-4 rounded-2xl bg-white">
        {ROWS.map(([r, ini, n, s, sc, d], i) => (
          <motion.div key={r} initial={false} animate={{ opacity: up ? 1 : 0, x: up ? 0 : 40 }} transition={{ delay: 0.6 + 0.1 * i }} className="flex items-center gap-3 border-b px-4 py-3" style={{ borderColor: BORDER }}>
            <span className="w-5 text-[16px] font-bold">{r}</span>
            <span className="grid size-10 place-items-center rounded-full text-[13px] font-bold" style={{ background: "#EEF2F9" }}>{ini}</span>
            <span className="grow"><b className="block text-[15px]">{n}</b><span className="text-[12px]" style={{ color: MUTED }}>{s}</span></span>
            {d ? <span className="text-[12px] font-bold" style={{ color: d > 0 ? "#15803D" : "#B42318" }}>{d > 0 ? `▲${d}` : `▼${-d}`}</span> : null}
            <b className="text-[17px] tabular-nums">{sc}</b>
          </motion.div>
        ))}
      </div>
      <motion.div initial={false} animate={{ y: up ? 0 : 120 }} transition={{ delay: 1.1, type: "spring", stiffness: 200, damping: 22 }}
        className="absolute inset-x-3 bottom-[90px] flex items-center gap-3 rounded-2xl px-4 py-3 text-white" style={{ background: NAVY }}>
        <b className="text-[20px]" style={{ color: GOLD }}>#128</b>
        <span className="grid size-10 place-items-center rounded-full text-[13px] font-bold" style={{ background: GOLD, color: NAVY }}>TA</span>
        <span className="grow"><b className="block text-[15px]">You</b><span className="text-[12px] text-[#C9D5EA]">38 points to reach the top 100</span></span>
        <b className="text-[18px]">287</b>
      </motion.div>
      <BottomNav active="test" />
    </div>
  );
}

export const SCREEN_ICONS = { Trophy, ChartBar, Lightning, SquaresFour, ArrowRight };
