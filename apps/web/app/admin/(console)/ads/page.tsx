import { Suspense } from "react";
import type { Metadata } from "next";
import { requireStaff } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";
import { ErrorState, PageHeader, PageSkeleton } from "@/components/admin/ui";
import { AdsBoard, type AdsReport } from "./ads-ui";

export const metadata: Metadata = { title: "Ads" };

export default function Page() {
  return <Suspense fallback={<PageSkeleton rows={6} />}><Ads /></Suspense>;
}

async function Ads() {
  await requireStaff(["super_admin", "admin"]);
  const supabase = await createClient();
  const { data, error } = await supabase.rpc("admin_ads_report", { p_days: 30 });
  if (error) return <ErrorState message={error.message} />;
  return (
    <>
      <PageHeader
        title="Ads"
        description="Google AdMob. Premium students never see ads. Ads never show during a running exam, on the CBT question screen or at checkout. Rewarded unlocks are checked by the server before anything opens."
      />
      <AdsBoard r={data as unknown as AdsReport} />
    </>
  );
}
