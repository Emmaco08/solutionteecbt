import { Suspense } from "react";
import type { Metadata } from "next";
import { requireStaff } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";
import { ErrorState, PageHeader, PageSkeleton, Panel } from "@/components/admin/ui";
import { SlideForm } from "./slide-form";

export const metadata: Metadata = { title: "Onboarding" };

export default function Page() {
  return <Suspense fallback={<PageSkeleton rows={6} />}><Onboarding /></Suspense>;
}

async function Onboarding() {
  await requireStaff(["super_admin", "admin"]);
  const supabase = await createClient();
  const { data, error } = await supabase.from("onboarding_slides").select("*").order("sort");
  if (error) return <ErrorState message={error.message} />;
  return (
    <>
      <PageHeader title="Onboarding" description="The slides new students swipe through before they sign up. Keep titles short (about 5 words) and text to one or two lines." />
      <div className="grid gap-4 lg:grid-cols-2">
        {data.map((s, i) => (
          <Panel key={s.id} title={`Slide ${i + 1}`}><SlideForm slide={s} /></Panel>
        ))}
        <Panel title="Add a slide"><SlideForm slide={{ sort: data.length + 1, enabled: true }} /></Panel>
      </div>
    </>
  );
}
