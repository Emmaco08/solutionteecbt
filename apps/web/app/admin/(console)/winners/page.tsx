import { Suspense } from "react";
import type { Metadata } from "next";
import { Trophy } from "@phosphor-icons/react/dist/ssr";
import { requireStaff } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";
import { EmptyState, ErrorState, PageHeader, PageSkeleton, Panel } from "@/components/admin/ui";
import { ClaimsList, WallList, type ClaimRow, type WallRow } from "./winners-ui";

export const metadata: Metadata = { title: "Winners & payouts" };

export default function Page() {
  return <Suspense fallback={<PageSkeleton rows={8} />}><Winners /></Suspense>;
}

async function Winners() {
  await requireStaff(["super_admin", "admin"]);
  const supabase = await createClient();
  const [claims, wall] = await Promise.all([
    supabase.rpc("admin_prize_claims"),
    supabase.from("winners_wall").select("id, challenge_title, name, state, place, amount, receipt_path, note, published, created_at").order("created_at", { ascending: false }).limit(50),
  ]);
  if (claims.error) return <ErrorState message={claims.error.message} />;
  const rows = (claims.data ?? []) as unknown as ClaimRow[];
  return (
    <>
      <PageHeader title="Winners & payouts" description="Winners send their account details in the app within 7 days. Pay by bank transfer, then mark it paid here and post the receipt on the Winners wall (hide the account number and balance first). Never ask for a PIN, card or password." />
      <div className="grid gap-4 xl:grid-cols-[1.4fr_1fr]">
        <Panel title="Winners to pay" bodyClassName="p-0">
          {rows.length ? <ClaimsList rows={rows} /> : <EmptyState icon={<Trophy />} title="No winners yet">When a cash challenge closes, its winners show here.</EmptyState>}
        </Panel>
        <Panel title="Winners wall posts" bodyClassName="p-0"><WallList rows={(wall.data ?? []) as WallRow[]} /></Panel>
      </div>
    </>
  );
}
