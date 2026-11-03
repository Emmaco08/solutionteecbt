import { Suspense } from "react";
import type { Metadata } from "next";
import { requireStaff } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";
import { ErrorState, PageHeader, PageSkeleton, Panel } from "@/components/admin/ui";
import { DayList, type QotdDay } from "./qotd-ui";

export const metadata: Metadata = { title: "Question of the day" };

export default function Page() {
  return <Suspense fallback={<PageSkeleton rows={10} />}><Qotd /></Suspense>;
}

/** Today in Lagos as YYYY-MM-DD, plus n days. */
function lagosDay(n = 0) {
  const d = new Date(Date.now() + 3600_000 + n * 86400_000); // Lagos is UTC+1 all year
  return d.toISOString().slice(0, 10);
}

async function Qotd() {
  await requireStaff(["super_admin", "admin", "editor"]);
  const supabase = await createClient();
  const [days, subjects] = await Promise.all([
    supabase.rpc("admin_qotd_days", { p_from: lagosDay(-14), p_to: lagosDay(13) }),
    supabase.from("subjects").select("id, name").order("name"),
  ]);
  if (days.error) return <ErrorState message={days.error.message} />;
  const rows = (days.data ?? []) as unknown as QotdDay[];
  const today = lagosDay();
  const byDay = new Map(rows.map((r) => [r.day, r]));
  const coming = Array.from({ length: 14 }, (_, i) => lagosDay(i)).map((d) => ({ day: d, row: byDay.get(d) ?? null }));
  const past = rows.filter((r) => r.day < today).reverse();
  return (
    <>
      <PageHeader title="Question of the day" description="One question a day for every student, with one try. It changes at midnight Lagos time. Days you leave empty get a question picked automatically from the years Free students can open, rotating subjects." />
      <div className="grid gap-4 xl:grid-cols-[1.3fr_1fr]">
        <Panel title="Next 14 days" bodyClassName="p-0"><DayList days={coming} today={today} subjects={subjects.data ?? []} /></Panel>
        <Panel title="Last 14 days" bodyClassName="p-0">
          {past.length ? (
            <ul className="divide-y">
              {past.map((r) => (
                <li key={r.day} className="px-5 py-3 text-sm">
                  <div className="flex items-center justify-between gap-2"><b>{new Date(r.day + "T12:00:00Z").toLocaleDateString("en-GB", { weekday: "short", day: "numeric", month: "short" })}</b>
                    <span className="tabular-nums text-muted-foreground">{r.answers} answered · {r.answers ? Math.round((100 * r.right) / r.answers) : 0}% right</span></div>
                  <p className="line-clamp-2 text-muted-foreground">{r.body}</p>
                  <span className="text-xs text-muted-foreground">{r.exam} {r.year} · {r.subject} · answer {r.answer}{r.source === "auto" ? " · automatic" : ""}</span>
                </li>
              ))}
            </ul>
          ) : <p className="px-5 py-6 text-sm text-muted-foreground">No past questions of the day yet.</p>}
        </Panel>
      </div>
    </>
  );
}
