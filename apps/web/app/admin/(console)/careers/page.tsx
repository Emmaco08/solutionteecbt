import { Suspense } from "react";
import type { Metadata } from "next";
import { requireStaff } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";
import { ErrorState, PageHeader, PageSkeleton } from "@/components/admin/ui";
import { CareerList, type Career } from "./careers-ui";

export const metadata: Metadata = { title: "Careers" };

export default function Page() {
  return <Suspense fallback={<PageSkeleton rows={10} />}><Careers /></Suspense>;
}

async function Careers() {
  await requireStaff(["super_admin", "admin", "editor"]);
  const supabase = await createClient();
  const [list, subjects] = await Promise.all([
    supabase.from("careers").select("id, name, field, course, years, summary, skills, universities, earnings, jamb_subjects, jamb_note, olevel, after_school, checked, active, sort, updated_at").order("sort").order("id"),
    supabase.from("subjects").select("code, name").order("sort"),
  ]);
  if (list.error) return <ErrorState message={list.error.message} />;
  return (
    <>
      <PageHeader
        title="Careers"
        description="Students pick a dream career in the app and see what the job is, the JAMB subject combination, the O'level subjects, the course, where to study and rough pay. Check every combination against this year's JAMB brochure before you tick it as checked."
      />
      <CareerList careers={(list.data ?? []) as Career[]} subjects={(subjects.data ?? []) as { code: string; name: string }[]} />
    </>
  );
}
