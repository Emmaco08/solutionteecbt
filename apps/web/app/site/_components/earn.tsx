"use client";
import { motion, useInView } from "motion/react";
import { useRef } from "react";
import { CheckCircle, Gift, Megaphone, Trophy } from "@phosphor-icons/react";
import { Phone3D, fitPhone, useScreen } from "./phone";
import { ChallengeScreen, InviteScreen } from "./screens";
import { Reveal, ease } from "./motion";

/** "Invite friends and earn" / "Practise in challenges and win" (D-122). Texts come from admin → Website, already filled. */
export function EarnSection({ kind, eyebrow, title, text, points, cash }: {
  kind: "invite" | "challenges"; eyebrow: string; title: string; text: string; points: string[]; cash: boolean;
}) {
  const ref = useRef<HTMLDivElement>(null);
  const inView = useInView(ref, { amount: 0.35 });
  const invite = kind === "invite";
  const screen = useScreen();
  const phoneW = screen.w >= 1024 ? fitPhone(screen, { max: 310, min: 240, reserve: 140 }) : fitPhone(screen, { max: 290, min: 220, vw: 0.7 });
  const Icon = invite ? Gift : Trophy;
  return (
    <section id={kind} className={`scroll-mt-20 overflow-hidden st-sec ${invite ? "bg-background" : "bg-[#F4F6FA] dark:bg-[#0A1730]"}`}>
      <div ref={ref} className={`st-wrap grid items-center gap-14 lg:grid-cols-2 ${invite ? "" : "lg:[&>*:first-child]:order-2"}`}>
        <div>
          <Reveal>
            <p className="inline-flex items-center gap-2 text-sm font-bold uppercase tracking-wider text-[#2563B3]"><Icon size={18} weight="fill" /> {eyebrow}</p>
            <h2 className="mt-3 st-h2 font-bold">{title}</h2>
            <p className="mt-4 max-w-xl st-lead text-muted-foreground">{text}</p>
          </Reveal>
          <ul className="mt-8 space-y-3">
            {points.map((p, i) => (
              <motion.li key={p} initial={{ opacity: 0, x: -16 }} whileInView={{ opacity: 1, x: 0 }} viewport={{ once: true, amount: 0.6 }}
                transition={{ duration: 0.5, delay: 0.08 * i, ease }} className="flex items-start gap-3 rounded-2xl border bg-card px-4 py-3.5 text-[15px] font-bold">
                <CheckCircle size={22} weight="fill" className="mt-0.5 shrink-0 text-[#16A34A]" /> {p}
              </motion.li>
            ))}
          </ul>
        </div>
        <Reveal className="relative mx-auto">
          <div className="pointer-events-none absolute inset-0 -z-10 m-auto size-[560px] bg-[radial-gradient(closest-side,rgba(242,178,51,.25),transparent)]" aria-hidden />
          <Phone3D width={phoneW}>{invite ? <InviteScreen play={inView} cash={cash} /> : <ChallengeScreen play={inView} cash={cash} />}</Phone3D>
        </Reveal>
      </div>
    </section>
  );
}

/** A thin bar above the menu for news ("Weekly challenge on Saturday!"), from admin → Website. */
export function Announcement({ text, link }: { text: string; link: string }) {
  const inner = <><Megaphone size={16} weight="fill" className="shrink-0" /> <span className="truncate">{text}</span></>;
  return (
    <div className="relative z-50 bg-[#F2B233] text-[#0B1F44]">
      {link ? (
        <a href={link} className="st-wrap flex h-10 items-center justify-center gap-2 text-sm font-bold hover:underline">{inner}</a>
      ) : (
        <p className="st-wrap flex h-10 items-center justify-center gap-2 text-sm font-bold">{inner}</p>
      )}
    </div>
  );
}
