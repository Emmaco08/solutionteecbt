import { Suspense } from "react";
import type { Metadata } from "next";
import { notFound } from "next/navigation";
import { requireStaff, canEditStudy } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";
import { PageHeader, PageSkeleton } from "@/components/admin/ui";
import { StudyForm, type StudyItem } from "../study-form";
import { studyLists } from "../data";
import { KIND_INFO, type StudyKind } from "../kinds";

export const metadata: Metadata = { title: "Edit study content" };

export default function Page({ params }: PageProps<"/admin/study/[id]">) {
  return <Suspense fallback={<PageSkeleton />}><Edit params={params} /></Suspense>;
}

async function Edit({ params }: { params: PageProps<"/admin/study/[id]">["params"] }) {
  const { id } = await params;
  if (!/^[0-9a-f-]{36}$/i.test(id)) notFound();
  const staff = await requireStaff();
  const supabase = await createClient();
  const [{ data }, lists] = await Promise.all([
    supabase.from("study_items").select("*").eq("id", id).is("deleted_at", null).maybeSingle(),
    studyLists(),
  ]);
  if (!data) notFound();
  const item = { ...data, kind: data.kind as StudyKind, data: data.data as Record<string, unknown>, files: data.files as Record<string, unknown> } satisfies StudyItem;
  return (<><PageHeader title={`Edit ${KIND_INFO[item.kind].one}`} /><StudyForm item={item} {...lists} canDelete={canEditStudy(staff.role)} /></>);
}
