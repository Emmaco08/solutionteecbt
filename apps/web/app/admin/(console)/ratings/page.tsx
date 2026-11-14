import { Suspense } from "react";
import type { Metadata } from "next";
import { requireStaff } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";
import { ErrorState, PageHeader, PageSkeleton, Panel } from "@/components/admin/ui";
import type { EngagementSettings, RatingsData } from "./actions";
import { EngagementForm, RatingsList } from "./ratings-ui";

export const metadata: Metadata = { title: "App ratings" };

export default function Page() {
  return <Suspense fallback={<PageSkeleton rows={8} />}><Ratings /></Suspense>;
}

const DEFAULTS: EngagementSettings = {
  rating: { on: true, after_days: 3, after_opens: 6, every_days: 60 },
  review: { on: true, after_days: 5, every_days: 120 },
  nudges: { on: true, after_days: 2, every_days: 3, community: true, games: true, tutor: true },
};

async function Ratings() {
  await requireStaff(["super_admin", "admin"]);
  const supabase = await createClient();
  const [r, s] = await Promise.all([
    supabase.rpc("admin_app_ratings", { p_offset: 0 }),
    supabase.from("app_settings").select("value").eq("key", "engagement").maybeSingle(),
  ]);
  if (r.error) return <ErrorState message={r.error.message} />;
  const d = r.data as unknown as RatingsData;
  const v = (s.data?.value ?? {}) as Partial<EngagementSettings>;
  const settings: EngagementSettings = {
    rating: { ...DEFAULTS.rating, ...v.rating },
    review: { ...DEFAULTS.review, ...v.review },
    nudges: { ...DEFAULTS.nudges, ...v.nudges },
  };
  const tile = (label: string, value: string) => (
    <div className="rounded-2xl border bg-card p-4"><p className="text-xs text-muted-foreground">{label}</p><p className="text-2xl font-bold tabular-nums">{value}</p></div>
  );
  const avg = (x: number | null) => (x == null ? "–" : `${Number(x).toFixed(1)} ★`);
  return (
    <>
      <PageHeader
        title="App ratings"
        description="Students rate SolutionTee inside the app now and then (stars and a comment). Google's own Play Store review box is asked for separately, at a happy moment such as a good score or a game win: Google's rules forbid asking our question first or showing their box only to happy students."
      />
      <div className="mb-4 grid grid-cols-2 gap-3 md:grid-cols-4">
        {tile("Average rating", avg(d.average))}{tile("Ratings", (d.total ?? 0).toLocaleString("en-NG"))}
        {tile("Average, last 30 days", avg(d.average_30))}{tile("Ratings, last 30 days", (d.count_30 ?? 0).toLocaleString("en-NG"))}
      </div>
      <RatingsList initial={d} />
      <Panel title="When the app asks" className="mt-4">
        <EngagementForm initial={settings} />
      </Panel>
    </>
  );
}
