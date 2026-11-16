"use client";
import { AnimatePresence, motion, useInView, useReducedMotion } from "motion/react";
import { useEffect, useRef, useState } from "react";
import { CaretLeft, CaretRight, ChartLineUp, Exam, Robot, Trophy, VideoCamera, type Icon } from "@phosphor-icons/react";
import { Phone3D, fitPhone, useScreen } from "./phone";
import { AiScreen, CbtScreen, LeaderScreen, ResultScreen, StudyScreen } from "./screens";
import { ease } from "./motion";

type Step = { key: string; icon: Icon; tag: string; title: string; text: string; how: string[]; screen: (play: boolean) => React.ReactNode };

const STEPS: Step[] = [
  {
    key: "cbt", icon: Exam, tag: "1 · Real CBT", title: "Write the exam before the exam",
    text: "The test screen works like the JAMB, WAEC and NECO computer-based tests, so exam day feels familiar.",
    how: [
      "Choose your exam, your subjects and a full mock or a quick test.",
      "Answer against a live timer. Switch subjects at the top, flag questions, open the calculator and the question map.",
      "Submit when you are ready, or the test submits itself when time runs out. Nothing is lost if your phone goes off.",
    ],
    screen: (p) => <CbtScreen play={p} />,
  },
  {
    key: "result", icon: ChartLineUp, tag: "2 · Instant results", title: "Know your score and what to fix",
    text: "The moment you submit, you see your JAMB score out of 400, how you did in each subject and which topics need work.",
    how: [
      "Your score, accuracy, time per question and how you compare with last time.",
      "Every question with the right answer and a clear explanation.",
      "Tap a weak topic to practise just that topic until it becomes a strength.",
    ],
    screen: (p) => <ResultScreen play={p} />,
  },
  {
    key: "ai", icon: Robot, tag: "3 · AI tutor", title: "Stuck? Ask your AI tutor",
    text: "Type a question or snap a photo of it. The tutor explains step by step in simple English, like a patient teacher.",
    how: [
      "Snap a question from your textbook or a past paper, or type it in your own words.",
      "Get the working one step at a time, with the final answer clearly marked.",
      "Ask it to explain again, give you a quick quiz or make a study plan. It only helps with schoolwork.",
    ],
    screen: (p) => <AiScreen play={p} />,
  },
  {
    key: "study", icon: VideoCamera, tag: "4 · Study hub", title: "Learn it properly, then practise",
    text: "Everything you need to study in one place, organised by subject and topic.",
    how: [
      "Past questions in study mode, with the answer and explanation under each one.",
      "Video solutions that walk you through the answer, plus topic lessons and lesson notes.",
      "JAMB literature novels, the syllabus and brochures. Download to study offline.",
    ],
    screen: (p) => <StudyScreen play={p} />,
  },
  {
    key: "compete", icon: Trophy, tag: "5 · Challenges", title: "Practise with all of Nigeria",
    text: "Weekly challenges and leaderboards keep you going. See where you stand in Nigeria and in your state.",
    how: [
      "Join weekly challenges: same questions for everyone, fair play checked.",
      "Climb the national and state leaderboards with your best mock score.",
      "Win Premium days and XP, keep your streak, and watch your rank rise.",
    ],
    screen: (p) => <LeaderScreen play={p} />,
  },
];

