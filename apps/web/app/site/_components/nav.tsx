"use client";
import Link from "next/link";
import { AnimatePresence, motion, useMotionValueEvent, useScroll } from "motion/react";
import { useState } from "react";
import { List, X } from "@phosphor-icons/react";

const LINKS = [
  ["#features", "Features"],
  ["#ai", "AI tutor"],
  ["#pricing", "Pricing"],
  ["#faq", "FAQ"],
] as const;

export function SiteNav() {
  const { scrollY } = useScroll();
  const [solid, setSolid] = useState(false);
  const [open, setOpen] = useState(false);
  useMotionValueEvent(scrollY, "change", (y) => setSolid(y > 24));
  return (
    <header className={`fixed inset-x-0 top-0 z-50 transition-colors duration-300 ${solid || open ? "bg-[#06132B]/85 shadow-[0_1px_0_rgba(255,255,255,.08)] backdrop-blur-md" : "bg-transparent"}`}>
      <nav className="mx-auto flex h-16 max-w-6xl items-center justify-between px-4 sm:px-6" aria-label="Main">
        <Link href="/" className="flex items-center gap-2.5 text-white" aria-label="SolutionTee CBT home">
          {/* Real brand mark from /brand (never redrawn) */}
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img src="/brand/favicon.svg" alt="" className="size-9 rounded-xl" />
          <span className="text-[17px] font-bold tracking-tight">SolutionTee <span className="text-[#F2B233]">CBT</span></span>
        </Link>
        <div className="hidden items-center gap-7 md:flex">
          {LINKS.map(([href, label]) => (
            <a key={href} href={href} className="text-sm font-medium text-[#C9D5EA] transition-colors hover:text-white">{label}</a>
          ))}
          <Link href="/pay" className="text-sm font-medium text-[#C9D5EA] transition-colors hover:text-white">Pay</Link>
          <a href="#download" className="inline-flex h-10 items-center rounded-xl bg-[#F2B233] px-4 text-sm font-bold text-[#0B1F44] transition-transform hover:-translate-y-0.5">Get the app</a>
        </div>
        <button type="button" className="grid size-11 place-items-center rounded-xl text-white md:hidden" aria-label={open ? "Close menu" : "Open menu"} aria-expanded={open} onClick={() => setOpen(!open)}>
          {open ? <X size={24} /> : <List size={24} />}
        </button>
      </nav>
      <AnimatePresence>
        {open ? (
          <motion.div initial={{ height: 0, opacity: 0 }} animate={{ height: "auto", opacity: 1 }} exit={{ height: 0, opacity: 0 }} className="overflow-hidden md:hidden">
            <div className="flex flex-col gap-1 px-4 pb-4">
              {LINKS.map(([href, label]) => (
                <a key={href} href={href} onClick={() => setOpen(false)} className="rounded-xl px-3 py-3 text-base font-medium text-white hover:bg-white/5">{label}</a>
              ))}
              <Link href="/pay" onClick={() => setOpen(false)} className="rounded-xl px-3 py-3 text-base font-medium text-white hover:bg-white/5">Pay for Premium</Link>
              <a href="#download" onClick={() => setOpen(false)} className="mt-2 inline-flex h-12 items-center justify-center rounded-xl bg-[#F2B233] font-bold text-[#0B1F44]">Get the app</a>
            </div>
          </motion.div>
        ) : null}
      </AnimatePresence>
    </header>
  );
}
