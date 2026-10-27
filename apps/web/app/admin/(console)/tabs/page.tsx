import { Suspense } from "react";
import type { Metadata } from "next";
import { requireStaff } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";
import { ErrorState, PageHeader, PageSkeleton } from "@/components/admin/ui";
import { TabRow } from "./tab-row";

export const metadata: Metadata = { title: "Tabs manager" };

export default function Page() {
  return <Suspense fallback={<PageSkeleton rows={5} />}><Tabs /></Suspense>;
}

async function Tabs() {
  await requireStaff(["super_admin", "admin"]);
  const supabase = await createClient();
  const { data, error } = await supabase.from("app_tabs").select("*").order("sort");
  if (error) return <ErrorState message={error.message} />;
  return (
    <>
      <PageHeader title="Tabs manager" description="The bottom bar of the app. Up to 5 tabs show; extra tabs go into a More sheet. The app keeps the last version for offline use." />
      <div className="overflow-hidden rounded-2xl border bg-card">
        <div className="hidden grid-cols-[56px_minmax(0,1fr)_160px_72px_96px_110px_120px_90px] gap-3 bg-surface-alt px-4 py-2.5 text-[11px] font-bold uppercase tracking-[0.6px] text-subtle lg:grid">
          <span>Order</span><span>Title</span><span>Icon (Phosphor)</span><span>Type</span><span>Premium only</span><span>Min version</span><span>On</span><span />
        </div>
        <div className="divide-y">{data.map((t) => <TabRow key={t.key} tab={t} />)}</div>
      </div>
    </>
  );
}
