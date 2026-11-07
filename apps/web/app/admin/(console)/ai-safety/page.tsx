import { Suspense } from "react";
import type { Metadata } from "next";
import { requireStaff } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";
import { ErrorState, PageHeader, PageSkeleton } from "@/components/admin/ui";
import { SafetyBoard, type SafetyRow } from "./safety-ui";

export const metadata: Metadata = { title: "AI safety" };

export default function Page() {
  return <Suspense fallback={<PageSkeleton rows={6} />}><Safety /></Suspense>;
}

async function Safety() {
  await requireStaff(["super_admin", "admin"]);
  const supabase = await createClient();
  const { data, error } = await supabase.rpc("admin_ai_safety_list");
  if (error) return <ErrorState message={error.message} />;
  return (
    <>
      <PageHeader
        title="AI safety"
        description="Students who tried to break the AI tutor's rules or pull out private data. 3 warnings in a day pause the AI for 3 days, the next time for 7 days, and the third time it waits here for your decision."
      />
      <SafetyBoard rows={(data ?? []) as unknown as SafetyRow[]} />
    </>
  );
}
