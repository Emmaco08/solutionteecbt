import { Suspense } from "react";
import type { Metadata } from "next";
import { requireStaff } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";
import { ErrorState, PageHeader, PageSkeleton, Panel } from "@/components/admin/ui";
import { LineList, type Line } from "./motivation-ui";

export const metadata: Metadata = { title: "Daily motivation" };

export default function Page() {
  return <Suspense fallback={<PageSkeleton rows={10} />}><Motivation /></Suspense>;
}

async function Motivation() {
  await requireStaff(["super_admin", "admin", "editor"]);
  const supabase = await createClient();
  const [list, today] = await Promise.all([
    supabase.from("motivation_quotes").select("id, body, author, kind, active, sort").order("sort").order("id"),
    supabase.rpc("today_motivation"),
  ]);
  if (list.error) return <ErrorState message={list.error.message} />;
  const t = (today.data ?? {}) as { id?: number; body?: string; author?: string | null };
  return (
    <>
      <PageHeader
        title="Daily motivation"
        description="The first card on the app's Home shows one line a day: a quote, a study tip or a fact. Every student sees the same line on the same day, going down this list in order. Pause a line to skip it."
      />
      <Panel title="Today in the app" className="mb-4">
        {t.body ? <p className="text-lg font-semibold">“{t.body}”{t.author ? <span className="ml-2 text-sm font-normal text-muted-foreground">— {t.author}</span> : null}</p> : <p className="text-sm text-muted-foreground">No lines are shown. Add one below.</p>}
      </Panel>
      <LineList lines={(list.data ?? []) as Line[]} todayId={t.id ?? null} />
    </>
  );
}
