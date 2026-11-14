import Link from "next/link";
import type { Metadata } from "next";
import { ArrowRight, CalendarBlank, ChalkboardTeacher, Clock, LockKey, PlayCircle, ShieldCheck, Users, VideoCamera } from "@phosphor-icons/react/dist/ssr";
import { SiteNav } from "../site/_components/nav";
import { Faq, HowItWorks, SiteFooter } from "../site/_components/sections";
import { Reveal } from "../site/_components/motion";
import { classImg, classesPageData, lagosDate, lagosWhen, ngn, programsData, type PublicProgram } from "./data";
import { Countdown } from "./_ui";

export const metadata: Metadata = {
  title: "Live classes",
  description: "Live online JAMB classes with real teachers. Pay once, join every session from your phone or laptop, and watch the recordings.",
};

const TRUST = [
  { icon: LockKey, title: "Secure payment", text: "Paid through Paystack: card, bank transfer or USSD." },
  { icon: ChalkboardTeacher, title: "Real teachers", text: "Live, step by step, with time for your questions." },
  { icon: PlayCircle, title: "Recordings", text: "Missed a session? Watch it again later." },
  { icon: ShieldCheck, title: "Pay once", text: "One payment covers every session of the class." },
];

function ProgramCard({ p, i }: { p: PublicProgram; i: number }) {
  const img = classImg(p.flyer_path);
  return (
    <Reveal delay={0.06 * i}>
      <Link href={`/classes/${p.slug}`} className="group flex h-full flex-col overflow-hidden rounded-3xl border bg-card shadow-[0_10px_40px_-24px_rgba(11,31,68,.45)] transition duration-300 hover:-translate-y-1 hover:shadow-[0_24px_60px_-28px_rgba(11,31,68,.55)]">
        <div className="relative aspect-[4/5] overflow-hidden bg-[#0B1F44]">
          {img ? (
            // eslint-disable-next-line @next/next/no-img-element
            <img src={img} alt={`${p.title} flyer`} loading="lazy" className="size-full object-cover transition duration-500 group-hover:scale-[1.04]" />
          ) : (
            <div className="grid size-full place-items-center bg-[radial-gradient(circle_at_30%_20%,#2563B3,#0B1F44_70%)] p-6 text-center">
              <p className="text-2xl font-bold text-white">{p.title}</p>
            </div>
          )}
          <div className="absolute inset-x-0 bottom-0 h-1/3 bg-gradient-to-t from-black/60 to-transparent" />
          {p.next?.live ? (
            <span className="absolute left-3 top-3 inline-flex items-center gap-1.5 rounded-full bg-[#E5484D] px-3 py-1 text-xs font-bold text-white"><span className="size-2 animate-pulse rounded-full bg-white" /> Live now</span>
          ) : null}
          {p.seats_left !== null && p.seats_left > 0 && p.seats_left <= 30 ? (
            <span className="absolute right-3 top-3 rounded-full bg-white/95 px-3 py-1 text-xs font-bold text-[#B8620A]">{p.seats_left} seats left</span>
          ) : null}
          <div className="absolute bottom-3 left-3 flex items-end gap-2">
            <span className="rounded-xl bg-[#F2B233] px-3 py-1.5 text-lg font-bold text-[#0B1F44]">{ngn(p.price_kobo ?? 0)}</span>
            {p.compare_kobo && p.compare_kobo > (p.price_kobo ?? 0) ? <s className="pb-1 text-sm font-semibold text-white/80">{ngn(p.compare_kobo)}</s> : null}
          </div>
        </div>
        <div className="flex flex-1 flex-col p-5">
          {p.exam ? <p className="text-xs font-bold uppercase tracking-wider text-[#2563B3]">{p.exam}{p.subjects ? ` · ${p.subjects}` : ""}</p> : null}
          <h3 className="mt-1 text-xl font-bold leading-snug">{p.title}</h3>
          {p.tagline ? <p className="mt-1 line-clamp-2 text-sm text-muted-foreground">{p.tagline}</p> : null}
          <div className="mt-3 space-y-1.5 text-sm">
            {p.schedule_note ? <p className="flex items-center gap-2"><CalendarBlank size={16} className="text-[#2563B3]" /> {p.schedule_note}</p> : null}
            {p.teacher ? <p className="flex items-center gap-2"><ChalkboardTeacher size={16} className="text-[#2563B3]" /> with {p.teacher}</p> : null}
            {p.starts_on ? <p className="flex items-center gap-2"><Clock size={16} className="text-[#2563B3]" /> Starts {lagosDate(p.starts_on)}</p> : null}
          </div>
          {p.next && !p.next.live ? (
            <div className="mt-4 rounded-2xl bg-muted/60 p-3">
              <p className="mb-1.5 text-xs font-bold text-muted-foreground">Next session in</p>
              <Countdown to={p.next.starts_at} size="sm" />
            </div>
          ) : null}
          <span className="mt-auto flex items-center gap-1.5 pt-4 text-sm font-bold text-[#0B1F44] dark:text-[#F2B233]">See details and join <ArrowRight size={16} weight="bold" className="transition group-hover:translate-x-1" /></span>
        </div>
      </Link>
    </Reveal>
  );
}

