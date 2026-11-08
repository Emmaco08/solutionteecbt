import Link from "next/link";
import { Panel } from "@/components/admin/ui";
import { BarList, Columns, Split, Stat, Trend } from "@/components/admin/charts";
import { fmt } from "@/lib/format-num";
import { cn } from "@/lib/utils";

/* Shape of public.admin_analytics (D-124). Money is in kobo except prize cash (naira). */
type Item = { label: string; n: number };
export type Analytics = {
  days: number; from: string; to: string;
  overview: {
    students: number; new: number; new_prev: number; dau: number; wau: number; mau: number; active: number; active_prev: number; premium: number;
    revenue: number; revenue_prev: number; tests: number; tests_prev: number; ai: number; ai_prev: number; entries: number;
    series: { day: string; new: number; active: number; tests: number; ai: number; revenue: number }[];
  };
  users: {
    ages: Item[]; exams: Item[]; no_exam: number; courses: Item[]; subjects: Item[]; combos: Item[]; states: Item[]; scores: Item[]; versions: Item[];
    retention: { d1: number | null; d7: number | null; d30: number | null; cohort_d1: number };
  };
  usage: {
    modes: (Item & { avg: number | null })[]; finished: number; abandoned: number; avg_jamb: number | null;
    subjects: (Item & { acc: number | null })[]; hours: number[]; weekdays: number[];
    qotd: { answers: number; correct_pct: number | null; players: number }; study: { opened: number; learners: number; finished: number };
    ai: { questions: number; users: number; flagged: number }; xp_streak: { xp_earned: number };
  };
  challenges: {
    held: number; live: number; upcoming: number; entries: number; players: number; finished: number; dq: number; cash_paid: number;
    claims_waiting: number; premium_given: number;
    list: { title: string; starts: string; mode: string; closed: boolean; players: number; finished: number; dq: number; avg_score: number | null; top_score: number | null }[];
  };
  payments: {
    revenue: number; statuses: Record<string, number>; providers: (Item & { kobo: number })[]; plans: (Item & { kobo: number })[]; channels: Item[];
    payers: number; payers_ever: number; repeat: number; discounts: { uses: number; kobo: number; free_days: number }; refunded: number;
  };
  ads: { impressions: number; clicks: number; formats: Item[] };
};

export const TABS = [["overview", "Overview"], ["students", "Students"], ["learning", "Learning"], ["challenges", "Challenges"], ["payments", "Payments"]] as const;
export type Tab = (typeof TABS)[number][0];

const MODES: Record<string, string> = { full: "Full JAMB mock", quick: "Quick test", subject: "Subject test", topic: "Topic drill", custom: "Custom exam" };
const PROVIDERS: Record<string, string> = { paystack: "Paystack (website and APK)", play: "Google Play", code: "Free-days codes" };
const STATUS: [string, string][] = [["success", "Paid"], ["pending", "Started, not finished"], ["abandoned", "Cancelled or left"], ["failed", "Failed"], ["needs_review", "Needs review"], ["refunded", "Refunded"]];
const WEEK = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
const naira = (kobo: number) => kobo / 100;

/** Same label twice (subjects picked in another order) → one row. */
function merge(items: Item[]) {
  const m = new Map<string, number>();
  for (const i of items) m.set(i.label, (m.get(i.label) ?? 0) + i.n);
  return [...m].map(([label, n]) => ({ label, n })).sort((a, b) => b.n - a.n);
}

export function PeriodTabs({ days, tab, tabs }: { days: number; tab: Tab; tabs: readonly (readonly [Tab, string])[] }) {
  return (
    <div className="flex flex-wrap items-center justify-between gap-3">
      <nav className="flex flex-wrap gap-1 rounded-xl border bg-card p-1" aria-label="Dashboard sections">
        {tabs.map(([k, label]) => (
          <Link key={k} href={`/admin?tab=${k}&days=${days}`} aria-current={tab === k ? "page" : undefined}
            className={cn("rounded-lg px-3.5 py-2 text-sm font-bold", tab === k ? "bg-primary text-primary-foreground" : "text-muted-foreground hover:text-foreground")}>{label}</Link>
        ))}
      </nav>
      <div className="flex gap-1 rounded-xl border bg-card p-1" aria-label="Period">
        {[7, 30, 90].map((d) => (
          <Link key={d} href={`/admin?tab=${tab}&days=${d}`} aria-current={days === d ? "true" : undefined}
            className={cn("rounded-lg px-3 py-2 text-sm font-bold", days === d ? "bg-muted text-foreground" : "text-muted-foreground hover:text-foreground")}>{d} days</Link>
        ))}
      </div>
    </div>
  );
}

