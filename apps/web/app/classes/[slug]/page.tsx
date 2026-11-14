import { Suspense } from "react";
import Link from "next/link";
import { notFound } from "next/navigation";
import type { Metadata } from "next";
import { ArrowLeft, CalendarBlank, ChalkboardTeacher, CheckCircle, Clock, PlayCircle, VideoCamera } from "@phosphor-icons/react/dist/ssr";
import { SiteNav } from "../../site/_components/nav";
import { Faq, SiteFooter } from "../../site/_components/sections";
import { Reveal } from "../../site/_components/motion";
import { classImg, lagosDate, lagosWhen, ngn, programData } from "../data";
import { BuyBox, Countdown } from "../_ui";

export async function generateMetadata({ params }: { params: Promise<{ slug: string }> }): Promise<Metadata> {
  const { slug } = await params;
  const p = await programData(slug);
  if (!p) return { title: "Class not found" };
  const img = classImg(p.flyer_path);
  return {
    title: p.title,
    description: p.tagline ?? `Live online class with ${p.teacher ?? "SolutionTee teachers"}. Pay once and join every session.`,
    openGraph: img ? { images: [{ url: img }] } : undefined,
  };
}

/** cbt.solutiontee.com/classes/[slug] (D-163): everything about one paid class, its timetable, teacher, FAQ and Pay. */
export default function Page({ params }: { params: Promise<{ slug: string }> }) {
  return (
    <Suspense fallback={<Loading />}>
      <ProgramBody params={params} />
    </Suspense>
  );
}

/** Shown for a moment while the class loads (the page is built on request, then cached for minutes). */
function Loading() {
  return (
    <>
      <SiteNav links={[["/classes", "All classes"], ["/classes/me", "My classes"]]} />
      <main className="bg-[#0B1F44] pb-12 pt-24 sm:pt-28">
        <div className="mx-auto grid max-w-6xl gap-8 px-4 sm:px-6 lg:grid-cols-[minmax(0,5fr)_minmax(0,7fr)]">
          <div className="aspect-[4/5] animate-pulse rounded-3xl bg-white/10" />
          <div className="space-y-4">
            <div className="h-4 w-32 animate-pulse rounded bg-white/10" />
            <div className="h-12 w-3/4 animate-pulse rounded-xl bg-white/10" />
            <div className="h-6 w-2/3 animate-pulse rounded bg-white/10" />
            <div className="h-40 animate-pulse rounded-2xl bg-white/10" />
          </div>
        </div>
      </main>
    </>
  );
}

