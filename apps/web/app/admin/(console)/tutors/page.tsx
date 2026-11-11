import { Suspense } from "react";
import type { Metadata } from "next";
import { requireStaff } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";
import { ErrorState, PageHeader, PageSkeleton } from "@/components/admin/ui";
import { TutorAdmin, type TRequest } from "./tutors-ui";

export const metadata: Metadata = { title: "Tutor requests" };

export default function Page({ searchParams }: { searchParams: Promise<{ show?: string }> }) {
  return <Suspense fallback={<PageSkeleton rows={8} />}><Tutors searchParams={searchParams} /></Suspense>;
}

async function Tutors({ searchParams }: { searchParams: Promise<{ show?: string }> }) {
  await requireStaff(["super_admin", "admin"]);
  const { show } = await searchParams;
  const status = ["open", "all", "new", "replied", "matched", "closed"].includes(show ?? "") ? show! : "open";
  const supabase = await createClient();
  const [reqs, tutors, plans] = await Promise.all([
    supabase.rpc("admin_tutor_requests", { p_status: status }),
    supabase.from("tutors").select("*").order("name"),
    supabase.from("tutor_plans").select("*").order("sort").order("price_kobo"),
  ]);
  if (reqs.error) return <ErrorState message={reqs.error.message} />;
  return (
    <>
      <PageHeader title="Tutor requests" description="Students ask for a tutor in the app (Study → Request a tutor). Reply here: the student sees it in the app chat and gets an email. Assign a tutor once they have a plan; the tutor's WhatsApp and phone show to the student only while the plan is active." />
      <TutorAdmin status={status} requests={(reqs.data ?? []) as TRequest[]} tutors={tutors.data ?? []} plans={plans.data ?? []} />
    </>
  );
}
