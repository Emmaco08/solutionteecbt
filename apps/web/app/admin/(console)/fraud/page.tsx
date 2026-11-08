import { Suspense } from "react";
import type { Metadata } from "next";
import { requireStaff } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";
import { ErrorState, PageHeader, PageSkeleton } from "@/components/admin/ui";
import { FraudBoard, type FraudData } from "./fraud-ui";

export const metadata: Metadata = { title: "Fraud & bans" };

export default function Page() {
  return <Suspense fallback={<PageSkeleton rows={8} />}><Fraud /></Suspense>;
}

async function Fraud() {
  await requireStaff(["super_admin", "admin"]);
  const supabase = await createClient();
  const { data, error } = await supabase.rpc("admin_fraud");
  if (error) return <ErrorState message={error.message} />;
  return (
    <>
      <PageHeader title="Fraud & bans" description="One account per phone. Decide paused second accounts and appeals in To do; every decision emails the student and is kept in the audit log." />
      <FraudBoard d={data as unknown as FraudData} />
    </>
  );
}
