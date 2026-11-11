import { Suspense } from "react";
import type { Metadata } from "next";
import { requireStaff } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";
import { ErrorState, PageHeader, PageSkeleton } from "@/components/admin/ui";
import { BadgeList, type Badge } from "./badges-ui";

export const metadata: Metadata = { title: "Badges" };

export default function Page() {
  return <Suspense fallback={<PageSkeleton rows={10} />}><Badges /></Suspense>;
}

async function Badges() {
  await requireStaff(["super_admin", "admin"]);
  const supabase = await createClient();
  const [list, counts, cfg] = await Promise.all([
    supabase.from("badges").select("id, key, name, description, icon, metric, targets, rewards, active, sort").order("sort").order("id"),
    supabase.rpc("admin_badge_counts"),
    supabase.from("app_settings").select("value").eq("key", "badges").maybeSingle(),
  ]);
  if (list.error) return <ErrorState message={list.error.message} />;
  const holders: Record<string, number> = {};
  for (const c of counts.data ?? []) holders[`${c.badge_id}:${c.tier}`] = Number(c.holders);
  const on = (cfg.data?.value as { on?: boolean } | null)?.on !== false;
  return (
    <>
      <PageHeader title="Badges" description="Students win bronze, silver, gold and diamond levels by practising. Each level can give XP and free Premium days, once. The server counts everything, so the app cannot fake a badge. Levels students had already reached when badges started were recorded without a reward." />
      <BadgeList badges={(list.data ?? []) as unknown as Badge[]} holders={holders} on={on} />
    </>
  );
}
