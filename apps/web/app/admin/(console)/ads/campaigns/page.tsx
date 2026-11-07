import { Suspense } from "react";
import type { Metadata } from "next";
import { requireStaff } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";
import { ErrorState, PageHeader, PageSkeleton } from "@/components/admin/ui";
import { CampaignsBoard } from "./campaigns-ui";
import type { Campaign } from "./shared";

export const metadata: Metadata = { title: "Brand ads" };

export default function Page() {
  return <Suspense fallback={<PageSkeleton rows={6} />}><Campaigns /></Suspense>;
}

async function Campaigns() {
  await requireStaff(["super_admin", "admin"]);
  const supabase = await createClient();
  const { data, error } = await supabase.rpc("admin_ad_campaigns");
  if (error) return <ErrorState message={error.message} />;
  return (
    <>
      <PageHeader
        title="Brand ads"
        description="Our own ads for brands that pay us: banner, card, full-screen break and video ads before, in the middle of or after our video lessons. They take a share of the ad slots the ads level already has (never more ads), never show to Premium students, students under 13, or during exams, CBT, challenges and checkout."
      />
      <CampaignsBoard list={(data ?? []) as unknown as Campaign[]} />
    </>
  );
}