function StepText({ s, i, onSeen }: { s: Step; i: number; onSeen: (i: number) => void }) {
  const ref = useRef<HTMLDivElement>(null);
  const seen = useInView(ref, { amount: 0.55 });
  const still = useReducedMotion();
  useEffect(() => { if (seen) onSeen(i); }, [seen, i, onSeen]);
  const Icon = s.icon;
  return (
    <div ref={ref} className="hidden min-h-[78vh] flex-col justify-center lg:flex">
      <motion.div className="relative" initial={still ? false : { opacity: 0, y: 30 }} whileInView={{ opacity: 1, y: 0 }} viewport={{ once: false, amount: 0.4 }} transition={{ duration: 0.6, ease }}>
        <span className="pointer-events-none absolute -left-2 -top-16 select-none text-[140px] font-bold leading-none text-[#0B1F44]/[0.05] dark:text-white/[0.05]" aria-hidden>0{i + 1}</span>
        <span className="inline-flex items-center gap-2 rounded-full bg-[#EEF2F9] px-3 py-1.5 text-xs font-bold uppercase tracking-wider text-[#2563B3] dark:bg-white/10 dark:text-[#8FB6EE]">
          <Icon size={16} weight="fill" /> {s.tag}
        </span>
        <h3 className="mt-4 st-h3 font-bold">{s.title}</h3>
        <p className="mt-3 max-w-lg st-lead text-muted-foreground">{s.text}</p>
        <ol className="mt-6 space-y-4">
          {s.how.map((h, k) => (
            <motion.li key={k} initial={still ? false : { opacity: 0, x: -16 }} whileInView={{ opacity: 1, x: 0 }} viewport={{ once: false, amount: 0.6 }} transition={{ delay: 0.12 * k, duration: 0.45, ease }}
              className="flex gap-4">
              <span className="grid size-9 shrink-0 place-items-center rounded-xl bg-[#0B1F44] text-sm font-bold text-white dark:bg-white dark:text-[#0B1F44]">{k + 1}</span>
              <span className="pt-1.5 text-[15px] leading-6">{h}</span>
            </motion.li>
          ))}
        </ol>
      </motion.div>
    </div>
  );
}

/**
 * Phones and tablets (owner, 16 Nov 2026: the tour was five tall phones in a row): one swipeable card per feature,
 * the live phone on top and the words under it, with dots and arrows. Only the card in view plays.
 */
function MobileTour() {
  const track = useRef<HTMLDivElement>(null);
  const [at, setAt] = useState(0);
  const screen = useScreen();
  const visible = useInView(track, { amount: 0.3 });
  const phoneW = fitPhone(screen, { max: 270, min: 210, vw: 0.6, reserve: 330 });
  const go = (i: number) => {
    const el = track.current;
    if (!el) return;
    const k = Math.max(0, Math.min(STEPS.length - 1, i));
    el.scrollTo({ left: (el.children[k] as HTMLElement).offsetLeft - el.offsetLeft, behavior: "smooth" });
  };
  return (
    <div className="lg:hidden">
      <div ref={track} className="-mx-4 flex snap-x snap-mandatory gap-4 overflow-x-auto px-4 pb-2 [scrollbar-width:none] sm:-mx-8 sm:px-8 [&::-webkit-scrollbar]:hidden"
        onScroll={(e) => {
          const el = e.currentTarget;
          const w = (el.children[0] as HTMLElement | undefined)?.offsetWidth ?? 1;
          setAt(Math.round(el.scrollLeft / (w + 16)));
        }}>
        {STEPS.map((s, i) => {
          const Icon = s.icon;
          return (
            <article key={s.key} className="w-[86%] shrink-0 snap-center rounded-[28px] border bg-card p-5 shadow-[var(--shadow-1)] sm:w-[70%]">
              <div className="rounded-3xl bg-[radial-gradient(closest-side,rgba(37,99,179,.18),transparent)] py-3">
                <Phone3D width={phoneW} float={false} tilt={false}>{s.screen(visible && i === at)}</Phone3D>
              </div>
              <span className="mt-4 inline-flex items-center gap-2 rounded-full bg-[#EEF2F9] px-3 py-1.5 text-[11px] font-bold uppercase tracking-wider text-[#2563B3] dark:bg-white/10 dark:text-[#8FB6EE]">
                <Icon size={14} weight="fill" /> {s.tag}
              </span>
              <h3 className="mt-3 text-[22px] font-bold leading-tight tracking-tight">{s.title}</h3>
              <p className="mt-2 text-[15px] leading-6 text-muted-foreground">{s.text}</p>
            </article>
          );
        })}
      </div>
      <div className="mt-5 flex items-center justify-center gap-4">
        <button type="button" aria-label="Previous feature" onClick={() => go(at - 1)} disabled={at === 0}
          className="grid size-11 place-items-center rounded-full border bg-card disabled:opacity-40"><CaretLeft size={18} weight="bold" /></button>
        <div className="flex gap-1.5" aria-hidden>
          {STEPS.map((s, i) => <motion.span key={s.key} className="h-2 rounded-full bg-[#2563B3]" animate={{ width: i === at ? 22 : 8, opacity: i === at ? 1 : 0.3 }} />)}
        </div>
        <button type="button" aria-label="Next feature" onClick={() => go(at + 1)} disabled={at === STEPS.length - 1}
          className="grid size-11 place-items-center rounded-full border bg-card disabled:opacity-40"><CaretRight size={18} weight="bold" /></button>
      </div>
    </div>
  );
}