const grid4 = "grid grid-cols-2 gap-3 sm:gap-4 xl:grid-cols-4 [&>*]:min-w-0";

export function Overview({ a, money }: { a: Analytics; money: boolean }) {
  const o = a.overview;
  const s = (k: "new" | "active" | "tests" | "ai" | "revenue") => o.series.map((d) => ({ day: d.day, v: k === "revenue" ? naira(d[k]) : d[k] }));
  return (
    <div className="min-w-0 space-y-4">
      <div className={grid4}>
        <Stat label="Students" value={o.students} sub={`+${fmt(o.new)} new in ${a.days} days`} />
        <Stat label="Active students" value={o.active} prev={o.active_prev} help="Did at least one thing: a test, an AI question, the question of the day, a challenge, a study item or opened the app." />
        {money ? <Stat label="Revenue" value={naira(o.revenue)} prev={naira(o.revenue_prev)} f="naira" help="Paid with Paystack or Google Play (codes not counted)." />
          : <Stat label="Tests taken" value={o.tests} prev={o.tests_prev} />}
        <Stat label="Premium now" value={o.premium} sub={o.students ? `${Math.round((o.premium / o.students) * 100)}% of students` : undefined} />
      </div>
      <div className={grid4}>
        <Stat label="Active today" value={o.dau} sub={`${fmt(o.wau)} this week · ${fmt(o.mau)} in 30 days`} />
        {money ? <Stat label="Tests taken" value={o.tests} prev={o.tests_prev} /> : <Stat label="Challenge entries" value={o.entries} />}
        <Stat label="AI tutor questions" value={o.ai} prev={o.ai_prev} />
        <Stat label="New students" value={o.new} prev={o.new_prev} />
      </div>
      <div className="grid gap-4 xl:grid-cols-2 [&>*]:min-w-0">
        <Panel title="Active students per day"><Trend data={s("active")} label="Active students" /></Panel>
        <Panel title="New students per day"><Trend data={s("new")} label="New students" /></Panel>
        <Panel title="Tests taken per day"><Trend data={s("tests")} label="Tests" /></Panel>
        {money ? <Panel title="Revenue per day"><Trend data={s("revenue")} label="Revenue" f="naira" /></Panel>
          : <Panel title="AI tutor questions per day"><Trend data={s("ai")} label="AI questions" /></Panel>}
      </div>
    </div>
  );
}

export function Students({ a }: { a: Analytics }) {
  const u = a.users;
  const ret = (v: number | null) => (v === null ? 0 : v);
  return (
    <div className="min-w-0 space-y-4">
      <div className={grid4}>
        <Stat label="Come back the next day" value={ret(u.retention.d1)} f="pct" sub={u.retention.d1 === null ? "Not enough sign-ups yet" : `of ${fmt(u.retention.cohort_d1)} who joined in the last month`} />
        <Stat label="Come back in week 2" value={ret(u.retention.d7)} f="pct" sub={u.retention.d7 === null ? "Needs students who joined 2 to 6 weeks ago" : "active 7 to 13 days after joining"} />
        <Stat label="Still here after a month" value={ret(u.retention.d30)} f="pct" sub={u.retention.d30 === null ? "Needs students who joined over 5 weeks ago" : "active 30 to 36 days after joining"} />
        <Stat label="No exam chosen yet" value={u.no_exam} sub="did not finish setup" />
      </div>
      <div className="grid gap-4 xl:grid-cols-3 [&>*]:min-w-0">
        <Panel title="Age"><BarList items={u.ages} /></Panel>
        <Panel title="Exams they are preparing for"><BarList items={u.exams} empty="No exams chosen yet." /></Panel>
        <Panel title="Target JAMB score"><BarList items={u.scores} /></Panel>
        <Panel title="Course area (from JAMB subjects)"><BarList items={u.courses} />
          <p className="mt-3 text-xs text-muted-foreground">The app does not ask for a course; this is worked out from each student&apos;s JAMB subject combination.</p></Panel>
        <Panel title="Most chosen subject combinations"><BarList items={merge(u.combos)} empty="No subject combinations yet." />
          <p className="mt-3 text-xs text-muted-foreground">Use of English is left out (everyone takes it).</p></Panel>
        <Panel title="JAMB subjects chosen"><BarList items={u.subjects} total={a.overview.students} /></Panel>
        <Panel title="States (top 15)"><BarList items={u.states} /></Panel>
        <Panel title="App versions in use (30 days)"><BarList items={u.versions} empty="No phones seen yet." /></Panel>
      </div>
    </div>
  );
}

