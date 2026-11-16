"use client";
import { useEffect, useRef, useState } from "react";
import { useInView } from "motion/react";
import { Check, WindowsLogo } from "@phosphor-icons/react";
import { DesktopCbtScreen, Laptop3D } from "./laptop";
import { Reveal } from "./motion";

const POINTS = [
  "The same account and Premium as your phone",
  "A real CBT on a big screen: keyboard keys and a calculator, like the exam centre",
  "Game Zone, Community, AI tutor, videos and notes",
  "Downloaded tests keep working without internet",
];

/** "Now on Windows" (owner, 16 Nov 2026): a laptop that opens as it scrolls in and shows the Windows app being used. */
export function WindowsSection() {
  const box = useRef<HTMLDivElement>(null);
  const live = useInView(box, { margin: "-80px" });
  const [w, setW] = useState(620);
  useEffect(() => {
    const el = box.current;
    if (!el) return;
    const ro = new ResizeObserver(([e]) => setW(Math.min(760, Math.max(280, Math.round(e.contentRect.width / 1.12)))));
    ro.observe(el);
    return () => ro.disconnect();
  }, []);
  return (
    <section id="windows" className="scroll-mt-20 overflow-hidden bg-[#F4F6FA] py-20 dark:bg-[#0A1730] sm:py-24">
      <div className="mx-auto grid max-w-6xl items-center gap-12 px-4 sm:px-6 lg:grid-cols-[minmax(0,.78fr)_minmax(0,1.22fr)]">
        <Reveal>
          <span className="inline-flex items-center gap-2 rounded-full bg-[#0B1F44] px-3 py-1 text-xs font-bold uppercase tracking-wider text-white">
            <WindowsLogo size={14} weight="fill" /> New · Windows app
          </span>
          <h2 className="mt-4 text-[32px] font-bold tracking-tight sm:text-[40px]">Practise on your laptop too</h2>
          <p className="mt-4 max-w-xl text-[17px] leading-7 text-muted-foreground">
            The full SolutionTee CBT app for Windows computers. Sit your mock on a big screen, the way the real JAMB CBT feels.
          </p>
          <ul className="mt-6 space-y-3">
            {POINTS.map((p) => (
              <li key={p} className="flex items-start gap-3 text-[15px]">
                <span className="mt-0.5 grid size-6 shrink-0 place-items-center rounded-full bg-[#F2B233] text-[#0B1F44]"><Check size={14} weight="bold" /></span>
                {p}
              </li>
            ))}
          </ul>
          <div className="mt-8 flex flex-col gap-2">
            <a href="/download/windows" className="inline-flex h-14 items-center justify-center gap-2.5 self-start whitespace-nowrap rounded-2xl bg-[#0B1F44] px-6 font-bold text-white transition-transform hover:-translate-y-0.5 dark:bg-[#F2B233] dark:text-[#0B1F44]">
              <WindowsLogo size={22} weight="fill" /> Download for Windows
            </a>
            <span className="text-sm text-muted-foreground">Windows 10 or 11 · 64-bit · free to start</span>
          </div>
          <p className="mt-3 text-xs text-muted-foreground">If Windows shows “Windows protected your PC”, click More info, then Run anyway.</p>
        </Reveal>
        <div ref={box} className="relative pb-4">
          <div className="pointer-events-none absolute -right-10 top-10 size-72 rounded-full bg-[#2563B3]/20 blur-3xl" aria-hidden />
          <div className="pointer-events-none absolute -bottom-10 left-0 size-60 rounded-full bg-[#F2B233]/20 blur-3xl" aria-hidden />
          <Laptop3D width={w}><DesktopCbtScreen play={live} /></Laptop3D>
        </div>
      </div>
    </section>
  );
}
