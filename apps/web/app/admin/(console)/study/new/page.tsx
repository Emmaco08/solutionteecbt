import { Suspense } from "react";
import type { Metadata } from "next";
import { redirect } from "next/navigation";
import { requireStaff, canEditStudy } from "@/lib/auth";
import { PageHeader, PageSkeleton } from "@/components/admin/ui";
import { StudyForm } from "../study-form";
import { studyLists } from "../data";
import { KINDS, KIND_INFO, type StudyKind } from "../kinds";

export const metadata: Metadata = { title: "Add study content" };

export default function Page({ searchParams }: PageProps<"/admin/study/new">) {
  return <Suspense fallback={<PageSkeleton />}><New searchParams={searchParams} /></Suspense>;
}

async function New({ searchParams }: { searchParams: PageProps<"/admin/study/new">["searchParams"] }) {
  const staff = await requireStaff();
  if (!canEditStudy(staff.role)) redirect("/admin/study");
  const sp = await searchParams;
  const kind: StudyKind = (KINDS as readonly string[]).includes(String(sp.kind)) ? (sp.kind as StudyKind) : "video_solution";
  const lists = await studyLists();
  return (<><PageHeader title={`Add ${KIND_INFO[kind].one}`} /><StudyForm item={{ kind, status: "draft" }} {...lists} canDelete={false} /></>);
}