export function Learning({ a }: { a: Analytics }) {
  const g = a.usage;
  const done = g.finished + g.abandoned;
  return (
    <div className="min-w-0 space-y-4">
      <div className={grid4}>
        <Stat label="Tests finished" value={g.finished} sub={done ? `${Math.round((g.finished / done) * 100)}% of tests started` : undefined} />
        <Stat label="Average full mock score" value={g.avg_jamb ?? 0} sub={g.avg_jamb === null ? "No full mocks yet" : "out of 400"} />
        <Stat label="Question of the day answers" value={g.qotd.answers} sub={`${fmt(g.qotd.players)} students · ${fmt(g.qotd.correct_pct, "pct")} right`} />
        <Stat label="AI tutor questions" value={g.ai.questions} sub={`${fmt(g.ai.users)} students · ${fmt(g.ai.flagged)} flagged`} />
      </div>
      <div className={grid4}>
        <Stat label="Study items opened" value={g.study.opened} sub={`${fmt(g.study.learners)} students · ${fmt(g.study.finished)} finished`} />
        <Stat label="XP earned (all time)" value={g.xp_streak.xp_earned} />
      </div>
      <div className="grid gap-4 xl:grid-cols-2 [&>*]:min-w-0">
        <Panel title="Kinds of test"><BarList items={g.modes.map((m) => ({ label: MODES[m.label] ?? m.label, n: m.n, note: m.avg === null ? undefined : `Average ${m.avg}% right` }))} empty="No tests in this period." /></Panel>
        <Panel title="Subjects practised (questions answered)"><BarList items={g.subjects.filter((x) => x.n > 0).map((x) => ({ label: x.label, n: x.n, note: x.acc === null ? undefined : `${x.acc}% right` }))} empty="No answers in this period." /></Panel>
        <Panel title="When students take tests (Lagos time)"><Columns label="Tests by hour" data={g.hours.map((v, h) => ({ label: `${h}`, v, tip: `${h}:00 to ${h}:59` }))} /></Panel>
        <Panel title="Active students by day of the week"><Columns label="Active by weekday" data={g.weekdays.map((v, k) => ({ label: WEEK[k]!, v, tip: `student-days on ${WEEK[k]}` }))} /></Panel>
      </div>
    </div>
  );
}

