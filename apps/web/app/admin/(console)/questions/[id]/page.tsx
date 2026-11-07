import { Suspense } from "react";
import type { Metadata } from "next";
import { notFound } from "next/navigation";
import { requireStaff, canEditContent } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";
import { PageHeader, PageSkeleton, when } from "@/components/admin/ui";
import { QuestionEditor } from "../editor";
import { editorLists } from "../editor-data";

export const metadata: Metadata = { title: "Edit question" };

export default function Page({ params }: PageProps<"/admin/questions/[id]">) {
  return <Suspense fallback={<PageSkeleton rows={8} />}><Edit params={params} /></Suspense>;
}

async function Edit({ params }: { params: PageProps<"/admin/questions/[id]">["params"] }) {
  const { id } = await params;
  if (!/^[0-9a-f-]{36}$/i.test(id)) notFound();
  const staff = await requireStaff();
  const supabase = await createClient();
  const [{ data: q }, lists] = await Promise.all([
    supabase.from("questions").select("*, topics(name)").eq("id", id).is("deleted_at", null).maybeSingle(),
    editorLists(),
  ]);
  if (!q) notFound();
  return (
    <>
      <PageHeader title="Edit question" description={`Last changed ${when(q.updated_at)}. Every change is kept in the audit log.`} />
      <QuestionEditor
        q={{
          id: q.id, exam_id: q.exam_id, subject_id: q.subject_id, year: q.year, number: q.number,
          topic: (q.topics as unknown as { name: string } | null)?.name ?? "", passage_id: q.passage_id, body: q.body,
          options: q.options as Record<string, string>, answer: q.answer, explanation: q.explanation, difficulty: q.difficulty,
          image_path: q.image_path, status: q.status, section: q.section, section_source: q.section_source,
        }}
        {...lists}
        canDelete={canEditContent(staff.role)}
      />
    </>
  );
}
