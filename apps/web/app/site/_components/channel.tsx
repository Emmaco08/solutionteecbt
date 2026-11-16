"use client";
import { motion, useReducedMotion } from "motion/react";
import { ArrowRight, WhatsappLogo } from "@phosphor-icons/react";
import { Reveal } from "./motion";

/** "Join our WhatsApp channel" (owner, 16 Nov 2026, D-174): the link the admin sets in Admin → Flags & settings.
 *  Plain like the app card: title, words, button; no perk pills or "Free · WhatsApp" badge (D-180). */
export function ChannelBand({ url, title, text }: { url: string; title: string; text: string }) {
  const still = useReducedMotion();
  return (
    <section id="channel" className="scroll-mt-20 bg-background pb-[clamp(56px,7vw,112px)]">
      <div className="st-wrap">
        <Reveal>
          <div className="relative overflow-hidden rounded-[32px] bg-[linear-gradient(120deg,#0A3B2C_0%,#0E6B4B_55%,#1FAF5F_100%)] px-6 py-10 text-white sm:px-10 sm:py-12 lg:px-14">
            {/* Rising bubbles: a CSS loop, no JavaScript while scrolling (D-131) */}
            <div className="pointer-events-none absolute inset-0" aria-hidden>
              {[8, 22, 37, 55, 68, 81, 93].map((x, i) => (
                <span key={x} className="st-bubble absolute bottom-[-40px] rounded-full border border-white/20 bg-white/[.06]"
                  style={{ left: `${x}%`, width: 14 + (i % 3) * 12, height: 14 + (i % 3) * 12, animationDelay: `${i * 1.3}s`, animationDuration: `${9 + (i % 4) * 2}s` }} />
              ))}
              <div className="absolute -bottom-32 -right-20 size-96 rounded-full bg-white/[.06]" />
            </div>
            <div className="relative grid items-center gap-8 lg:grid-cols-[auto_minmax(0,1fr)_auto]">
              <div className="relative mx-auto grid size-24 place-items-center sm:size-28">
                {!still ? [0, 1].map((k) => (
                  <motion.span key={k} className="absolute inset-0 rounded-full border-2 border-[#25D366]/70"
                    animate={{ scale: [1, 1.55], opacity: [0.7, 0] }} transition={{ duration: 2, repeat: Infinity, delay: k * 1, ease: "easeOut" }} />
                )) : null}
                <motion.span className="grid size-full place-items-center rounded-full bg-white text-[#1FAF5F] shadow-[0_0_40px_rgba(37,211,102,.45)]"
                  animate={still ? undefined : { scale: [1, 1.06, 1] }} transition={{ duration: 2.4, repeat: Infinity, ease: "easeInOut" }}>
                  <WhatsappLogo size={52} weight="fill" />
                </motion.span>
              </div>
              <div className="text-center lg:text-left">
                <h2 className="st-h2 font-bold">{title}</h2>
                <p className="st-lead mx-auto mt-2 max-w-xl text-white/85 lg:mx-0">{text}</p>
              </div>
              <a href={url} target="_blank" rel="noopener noreferrer"
                className="group inline-flex h-14 items-center justify-center gap-2.5 whitespace-nowrap rounded-2xl bg-white px-7 font-bold text-[#0A3B2C] shadow-[0_18px_40px_-14px_rgba(0,0,0,.45)] transition-transform hover:-translate-y-0.5">
                <WhatsappLogo size={22} weight="fill" className="text-[#1FAF5F]" /> Join the channel
                <ArrowRight size={16} weight="bold" className="transition-transform group-hover:translate-x-1" />
              </a>
            </div>
          </div>
        </Reveal>
      </div>
    </section>
  );
}