async function ProgramBody({ params }: { params: Promise<{ slug: string }> }) {
  const { slug } = await params;
  const p = await programData(slug);
  if (!p) notFound();
  const img = classImg(p.flyer_path);
  const photo = classImg(p.teacher_photo);
  const next = p.sessions[0] ?? null;
  return (
    <>
      <SiteNav links={[["/classes", "All classes"], ["/classes/me", "My classes"]]} />
      <main className="pb-28 lg:pb-0">
        <section className="relative overflow-hidden bg-[#0B1F44] pb-12 pt-24 text-white sm:pt-28">
          <div className="pointer-events-none absolute -right-40 -top-40 size-[30rem] rounded-full bg-[#2563B3]/40 blur-3xl" />
          <div className="relative mx-auto max-w-6xl px-4 sm:px-6">
            <Link href="/classes" className="inline-flex items-center gap-1.5 text-sm font-semibold text-[#C9D5EA] hover:text-white"><ArrowLeft size={16} /> All classes</Link>
            <div className="mt-6 grid items-start gap-8 lg:grid-cols-[minmax(0,5fr)_minmax(0,7fr)]">
              <Reveal>
                <div className="overflow-hidden rounded-3xl bg-white/5 shadow-[0_30px_80px_-30px_rgba(0,0,0,.7)] ring-1 ring-white/10">
                  {img ? (
                    // eslint-disable-next-line @next/next/no-img-element
                    <img src={img} alt={`${p.title} flyer`} className="aspect-[4/5] w-full object-cover" />
                  ) : (
                    <div className="grid aspect-[4/5] place-items-center bg-[radial-gradient(circle_at_30%_20%,#2563B3,#0B1F44_70%)] p-8 text-center text-3xl font-bold">{p.title}</div>
                  )}
                </div>
              </Reveal>
              <Reveal delay={0.08}>
                {p.exam ? <p className="text-sm font-bold uppercase tracking-wider text-[#F2B233]">{p.exam}{p.subjects ? ` · ${p.subjects}` : ""}</p> : null}
                <h1 className="mt-2 text-4xl font-bold leading-tight tracking-tight sm:text-5xl">{p.title}</h1>
                {p.tagline ? <p className="mt-3 text-lg leading-8 text-[#C9D5EA]">{p.tagline}</p> : null}
                <div className="mt-5 flex flex-wrap gap-2 text-sm">
                  {p.schedule_note ? <span className="inline-flex items-center gap-1.5 rounded-full bg-white/10 px-3 py-1.5"><CalendarBlank size={16} /> {p.schedule_note}</span> : null}
                  {p.starts_on ? <span className="inline-flex items-center gap-1.5 rounded-full bg-white/10 px-3 py-1.5"><Clock size={16} /> {lagosDate(p.starts_on)}{p.ends_on ? ` – ${lagosDate(p.ends_on)}` : ""}</span> : null}
                  {p.teacher ? <span className="inline-flex items-center gap-1.5 rounded-full bg-white/10 px-3 py-1.5"><ChalkboardTeacher size={16} /> {p.teacher}</span> : null}
                  <span className="inline-flex items-center gap-1.5 rounded-full bg-white/10 px-3 py-1.5"><VideoCamera size={16} /> {p.sessions_left + p.sessions_done ? `${p.sessions_left + p.sessions_done} live sessions` : "Live sessions"}</span>
                </div>
                {next ? (
                  <div className="mt-6 rounded-2xl border border-white/10 bg-white/5 p-4">
                    <p className="text-sm font-bold text-[#C9D5EA]">Next session: {next.title} · {lagosWhen(next.starts_at)}</p>
                    <div className="mt-3"><Countdown to={next.starts_at} endsAt={new Date(new Date(next.starts_at).getTime() + next.minutes * 60000).toISOString()} dark /></div>
                  </div>
                ) : null}
                <div id="join" className="mt-6 scroll-mt-24 text-[#0B1F44] lg:max-w-md dark:text-white">
                  <BuyBox programId={p.id} price={p.price_kobo ?? 0} compare={p.compare_kobo} buyable={p.buyable} seatsLeft={p.seats_left} />
                </div>
              </Reveal>
            </div>
          </div>
        </section>

        <section className="py-14">
          <div className="mx-auto grid max-w-6xl gap-10 px-4 sm:px-6 lg:grid-cols-[minmax(0,7fr)_minmax(0,5fr)]">
            <div className="space-y-10">
              {p.highlights.length ? (
                <Reveal>
                  <h2 className="text-2xl font-bold tracking-tight">What you get</h2>
                  <ul className="mt-4 grid gap-3 sm:grid-cols-2">
                    {p.highlights.map((h) => (
                      <li key={h} className="flex items-start gap-3 rounded-2xl border bg-card p-4"><CheckCircle size={22} weight="fill" className="mt-0.5 shrink-0 text-[#14874F]" /><span>{h}</span></li>
                    ))}
                  </ul>
                </Reveal>
              ) : null}
              {p.about ? (
                <Reveal>
                  <h2 className="text-2xl font-bold tracking-tight">About this class</h2>
                  <div className="mt-3 whitespace-pre-line leading-8 text-foreground/90">{p.about}</div>
                </Reveal>
              ) : null}
              <Reveal>
                <h2 className="text-2xl font-bold tracking-tight">Timetable</h2>
                <p className="mt-1 text-sm text-muted-foreground">Lagos time. Join from 15 minutes before each session. Every session is recorded for students of the class.</p>
                {p.sessions.length ? (
                  <ol className="mt-4 space-y-2">
                    {p.sessions.slice(0, 20).map((s, i) => (
                      <li key={s.id} className="flex items-center gap-4 rounded-2xl border bg-card p-4">
                        <span className="grid size-10 shrink-0 place-items-center rounded-xl bg-[#0B1F44] text-sm font-bold text-[#F2B233]">{i + 1}</span>
                        <div className="min-w-0 flex-1">
                          <p className="font-bold">{s.title}</p>
                          <p className="text-sm text-muted-foreground">{lagosWhen(s.starts_at)} · {s.minutes} min</p>
                        </div>
                      </li>
                    ))}
                  </ol>
                ) : (
                  <p className="mt-4 rounded-2xl border bg-card p-4 text-sm text-muted-foreground">{p.schedule_note ? `Sessions hold ${p.schedule_note}. ` : ""}The dates of the next sessions will show here. Students of the class are reminded before each one.</p>
                )}
              </Reveal>
            </div>
            <div className="space-y-6">
              {p.teacher ? (
                <Reveal>
                  <div className="rounded-3xl border bg-card p-5">
                    <p className="text-sm font-bold text-muted-foreground">Your teacher</p>
                    <div className="mt-3 flex items-center gap-4">
                      {photo ? (
                        // eslint-disable-next-line @next/next/no-img-element
                        <img src={photo} alt={p.teacher} className="size-16 rounded-full object-cover" />
                      ) : (
                        <span className="grid size-16 place-items-center rounded-full bg-[#0B1F44] text-2xl font-bold text-[#F2B233]">{p.teacher.slice(0, 1)}</span>
                      )}
                      <p className="text-lg font-bold">{p.teacher}</p>
                    </div>
                    {p.teacher_bio ? <p className="mt-3 text-sm leading-7">{p.teacher_bio}</p> : null}
                  </div>
                </Reveal>
              ) : null}
              <Reveal delay={0.06}>
                <div className="rounded-3xl bg-[#F4F6FA] p-5 dark:bg-[#0A1730]">
                  <p className="font-bold">How joining works</p>
                  <ol className="mt-3 space-y-3 text-sm">
                    <li className="flex gap-3"><span className="grid size-6 shrink-0 place-items-center rounded-full bg-[#0B1F44] text-xs font-bold text-white">1</span> Pay once on this page. Your receipt comes by email.</li>
                    <li className="flex gap-3"><span className="grid size-6 shrink-0 place-items-center rounded-full bg-[#0B1F44] text-xs font-bold text-white">2</span> Open the SolutionTee app or My classes with the same email.</li>
                    <li className="flex gap-3"><span className="grid size-6 shrink-0 place-items-center rounded-full bg-[#0B1F44] text-xs font-bold text-white">3</span> Tap Join when the session opens. We remind you before each one.</li>
                    <li className="flex gap-3"><span className="grid size-6 shrink-0 place-items-center rounded-full bg-[#0B1F44] text-xs font-bold text-white"><PlayCircle size={14} weight="fill" /></span> Missed a session? Watch the recording.</li>
                  </ol>
                </div>
              </Reveal>
            </div>
          </div>
        </section>

        {p.faq.length ? <Faq title="Questions" items={p.faq} /> : null}

        {/* Phones: the price and Join stay at the bottom while reading. */}
        <div className="fixed inset-x-0 bottom-0 z-40 border-t bg-background/95 p-3 backdrop-blur lg:hidden">
          <div className="mx-auto flex max-w-xl items-center gap-3">
            <div className="min-w-0 flex-1">
              <p className="truncate text-sm font-bold">{p.title}</p>
              <p className="text-lg font-bold">{ngn(p.price_kobo ?? 0)}{p.compare_kobo && p.compare_kobo > (p.price_kobo ?? 0) ? <s className="ml-2 text-sm font-semibold text-muted-foreground">{ngn(p.compare_kobo)}</s> : null}</p>
            </div>
            <a href="#join" className="inline-flex h-12 items-center rounded-2xl bg-[#F2B233] px-6 font-bold text-[#0B1F44]">Join</a>
          </div>
        </div>
      </main>
      <SiteFooter />
    </>
  );
}
