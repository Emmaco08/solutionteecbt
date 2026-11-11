import { Suspense } from "react";
import type { Metadata } from "next";
import { requireStaff } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";
import { ErrorState, PageHeader, PageSkeleton } from "@/components/admin/ui";
import { AccessForm } from "./access-form";
import { rulesFor } from "./rules";

export const metadata: Metadata = { title: "Free vs Premium" };

export default function Page() {
  return <Suspense fallback={<PageSkeleton rows={12} />}><Access /></Suspense>;
}

async function Access() {
  await requireStaff(["super_admin", "admin"]);
  const supabase = await createClient();
  const [{ data, error }, exams] = await Promise.all([
    supabase.from("access_rules").select("tier, rules, updated_at"),
    supabase.from("exam_bodies").select("code").order("sort"),
  ]);
  if (error) return <ErrorState message={error.message} />;
  const free = (data.find((r) => r.tier === "free")?.rules ?? {}) as Record<string, unknown>;
  const premium = (data.find((r) => r.tier === "premium")?.rules ?? {}) as Record<string, unknown>;
  return (
    <>
      <PageHeader title="Free vs Premium" description="What each plan can open. The server applies these rules to every request, so a changed or hacked app cannot unlock more. Changes apply straight away and are logged." />
      <AccessForm rules={rulesFor(exams.data ?? [])} free={free} premium={premium} />
    </>
  );
}
