import Link from "next/link";
import type { Metadata } from "next";
import { CalendarBlank, ChalkboardTeacher, Clock, Users } from "@phosphor-icons/react/dist/ssr";
import { SiteNav } from "../site/_components/nav";
import { Faq, SiteFooter } from "../site/_components/sections";
import { classesPageData, lagosWhen, ngn, type PublicClass } from "./data";

export const metadata: Metadata = {
  title: "JAMB classes",
  description: "Live online JAMB classes with real teachers: timetable, prices and how to join. Join from your phone or laptop.",
};

const price = (c: PublicClass) => (c.access === "paid" ? ngn(c.price_kobo ?? 0) : c.access === "premium" ? "Free with Premium" : "Free");

/** cbt.solutiontee.com/classes (D-148): about the classes, teachers, the timetable and how to register. */
export default async function Page() {
  const { page, classes } = await classesPageData();
  return (
    <>
      <SiteNav links={[["/", "Home"], ["#timetable", "Timetable"], ["/classes/me", "My classes"]]} />
      <main>
        <section className="bg-[#0B1F44] pb-16 pt-28 text-white sm:pt-32">
          <div className="mx-auto max-w-5xl px-4 sm:px-6">
            <p className="inline-flex items-center gap-2 rounded-full bg-white/10 px-3 py-1 text-sm font-bold text-[#F2B233]"><ChalkboardTeacher size={18} weight="fill" /> Live online classes</p>
            <h1 className="mt-4 max-w-3xl text-4xl font-bold leading-tight tracking-tight sm:text-5xl">{page.title}</h1>
            {page.intro ? <p className="mt-4 max-w-2xl text-lg leading-8 text-[#C9D5EA]">{page.intro}</p> : null}
            <div className="mt-7 flex flex-wrap gap-3">
              <a href="#timetable" className="inline-flex h-12 items-center rounded-2xl bg-[#F2B233] px-6 font-bold text-[#0B1F44]">See the timetable</a>
              <Link href="/classes/me" className="inline-flex h-12 items-center rounded-2xl border border-white/25 px-6 font-bold">My classes</Link>
            </div>
            {page.price_note ? <p className="mt-6 max-w-2xl text-sm text-[#AFC0DD]">{page.price_note}</p> : null}
          </div>
        </section>

        <section id="timetable" className="scroll-mt-20 py-16">
          <div className="mx-auto max-w-5xl px-4 sm:px-6">
            <h2 className="text-3xl font-bold tracking-tight">Timetable</h2>
            <p className="mt-2 text-muted-foreground">All times are Lagos time. Register, then join from My classes or the SolutionTee app 15 minutes before the start.</p>
            {classes.length === 0 ? (
              <p className="mt-8 rounded-2xl border bg-card p-6 text-muted-foreground">No classes are on the timetable yet. Check back soon.</p>
            ) : (
              <ul className="mt-8 grid gap-4 sm:grid-cols-2">
                {classes.map((c) => (
                  <li key={c.id} className="flex flex-col rounded-2xl border bg-card p-5 shadow-[var(--shadow-1)]">
                    <div className="flex items-start justify-between gap-3">
                      <h3 className="text-lg font-bold leading-snug">{c.title}</h3>
                      <span className={`shrink-0 rounded-full px-3 py-1 text-xs font-bold ${c.access === "paid" ? "bg-[#E8EEF8] text-[#0B1F44]" : "bg-success-soft text-on-success-soft"}`}>{price(c)}</span>
                    </div>
                    <p className="mt-1 text-sm text-muted-foreground">with {c.teacher}{c.subject ? ` · ${c.subject}` : ""}</p>
                    <div className="mt-3 space-y-1 text-sm">
                      <p className="flex items-center gap-2"><CalendarBlank size={16} /> {lagosWhen(c.starts_at)}</p>
                      <p className="flex items-center gap-2"><Clock size={16} /> {c.minutes} minutes</p>
                      {c.seats_left !== null ? <p className="flex items-center gap-2"><Users size={16} /> {c.seats_left > 0 ? `${c.seats_left} seats left` : "Full"}</p> : null}
                    </div>
                    {c.about ? <p className="mt-3 line-clamp-3 text-sm text-muted-foreground">{c.about}</p> : null}
                    <div className="mt-auto pt-4">
                      {c.seats_left === 0 ? <span className="text-sm font-bold text-muted-foreground">This class is full</span> : (
                        <Link href={`/classes/me?class=${c.id}`} className="inline-flex h-11 w-full items-center justify-center rounded-2xl bg-[#0B1F44] px-5 text-sm font-bold text-white dark:bg-[#F2B233] dark:text-[#0B1F44]">
                          {c.access === "paid" ? `Register and pay ${ngn(c.price_kobo ?? 0)}` : "Register"}
                        </Link>
                      )}
                    </div>
                  </li>
                ))}
              </ul>
            )}
          </div>
        </section>

        {page.teachers.length ? (
          <section className="bg-[#F4F6FA] py-16 dark:bg-[#0A1730]">
            <div className="mx-auto max-w-5xl px-4 sm:px-6">
              <h2 className="text-3xl font-bold tracking-tight">Your teachers</h2>
              <ul className="mt-8 grid gap-4 sm:grid-cols-3">
                {page.teachers.map((t) => (
                  <li key={t.name} className="rounded-2xl border bg-card p-5">
                    <span className="grid size-12 place-items-center rounded-full bg-[#0B1F44] text-lg font-bold text-[#F2B233]">{t.name.slice(0, 1)}</span>
                    <p className="mt-3 font-bold">{t.name}</p>
                    {t.subject ? <p className="text-sm text-muted-foreground">{t.subject}</p> : null}
                    {t.bio ? <p className="mt-2 text-sm">{t.bio}</p> : null}
                  </li>
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