/** cbt.solutiontee.com/classes (D-148, D-163): paid live classes students buy once, with flyers, full details and payment. */
export default async function Page() {
  const [{ page, classes }, programs] = await Promise.all([classesPageData(), programsData()]);
  const oneOff = classes.filter((c) => c.access === "paid");
  return (
    <>
      <SiteNav links={[["/", "Home"], ["#classes", "Classes"], ["/classes/me", "My classes"]]} />
      <main>
        <section className="relative overflow-hidden bg-[#0B1F44] pb-20 pt-28 text-white sm:pt-32">
          <div className="pointer-events-none absolute -right-32 -top-32 size-[28rem] rounded-full bg-[#2563B3]/40 blur-3xl motion-safe:animate-[pulse_8s_ease-in-out_infinite]" />
          <div className="pointer-events-none absolute -bottom-40 -left-24 size-[26rem] rounded-full bg-[#F2B233]/20 blur-3xl motion-safe:animate-[pulse_10s_ease-in-out_infinite]" />
          <div className="relative mx-auto max-w-6xl px-4 sm:px-6">
            <Reveal>
              <p className="inline-flex items-center gap-2 rounded-full bg-white/10 px-3 py-1 text-sm font-bold text-[#F2B233]"><VideoCamera size={18} weight="fill" /> Live online classes</p>
              <h1 className="mt-4 max-w-3xl text-4xl font-bold leading-tight tracking-tight sm:text-6xl">{page.title}</h1>
              <p className="mt-4 max-w-2xl text-lg leading-8 text-[#C9D5EA]">{page.intro || "Learn live with real teachers. Pay once for a class and join every session, from your phone or laptop. Missed one? Watch the recording."}</p>
              <div className="mt-8 flex flex-wrap gap-3">
                <a href="#classes" className="inline-flex h-12 items-center gap-2 rounded-2xl bg-[#F2B233] px-6 font-bold text-[#0B1F44] transition hover:brightness-105">See the classes <ArrowRight size={18} weight="bold" /></a>
                <Link href="/classes/me" className="inline-flex h-12 items-center rounded-2xl border border-white/25 px-6 font-bold transition hover:bg-white/10">My classes</Link>
              </div>
            </Reveal>
            <div className="mt-12 grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
              {TRUST.map((t, i) => (
                <Reveal key={t.title} delay={0.08 * i}>
                  <div className="h-full rounded-2xl border border-white/10 bg-white/5 p-4 backdrop-blur-sm">
                    <t.icon size={24} weight="fill" className="text-[#F2B233]" />
                    <p className="mt-2 font-bold">{t.title}</p>
                    <p className="text-sm text-[#AFC0DD]">{t.text}</p>
                  </div>
                </Reveal>
              ))}
            </div>
          </div>
        </section>

        <section id="classes" className="scroll-mt-20 py-16 sm:py-20">
          <div className="mx-auto max-w-6xl px-4 sm:px-6">
            <Reveal>
              <h2 className="text-3xl font-bold tracking-tight sm:text-4xl">Choose your class</h2>
              <p className="mt-2 text-muted-foreground">All times are Lagos time. Tap a class to see everything about it and join.</p>
            </Reveal>
            {programs.length === 0 && oneOff.length === 0 ? (
              <p className="mt-8 rounded-3xl border bg-card p-8 text-center text-muted-foreground">New classes are coming soon. Check back, or follow us for the announcement.</p>
            ) : (
              <div className="mt-8 grid gap-6 sm:grid-cols-2 lg:grid-cols-3">
                {programs.map((p, i) => <ProgramCard key={p.id} p={p} i={i} />)}
              </div>
            )}
            {oneOff.length ? (
              <div className="mt-12">
                <h3 className="text-xl font-bold">One-off classes</h3>
                <ul className="mt-4 grid gap-3 sm:grid-cols-2">
                  {oneOff.map((c) => (
                    <li key={c.id} className="flex items-center gap-4 rounded-2xl border bg-card p-4">
                      <div className="min-w-0 flex-1">
                        <p className="font-bold">{c.title}</p>
                        <p className="text-sm text-muted-foreground">{lagosWhen(c.starts_at)} · {c.minutes} min · {c.teacher}</p>
                        {c.seats_left !== null ? <p className="text-xs text-muted-foreground"><Users size={12} className="inline" /> {c.seats_left > 0 ? `${c.seats_left} seats left` : "Full"}</p> : null}
                      </div>
                      <Link href={`/classes/me?class=${c.id}`} className="inline-flex h-10 shrink-0 items-center rounded-xl bg-[#0B1F44] px-4 text-sm font-bold text-white dark:bg-[#F2B233] dark:text-[#0B1F44]">{ngn(c.price_kobo ?? 0)}</Link>
                    </li>
                  ))}
                </ul>
              </div>
            ) : null}
          </div>
        </section>

        <HowItWorks title="How it works" steps={[
          { title: "Choose a class", text: "See the timetable, the teacher and everything the class covers." },
          { title: "Pay once, securely", text: "Sign in with your email and pay with Paystack. You get a receipt by email." },
          { title: "Join every session", text: "Join live from the SolutionTee app or My classes. We remind you before each session." },
        ]} />

        {page.teachers.length ? (
          <section className="bg-[#F4F6FA] py-16 dark:bg-[#0A1730]">
            <div className="mx-auto max-w-6xl px-4 sm:px-6">
              <Reveal><h2 className="text-3xl font-bold tracking-tight">Your teachers</h2></Reveal>
              <ul className="mt-8 grid gap-4 sm:grid-cols-3">
                {page.teachers.map((t, i) => (
                  <Reveal key={t.name} delay={0.06 * i}>
                    <li className="h-full rounded-2xl border bg-card p-5">
                      <span className="grid size-12 place-items-center rounded-full bg-[#0B1F44] text-lg font-bold text-[#F2B233]">{t.name.slice(0, 1)}</span>
                      <p className="mt-3 font-bold">{t.name}</p>
                      {t.subject ? <p className="text-sm text-muted-foreground">{t.subject}</p> : null}
                      {t.bio ? <p className="mt-2 text-sm">{t.bio}</p> : null}
                    </li>
                  </Reveal>
                ))}
              </ul>
            </div>
          </section>
        ) : null}

        {page.faq.length ? <Faq title="Questions about the classes" items={page.faq} /> : null}
      </main>
      <SiteFooter />
    </>
  );
}
