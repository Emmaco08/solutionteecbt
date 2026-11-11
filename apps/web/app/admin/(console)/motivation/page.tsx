import { Suspense } from "react";
import type { Metadata } from "next";
import { requireStaff } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";
import { ErrorState, PageHeader, PageSkeleton, Panel } from "@/components/admin/ui";
import { LineList, type Line } from "./motivation-ui";
import { CountdownEditor, type CountdownSettings } from "./countdown-ui";

export const metadata: Metadata = { title: "Daily motivation" };

export default function Page() {
  return <Suspense fallback={<PageSkeleton rows={10} />}><Motivation /></Suspense>;
}

async function Motivation() {
  const me = await requireStaff(["super_admin", "admin", "editor"]);
  const supabase = await createClient();
  const [list, today, cd, exams] = await Promise.all([
    supabase.from("motivation_quotes").select("id, body, author, kind, active, sort").order("sort").order("id"),
    supabase.rpc("today_motivation"),
    supabase.from("app_settings").select("value").eq("key", "exam_countdown").maybeSingle(),
    supabase.from("exam_bodies").select("code, name").eq("is_active", true).order("sort"),
  ]);
  const v = (cd.data?.value ?? {}) as Partial<CountdownSettings>;
  const countdown: CountdownSettings = { on: v.on !== false, daily: v.daily !== false, dates: v.dates ?? {} };
  if (list.error) return <ErrorState message={list.error.message} />;
  const t = (today.data ?? {}) as { id?: number; body?: string; author?: string | null };
  return (
    <>
      <PageHeader
        title="Daily motivation"
        description="The first card on the app's Home shows one line a day: a quote, a study tip or a fact. Every student sees the same line on the same day, going down this list in order. Pause a line to skip it."
      />
      <Panel title="Exam countdown" className="mb-4">
        <CountdownEditor initial={countdown} exams={(exams.data ?? []) as { code: string; name: string }[]} canEdit={me.role === "super_admin" || me.role === "admin"} />
      </Panel>
      <Panel title="Today in the app" className="mb-4">
        {t.body ? <p className="text-lg font-semibold">“{t.body}”{t.author ? <span className="ml-2 text-sm font-normal text-muted-foreground">— {t.author}</span> : null}</p> : <p className="text-sm text-muted-foreground">No lines are shown. Add one below.</p>}
      </Panel>
      <LineList lines={(list.data ?? []) as Line[]} todayId={t.id ?? null} />
    </>
  );
}
