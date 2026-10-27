import { Suspense } from "react";
import type { Metadata } from "next";
import { Article } from "@phosphor-icons/react/dist/ssr";
import { requireStaff, canEditContent } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";
import { getCatalogue } from "@/lib/catalogue";
import { EmptyState, ErrorState, PageHeader, PageSkeleton, Panel } from "@/components/admin/ui";
import { PassageForm } from "./passage-form";

export const metadata: Metadata = { title: "Passages" };

export default function Page() {
  return <Suspense fallback={<PageSkeleton rows={6} />}><Passages /></Suspense>;
}

async function Passages() {
  const staff = await requireStaff();
  const supabase = await createClient();
  const [{ exams, subjects }, { data, error }] = await Promise.all([
    getCatalogue(),
    supabase.from("passages").select("id, exam_id, subject_id, year, title, body, questions(count)").order("created_at", { ascending: false }).limit(100),
  ]);
  if (error) return <ErrorState message={error.message} />;
  const editable = canEditContent(staff.role);
  const opts = { exams: exams.map((e) => ({ id: e.id, label: e.code })), subjects: subjects.map((s) => ({ id: s.id, label: s.name })) };
  return (
    <>
      <PageHeader title="Comprehension passages" description="A passage stays on screen while students answer the questions linked to it. Link questions to a passage in the question editor or with the passage_id column in a CSV." />
      <div className="grid items-start gap-4 xl:grid-cols-[minmax(0,1fr)_420px]">
        <div className="space-y-3">
          {data.length ? data.map((p) => (
            <Panel key={p.id} title={<span className="flex flex-wrap items-center gap-2">{p.title || "Untitled passage"}
              <span className="text-xs font-normal text-muted-foreground">{exams.find((e) => e.id === p.exam_id)?.code} {p.year ?? ""} · {subjects.find((s) => s.id === p.subject_id)?.name} · {(p.questions as unknown as { count: number }[])[0]?.count ?? 0} questions</span></span>}>
              {editable ? <PassageForm {...opts} passage={p} /> : <p className="line-clamp-4 whitespace-pre-line text-sm">{p.body}</p>}
              <p className="mt-3 text-xs text-muted-foreground">Passage ID for CSV: <code className="select-all font-mono">{p.id}</code></p>
            </Panel>
          )) : <div className="rounded-2xl border bg-card"><EmptyState icon={<Article />} title="No passages yet">Add one on the right. Use passages for English comprehension and Literature.</EmptyState></div>}
        </div>
        {editable ? <Panel title="Add a passage" className="xl:sticky xl:top-[88px]"><PassageForm {...opts} /></Panel> : null}
      </div>
    </>
  );
}