export function Challenges({ a }: { a: Analytics }) {
  const c = a.challenges;
  return (
    <div className="min-w-0 space-y-4">
      <div className={grid4}>
        <Stat label="Challenges held" value={c.held} sub={`${fmt(c.live)} live now · ${fmt(c.upcoming)} coming`} />
        <Stat label="Entries" value={c.entries} sub={`${fmt(c.players)} different students`} />
        <Stat label="Finished fairly" value={c.entries ? Math.round((c.finished / c.entries) * 100) : 0} f="pct" sub={`${fmt(c.dq)} disqualified`} />
        <Stat label="Cash prizes paid" value={c.cash_paid} f="naira" sub={`${fmt(c.claims_waiting)} claims waiting · ${fmt(c.premium_given)} Premium rewards`} />
      </div>
      <Panel title="Recent challenges" bodyClassName="p-0">
        {c.list.length ? (
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead><tr className="border-b text-left text-xs text-muted-foreground">
                <th className="px-5 py-2.5 font-bold">Challenge</th><th className="px-3 py-2.5 font-bold">Date</th><th className="px-3 py-2.5 text-right font-bold">Players</th>
                <th className="px-3 py-2.5 text-right font-bold">Finished</th><th className="px-3 py-2.5 text-right font-bold">Disqualified</th>
                <th className="px-3 py-2.5 text-right font-bold">Average</th><th className="px-5 py-2.5 text-right font-bold">Best</th>
              </tr></thead>
              <tbody className="divide-y">
                {c.list.map((r) => (
                  <tr key={r.title + r.starts}>
                    <td className="px-5 py-2.5 font-bold">{r.title}</td>
                    <td className="whitespace-nowrap px-3 py-2.5 text-muted-foreground">{new Date(r.starts).toLocaleDateString("en-GB", { day: "numeric", month: "short" })}</td>
                    <td className="tnum px-3 py-2.5 text-right">{fmt(r.players)}</td>
                    <td className="tnum px-3 py-2.5 text-right">{fmt(r.finished)}</td>
                    <td className="tnum px-3 py-2.5 text-right">{fmt(r.dq)}</td>
                    <td className="tnum px-3 py-2.5 text-right">{fmt(r.avg_score)}</td>
                    <td className="tnum px-5 py-2.5 text-right">{fmt(r.top_score)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        ) : <p className="py-8 text-center text-sm text-muted-foreground">No challenges yet.</p>}
      </Panel>
    </div>
  );
}

export function Payments({ a }: { a: Analytics }) {
  const p = a.payments, o = a.overview, ad = a.ads;
  const series = o.series.map((d) => ({ day: d.day, v: naira(d.revenue) }));
  const attempts = Object.values(p.statuses).reduce((s, n) => s + n, 0);
  return (
    <div className="min-w-0 space-y-4">
      <div className={grid4}>
        <Stat label="Revenue" value={naira(p.revenue)} prev={naira(o.revenue_prev)} f="naira" sub={p.refunded ? `${fmt(naira(p.refunded), "naira")} refunded` : undefined} />
        <Stat label="Paying students" value={p.payers} sub={`${fmt(p.payers_ever)} have ever paid · ${fmt(p.repeat)} paid again`} />
        <Stat label="Average per paying student" value={p.payers ? naira(p.revenue) / p.payers : 0} f="naira" />
        <Stat label="Paid out of started" value={attempts ? Math.round(((p.statuses.success ?? 0) / attempts) * 100) : 0} f="pct" sub={`${fmt(attempts)} payments started`} />
      </div>
      <div className="grid gap-4 xl:grid-cols-3 [&>*]:min-w-0">
        <Panel title="Revenue per day" className="xl:col-span-2"><Trend data={series} label="Revenue" f="naira" /></Panel>
        <Panel title="How payments ended">
          <BarList items={STATUS.map(([k, label]) => ({ label, n: p.statuses[k] ?? 0 })).filter((x) => x.n > 0)} empty="No payments in this period." />
        </Panel>
        <Panel title="Revenue by plan"><BarList items={p.plans.map((x) => ({ label: x.label, n: naira(x.kobo), note: `${fmt(x.n)} payment${x.n === 1 ? "" : "s"}` }))} f="naira" empty="No paid plans in this period." /></Panel>
        <Panel title="Where students paid"><Split items={p.providers.map((x) => ({ label: PROVIDERS[x.label] ?? x.label, n: x.n }))} />
          <p className="mt-3 text-xs text-muted-foreground">Number of successful payments, including free-days codes.</p></Panel>
        <Panel title="Paystack payment methods"><BarList items={p.channels.map((x) => ({ label: x.label.replace(/_/g, " "), n: x.n }))} empty="No Paystack payments in this period." /></Panel>
        <Panel title="Discount and free-days codes">
          <dl className="grid grid-cols-3 gap-3 text-center">
            <div><dt className="text-xs text-muted-foreground">Codes used</dt><dd className="tnum mt-1 text-xl font-bold">{fmt(p.discounts.uses)}</dd></div>
            <div><dt className="text-xs text-muted-foreground">Discount given</dt><dd className="tnum mt-1 text-xl font-bold">{fmt(naira(p.discounts.kobo), "naira")}</dd></div>
            <div><dt className="text-xs text-muted-foreground">Free days</dt><dd className="tnum mt-1 text-xl font-bold">{fmt(p.discounts.free_days)}</dd></div>
          </dl>
        </Panel>
        <Panel title="Ads (free students)" className="xl:col-span-2">
          <div className="grid gap-4 sm:grid-cols-[1fr_1.4fr]">
            <dl className="grid grid-cols-3 gap-3 text-center sm:grid-cols-1 sm:text-left">
              <div><dt className="text-xs text-muted-foreground">Ads shown</dt><dd className="tnum text-xl font-bold">{fmt(ad.impressions)}</dd></div>
              <div><dt className="text-xs text-muted-foreground">Clicks</dt><dd className="tnum text-xl font-bold">{fmt(ad.clicks)}</dd></div>
              <div><dt className="text-xs text-muted-foreground">Click rate</dt><dd className="tnum text-xl font-bold">{ad.impressions ? `${((ad.clicks / ad.impressions) * 100).toFixed(1)}%` : "–"}</dd></div>
            </dl>
            <BarList items={ad.formats.map((x) => ({ label: x.label.replace(/_/g, " "), n: x.n }))} empty="No ads shown in this period." />
          </div>
          <p className="mt-3 text-xs text-muted-foreground">Earnings are in your AdMob account. Full ads report: Money → Ads.</p>
        </Panel>
      </div>
    </div>
  );
}
