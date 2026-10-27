import { Suspense } from "react";
import type { Metadata } from "next";
import { redirect } from "next/navigation";
import { requireStaff, canEditContent } from "@/lib/auth";
import { PageHeader, PageSkeleton } from "@/components/admin/ui";
import { QuestionEditor } from "../editor";
import { editorLists } from "../editor-data";

export const metadata: Metadata = { title: "New question" };

export default function Page() {
  return <Suspense fallback={<PageSkeleton rows={8} />}><New /></Suspense>;
}

async function New() {
  const staff = await requireStaff();
  if (!canEditContent(staff.role)) redirect("/admin/questions");
  const lists = await editorLists();
  return (
    <>
      <PageHeader title="New question" description="Saved as a draft unless you choose Published. Students only see published questions in published years." />
      <QuestionEditor q={{ year: new Date().getFullYear() - 1 }} {...lists} canDelete={false} />
    </>
  );
}
