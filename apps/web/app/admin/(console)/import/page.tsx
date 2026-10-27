import { Suspense } from "react";
import type { Metadata } from "next";
import { redirect } from "next/navigation";
import { requireStaff, canEditContent } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";
import { getCatalogue } from "@/lib/catalogue";
import { PageHeader, PageSkeleton, Panel, Pill, when } from "@/components/admin/ui";
import { Importer } from "./importer";
import { UndoButton } from "./undo-button";

export const metadata: Metadata = { title: "CSV import" };

export default function Page() {
  return <Suspense fallback={<PageSkeleton rows={6} />}><ImportPage /></Suspense>;
}

async function ImportPage() {
  const staff = await requireStaff();
  if (!canEditContent(staff.role)) redirect("/admin");
  const supabase = await createClient();
  const [{ exams, subjects }, history] = await Promise.all([
    getCatalogue(),
    supabase.from("import_batches").select("id, file_name, total_rows, inserted_rows, created_at, undone_at, summary").order("created_at", { ascending: false }).limit(20),
  ]);
  return (
    <>
      <PageHeader title="CSV import" description="Add many past questions at once. Every row is checked before anything is saved, and imported questions arrive as drafts so you can review and publish them." />
      <div className="space-y-4">
        <Importer exams={exams.map((e) => e.code)} subjects={subjects.flatMap((s) => [s.code, s.name])} subjectHint={subjects.map((s) => `${s.code} = ${s.name}`).join(" · ")} />
        <Panel title="Import history" bodyClassName="p-0">
          {history.data?.length ? (
            <div className="overflow-x-auto">
              <table className="w-full text-sm">
                <thead className="bg-surface-alt text-left text-[11px] uppercase tracking-[0.6px] text-subtle">
                  <tr><th className="px-5 py-2.5">File</th><th className="px-3 py-2.5">Rows</th><th className="px-3 py-2.5">When</th><th className="px-3 py-2.5">Status</th><th className="px-3 py-2.5" /></tr>
                </thead>
                <tbody className="divide-y">
                  {history.data.map((b) => (
                    <tr key={b.id}>
                      <td className="px-5 py-3 font-bold">{b.file_name}</td>
                      <td className="tnum px-3 py-3">{b.inserted_rows.toLocaleString()}</td>
                      <td className="whitespace-nowrap px-3 py-3 text-muted-foreground">{when(b.created_at)}</td>
                      <td className="px-3 py-3">{b.undone_at ? <Pill>Undone {when(b.undone_at)}</Pill> : <Pill tone="ok">Imported</Pill>}</td>
                      <td className="px-3 py-3 text-right">{b.undone_at ? null : <UndoButton id={b.id} rows={b.inserted_rows} />}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          ) : <p className="px-5 py-8 text-center text-sm text-muted-foreground">No imports yet. Your first import will show here, with an Undo button.</p>}
        </Panel>
      </div>
    </>
  );
}
