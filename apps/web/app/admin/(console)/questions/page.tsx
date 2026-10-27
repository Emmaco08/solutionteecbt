import { Suspense } from "react";
import Link from "next/link";
import type { Metadata } from "next";
import { Database, FileCsv, Plus } from "@phosphor-icons/react/dist/ssr";
import { requireStaff, canEditContent } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";
import { getCatalogue, STATUS_LABEL } from "@/lib/catalogue";
import { EmptyState, ErrorState, PageHeader, PageSkeleton } from "@/components/admin/ui";
import { buttonVariants } from "@/components/ui/button";
import { QuestionTable, type QRow } from "./question-table";
import { Filters } from "./filters";

export const metadata: Metadata = { title: "Question bank" };
const PAGE = 25;

export default function Page({ searchParams }: PageProps<"/admin/questions">) {
  return <Suspense fallback={<PageSkeleton rows={10} />}><Bank searchParams={searchParams} /></Suspense>;
}

async function Bank({ searchParams }: { searchParams: PageProps<"/admin/questions">["searchParams"] }) {
  const staff = await requireStaff();
  const sp = await searchParams;
  const s = (k: string) => (typeof sp[k] === "string" ? (sp[k] as string) : "");
  const status = (["draft", "review", "published"] as const).find((x) => x === s("status"));
  const page = Math.max(1, Number(s("page")) || 1);
  const supabase = await createClient();
  const { exams, subjects } = await getCatalogue();

  let q = supabase
    .from("questions")
    .select("id, body, year, number, status, difficulty, updated_at, exam_bodies(code), subjects(name), topics(name)", { count: "exact" })
    .is("deleted_at", null);
  if (status) q = q.eq("status", status);
  if (s("exam")) q = q.eq("exam_id", Number(s("exam")));
  if (s("subject")) q = q.eq("subject_id", Number(s("subject")));
  if (s("year")) q = q.eq("year", Number(s("year")));
  if (s("q")) q = q.ilike("body", `%${s("q").replace(/[%_]/g, "")}%`);
  const { data, count, error } = await q.order("updated_at", { ascending: false }).range((page - 1) * PAGE, page * PAGE - 1);
  if (error) return <ErrorState message={error.message} />;

  // Counts for the status tabs (same filters, without status).
  const counts = await Promise.all(
    (["draft", "review", "published"] as const).map(async (st) => {
      let c = supabase.from("questions").select("id", { count: "exact", head: true }).is("deleted_at", null).eq("status", st);
      if (s("exam")) c = c.eq("exam_id", Number(s("exam")));
      if (s("subject")) c = c.eq("subject_id", Number(s("subject")));
      return [st, (await c).count ?? 0] as const;
    }),
  );
  const total = counts.reduce((t, [, n]) => t + n, 0);
  const rows: QRow[] = (data ?? []).map((r) => ({
    id: r.id, body: r.body, year: r.year, number: r.number, status: r.status, difficulty: r.difficulty,
    exam: (r.exam_bodies as unknown as { code: string } | null)?.code ?? "", subject: (r.subjects as unknown as { name: string } | null)?.name ?? "",
    topic: (r.topics as unknown as { name: string } | null)?.name ?? "",
  }));
  const editable = canEditContent(staff.role);

  return (
    <>
      <PageHeader
        title="Question bank"
        description={`${total.toLocaleString()} questions. Students only receive published questions from years their plan opens.`}
        actions={editable ? <>
          <Link href="/admin/import" className={buttonVariants({ variant: "outline" })}><FileCsv size={18} /> Import CSV</Link>
          <Link href="/admin/questions/new" className={buttonVariants()}><Plus size={18} weight="bold" /> New question</Link>
        </> : null}
      />
      <Filters exams={exams} subjects={subjects} current={{ q: s("q"), exam: s("exam"), subject: s("subject"), year: s("year"), status: status ?? "" }}
        tabs={[["", "All", total], ...counts.map(([st, n]) => [st, STATUS_LABEL[st], n] as [string, string, number])]} />
      {rows.length ? (
        <QuestionTable rows={rows} editable={editable} savedId={s("saved")} page={page} pages={Math.max(1, Math.ceil((count ?? 0) / PAGE))} total={count ?? 0} />
      ) : (
        <div className="rounded-2xl border bg-card">
          <EmptyState icon={<Database />} title={total ? "No questions match these filters" : "No questions yet"}
            action={editable ? <Link href="/admin/import" className={buttonVariants()}><FileCsv size={18} /> Import a CSV</Link> : null}>
            {total ? "Try clearing the search or picking another exam, subject or year." : "Import a CSV file of past questions, or add questions one by one."}
          </EmptyState>
        </div>
      )}
    </>
  );
}
