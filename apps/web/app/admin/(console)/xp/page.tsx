import { Suspense } from "react";
import type { Metadata } from "next";
import { requireStaff } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";
import { ErrorState, PageHeader, PageSkeleton } from "@/components/admin/ui";
import { XpBoard, type XpOverview } from "./xp-ui";

export const metadata: Metadata = { title: "XP & streaks" };

export default function Page() {
  return <Suspense fallback={<PageSkeleton rows={10} />}><Xp /></Suspense>;
}

async function Xp() {
  await requireStaff(["super_admin", "admin"]);
  const supabase = await createClient();
  const [o, plans] = await Promise.all([supabase.rpc("admin_xp_overview"), supabase.from("plans").select("code, name").order("price_kobo")]);
  if (o.error) return <ErrorState message={o.error.message} />;
  return (
    <>
      <PageHeader title="XP & streaks" description="XP is the app's game coin. Students earn it by practising and spend it on challenge entries, Premium and streak freezes. You set every number here, and can switch XP off." />
      <XpBoard d={o.data as unknown as XpOverview} plans={(plans.data ?? []) as { code: string; name: string }[]} />
    </>
  );
}
