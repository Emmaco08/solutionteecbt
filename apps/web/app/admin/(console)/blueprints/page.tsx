import { Suspense } from "react";
import type { Metadata } from "next";
import { requireStaff } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";
import { getCatalogue } from "@/lib/catalogue";
import { EmptyState, ErrorState, PageHeader, PageSkeleton, Panel } from "@/components/admin/ui";
import { AddSubject, BlueprintCard, type BlueprintRow, type SectionRow } from "./blueprints-ui";
import { Coverage, SortButton } from "./coverage-ui";

export const metadata: Metadata = { title: "Blueprints" };

export default function Page() {
  return <Suspense fallback={<PageSkeleton rows={8} />}><Blueprints /></Suspense>;
}

async function Blueprints() {
  const staff = await requireStaff(["super_admin", "admin", "editor"]);
  const supabase = await createClient();
  const { exams, subjects } = await getCatalogue();
  const bps = await supabase.from("exam_blueprints").select("id, exam_id, subject_id, total, sections").order("subject_id", { ascending: true, nullsFirst: true });
  if (bps.error) return <ErrorState message={bps.error.message} />;
  const rows: BlueprintRow[] = (bps.data ?? []).map((b) => ({
    id: b.id, exam_id: b.exam_id, subject_id: b.subject_id, total: b.total,
    sections: (Array.isArray(b.sections) ? (b.sections as unknown as SectionRow[]) : []).map((s) => ({
      key: s.key, label: s.label, count: Number(s.count) || 0, instruction: s.instruction ?? "", passage: Boolean(s.passage),
    })),
  }));

  // JAMB Use of English: how many published questions each year has in each section.
  const jamb = exams.find((e) => e.code === "JAMB");
  const english = subjects.find((s) => s.name === "Use of English");
  let coverage: { year: number; section: string | null }[] | null = null;
  if (jamb && english) {
    coverage = [];
    for (let from = 0; from < 50000; from += 1000) {
      const { data, error } = await supabase.from("questions").select("year, section")
        .eq("exam_id", jamb.id).eq("subject_id", english.id).eq("status", "published").is("deleted_at", null).range(from, from + 999);
      if (error) return <ErrorState message={error.message} />;
      coverage.push(...(data ?? []));
      if ((data?.length ?? 0) < 1000) break;
    }
  }
  const englishBp = jamb && english ? rows.find((r) => r.exam_id === jamb.id && r.subject_id === english.id) : undefined;

  return (
    <>
      <PageHeader
        title="Blueprints"
        description="How many questions a full paper has, and for Use of English, which sections it holds and in what order. Students always get a complete paper: if a year is short, the rest is filled quietly from other years."
      />
      {exams.map((e) => {
        const list = rows.filter((r) => r.exam_id === e.id);
        const free = subjects.filter((s) => !list.some((r) => r.subject_id === s.id));
        return (
          <section key={e.id} className="mb-6">
            <h2 className="mb-3 text-[17px] font-bold">{e.code}</h2>
            {list.length ? (
              <div className="space-y-3">
                {list.map((b) => (
                  <BlueprintCard key={b.id} bp={b} subject={subjects.find((s) => s.id === b.subject_id)?.name ?? null} examId={e.id}
                    canDelete={staff.role === "super_admin" || staff.role === "admin"} />
                ))}
              </div>
            ) : <div className="rounded-2xl border bg-card"><EmptyState title="No blueprint for this exam yet">Papers use the built-in sizes until one is added.</EmptyState></div>}
            <AddSubject examId={e.id} free={free} />
          </section>
        );
      })}
      {coverage && english ? (
        <Panel title="JAMB Use of English: questions per year" className="mt-2" actions={<SortButton />}>
          <Coverage rows={coverage} sections={englishBp?.sections ?? []} />
        </Panel>
      ) : null}
    </>
  );
}
