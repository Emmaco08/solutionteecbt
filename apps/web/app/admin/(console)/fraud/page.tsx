import { Suspense } from "react";
import type { Metadata } from "next";
import { ShieldCheck } from "@phosphor-icons/react/dist/ssr";
import { requireStaff } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";
import { EmptyState, ErrorState, PageHeader, PageSkeleton, Panel } from "@/components/admin/ui";
import { AppealsList, BannedList, PhonesList, type Appeal, type Banned, type Phone } from "./fraud-ui";

export const metadata: Metadata = { title: "Fraud & bans" };

export default function Page() {
  return <Suspense fallback={<PageSkeleton rows={8} />}><Fraud /></Suspense>;
}

async function Fraud() {
  await requireStaff(["super_admin", "admin"]);
  const supabase = await createClient();
  const { data, error } = await supabase.rpc("admin_fraud");
  if (error) return <ErrorState message={error.message} />;
  const d = data as unknown as { shared_phones: Phone[]; banned: Banned[]; appeals: Appeal[] };
  const waiting = d.appeals.filter((a) => a.status === "pending").length;
  return (
    <>
      <PageHeader title="Fraud & bans" description="One account per phone: a second account on a phone sees “This phone already has an account” and cannot earn rewards or prizes, unless you allow it (for example brothers and sisters). A ban cancels unpaid rewards and prizes; the student sees a ban screen and can send one appeal within 14 days. Everything is in the audit log." />
      <div className="grid gap-4 xl:grid-cols-2">
        <Panel title={`Ban appeals${waiting ? ` (${waiting} waiting)` : ""}`} bodyClassName="p-0">
          {d.appeals.length ? <AppealsList rows={d.appeals} /> : <p className="p-4 text-sm text-muted-foreground">No appeals.</p>}
        </Panel>
        <Panel title={`Phones with more than one account (${d.shared_phones.length})`} bodyClassName="p-0">
          {d.shared_phones.length ? <PhonesList rows={d.shared_phones} /> : <EmptyState icon={<ShieldCheck />} title="No shared phones">Every phone has one account.</EmptyState>}
        </Panel>
        <Panel title={`Banned students (${d.banned.length})`} bodyClassName="p-0">
          {d.banned.length ? <BannedList rows={d.banned} /> : <p className="p-4 text-sm text-muted-foreground">Nobody is banned.</p>}
        </Panel>
      </div>
    </>
  );
}
