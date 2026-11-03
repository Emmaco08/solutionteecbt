import { Suspense } from "react";
import type { Metadata } from "next";
import { requireStaff } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";
import { ErrorState, PageHeader, PageSkeleton, Panel } from "@/components/admin/ui";
import { AddPanel, Analysis, DayGrid, NotifyForm, type QotdDay, type Stats } from "./qotd-ui";

export const metadata: Metadata = { title: "Question of the day" };

export default function Page() {
  return <Suspense fallback={<PageSkeleton rows={10} />}><Qotd /></Suspense>;
}

/** Today in Lagos as YYYY-MM-DD, plus n days. */
function lagosDay(n = 0) {
  return new Date(Date.now() + 3600_000 + n * 86400_000).toISOString().slice(0, 10); // Lagos is UTC+1 all year
}

async function Qotd() {
  const staff = await requireStaff(["super_admin", "admin", "editor"]);
  const supabase = await createClient();
  const [days, subjects, stats, setting] = await Promise.all([
    supabase.rpc("admin_qotd_days", { p_from: lagosDay(-14), p_to: lagosDay(13) }),
    supabase.from("exam_subjects").select("subject_id, subjects(id, name, sort), exam_bodies!inner(code)").eq("exam_bodies.code", "JAMB"),
    supabase.rpc("admin_qotd_stats", { p_days: 14 }),
    supabase.from("app_settings").select("value").eq("key", "qotd").maybeSingle(),
  ]);
  if (days.error) return <ErrorState message={days.error.message} />;
  const rows = (days.data ?? []) as unknown as QotdDay[];
  const today = lagosDay();
  const subs = ((subjects.data ?? []) as unknown as { subjects: { id: number; name: string; sort: number } }[])
    .map((x) => x.subjects).filter(Boolean).sort((a, b) => a.sort - b.sort || a.name.localeCompare(b.name));
  const coming = Array.from({ length: 7 }, (_, i) => lagosDay(i));
  const past = Array.from({ length: 14 }, (_, i) => lagosDay(-i - 1));
  const notify = (setting.data?.value ?? {}) as { notify?: boolean; notify_hour?: number };
  const canSettings = staff.role === "super_admin" || staff.role === "admin";
  return (
    <>
      <PageHeader title="Question of the day" description="Every day, each student gets one question from one of their own 4 JAMB subjects, picked at random for them. Set a question for each subject below, or leave it: empty subjects get a past question picked automatically from the years Free students can open." />
      <Panel title="Analysis (last 14 days)" className="mb-4">{stats.error ? <ErrorState message={stats.error.message} /> : <Analysis stats={stats.data as unknown as Stats} />}</Panel>
      <div className="grid gap-4 xl:grid-cols-[1fr_1fr]">
        <Panel title="Add or change a question"><AddPanel today={today} subjects={subs} /></Panel>
        <div className="space-y-4">
          <Panel title="Next 7 days" bodyClassName="p-0"><DayGrid days={coming} rows={rows} subjects={subs} today={today} editable /></Panel>
          {canSettings ? <Panel title="Daily notification"><NotifyForm notify={notify.notify ?? true} hour={notify.notify_hour ?? 7} /></Panel> : null}
        </div>
      </div>
      <Panel title="Past days: how students answered" className="mt-4" bodyClassName="p-0"><DayGrid days={past} rows={rows} subjects={subs} today={today} /></Panel>
    </>
  );
}