/** Feature tour: on large screens a sticky 3D phone shows each feature live while its steps scroll past. */
export function FeatureTour() {
  const [active, setActive] = useState(0);
  const still = useReducedMotion();
  const box = useRef<HTMLElement>(null);
  const tourOn = useInView(box); // the sticky phone stops when the tour is off screen (D-131)
  // The sticky phone fits the window height (owner, 16 Nov 2026: too big on 768 px laptops).
  const phoneW = fitPhone(useScreen(), { max: 340, min: 240, reserve: 170 });
  return (
    <section ref={box} id="features" className="relative scroll-mt-20 bg-background st-sec">
      <div className="pointer-events-none absolute inset-x-0 top-0 h-40 bg-gradient-to-b from-[#EEF2F9] to-transparent dark:from-[#0A1730]" aria-hidden />
      <div className="relative st-wrap">
        <motion.div initial={still ? false : { opacity: 0, y: 24 }} whileInView={{ opacity: 1, y: 0 }} viewport={{ once: true }} transition={{ duration: 0.6, ease }} className="mx-auto max-w-2xl text-center">
          <p className="text-sm font-bold uppercase tracking-wider text-[#2563B3]">See it working</p>
          <h2 className="mt-3 st-h2 font-bold">How SolutionTee helps you pass, step by step</h2>
          <p className="mt-4 text-[17px] text-muted-foreground">Scroll through the app as a student uses it: practise, see your result, get help, study and compete.</p>
        </motion.div>
        <div className="mt-10 grid gap-10 lg:mt-4 lg:grid-cols-[1fr_minmax(0,420px)]">
          <div className="min-w-0">
            <MobileTour />
            {STEPS.map((s, i) => <StepText key={s.key} s={s} i={i} onSeen={setActive} />)}
          </div>
          <div className="hidden lg:block">
            <div className="sticky top-[12vh] flex h-[76vh] items-center justify-center">
              <div className="absolute size-[520px] bg-[radial-gradient(closest-side,rgba(37,99,179,.25),transparent)]" aria-hidden />
              <Phone3D width={phoneW}>
                <AnimatePresence mode="wait">
                  <motion.div key={STEPS[active].key} className="h-full w-full"
                    initial={still ? false : { opacity: 0, scale: 1.03 }} animate={{ opacity: 1, scale: 1 }} exit={{ opacity: 0, scale: 0.97 }} transition={{ duration: 0.4, ease }}>
                    {STEPS[active].screen(tourOn)}
                  </motion.div>
                </AnimatePresence>
              </Phone3D>
              <div className="absolute -right-2 top-1/2 flex -translate-y-1/2 flex-col gap-2" aria-hidden>
                {STEPS.map((s, i) => <motion.span key={s.key} className="w-1.5 rounded-full bg-[#2563B3]" animate={{ height: i === active ? 28 : 8, opacity: i === active ? 1 : 0.3 }} />)}
              </div>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}
