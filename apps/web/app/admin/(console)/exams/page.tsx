import { Suspense } from "react";
import Link from "next/link";
import type { Metadata } from "next";
import { Exam } from "@phosphor-icons/react/dist/ssr";
import { requireStaff, canEditContent, canManage } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";
import { getCatalogue } from "@/lib/catalogue";
import { EmptyState, ErrorState, PageHeader, PageSkeleton, Panel, Pill } from "@/components/admin/ui";
import { cn } from "@/lib/utils";
import { YearChip } from "./year-chip";
import { RulesForm, SubjectRuleRow } from "./forms";
import { AddExam, BUILT_IN, ExamDetailsForm } from "./exam-forms";

export const metadata: Metadata = { title: "Exams & years" };

export default function Page({ searchParams }: PageProps<"/admin/exams">) {
  return <Suspense fallback={<PageSkeleton rows={8} />}><Exams searchParams={searchParams} /></Suspense>;
}

async function Exams({ searchParams }: { searchParams: PageProps<"/admin/exams">["searchParams"] }) {
  const staff = await requireStaff();
  const sp = await searchParams;
  const { exams, subjects } = await getCatalogue();
  const exam = exams.find((e) => String(e.id) === sp.exam) ?? exams[0];
  if (!exam) return <ErrorState message="No exams are set up." />;
  const supabase = await createClient();
  const [cfg, subjRules, years, counts] = await Promise.all([
    supabase.from("exam_configs").select("*").eq("exam_id", exam.id).maybeSingle(),
    supabase.from("exam_subjects").select("*").eq("exam_id", exam.id),
    supabase.from("exam_years").select("id, subject_id, year, status, published_at").eq("exam_id", exam.id).order("year"),
    supabase.rpc("admin_year_counts", { p_exam: exam.id }),
  ]);
  if (years.error) return <ErrorState message={years.error.message} />;

  const qCount = new Map<string, { all: number; pub: number }>();
  for (const c of counts.data ?? []) qCount.set(`${c.subject_id}-${c.year}`, { all: Number(c.total), pub: Number(c.published) });

  const bySubject = new Map<number, typeof years.data>();
  for (const y of years.data ?? []) bySubject.set(y.subject_id, [...(bySubject.get(y.subject_id) ?? []), y]);
  const subjName = new Map(subjects.map((s) => [s.id, s.name]));
  const rulesBySubject = new Map((subjRules.data ?? []).map((r) => [r.subject_id, r]));
  const editable = canEditContent(staff.role);

  return (
    <>
      <PageHeader title="Exams & years" description="Add exams, set the rules for each one and choose which years students can practise. Publishing a year makes it appear in the app at once (free students only see the years set in Free vs Premium)." />
      <div className="mb-4 flex flex-wrap gap-2">
        {exams.map((e) => (
          <Link key={e.id} href={`/admin/exams?exam=${e.id}`}
            className={cn("flex h-[52px] items-center gap-2.5 rounded-2xl border bg-card pl-2 pr-4 font-bold", e.id === exam.id && "border-blue bg-info-soft ring-1 ring-blue")}>
            {/* Real exam-body logo from /brand/exam-bodies, the admin's upload for added exams, or the short name */}
            <span className="grid size-9 place-items-center rounded-lg border bg-white p-0.5 text-[10px] font-black text-[#0B1F44]">
              {BUILT_IN.includes(e.code) ? <img src={`/brand/exam-bodies/${e.code.toLowerCase()}.png`} alt="" className="max-h-full max-w-full object-contain" />
                : e.logo_path ? <img src={`/admin/api/image?key=${encodeURIComponent(e.logo_path)}`} alt="" className="max-h-full max-w-full object-contain" /> : e.code.slice(0, 4)}
            </span>
            {e.code}
            {!e.is_active ? <Pill>Hidden</Pill> : null}
          </Link>
        ))}
        {canManage(staff.role) ? <AddExam /> : null}
      </div>

      <div className="grid items-start gap-4 xl:grid-cols-[minmax(0,1fr)_380px]">
        <Panel title={`${exam.name}: years by subject`} actions={<span className="flex gap-2 text-xs"><Pill tone="ok">Published</Pill><Pill tone="warn">Draft</Pill></span>}>
          {bySubject.size ? (
            <div className="space-y-5">
              {[...bySubject.entries()].sort((a, b) => (subjName.get(a[0]) ?? "").localeCompare(subjName.get(b[0]) ?? "")).map(([sid, ys]) => (
                <div key={sid}>
                  <b className="text-sm">{subjName.get(sid)}</b>
                  <div className="mt-2 grid grid-cols-[repeat(auto-fill,minmax(96px,1fr))] gap-2">
                    {ys!.map((y) => {
                      const c = qCount.get(`${sid}-${y.year}`) ?? { all: 0, pub: 0 };
                      return <YearChip key={y.id} id={y.id} year={y.year} status={y.status} total={c.all} published={c.pub} editable={editable} />;
                    })}
                  </div>
                </div>
              ))}
            </div>
          ) : (
            <EmptyState icon={<Exam />} title={`No ${exam.code} years yet`}>Years appear here as soon as you import or add questions for them.</EmptyState>
          )}
        </Panel>

        <div className="space-y-4">
          <Panel title="Exam details">
            <ExamDetailsForm exam={exam} editable={canManage(staff.role)} />
          </Panel>
          <Panel title="Exam rules">
            {cfg.data ? <RulesForm cfg={cfg.data} editable={canManage(staff.role)} /> : <p className="text-sm text-muted-foreground">No rules set.</p>}
          </Panel>
          <Panel title="Subjects in this exam" bodyClassName="p-0">
            <div className="max-h-[420px] divide-y overflow-auto">
              {subjects.map((s) => (
                <SubjectRuleRow key={s.id} examId={exam.id} subjectId={s.id} name={s.name} rule={rulesBySubject.get(s.id) ?? null} editable={canManage(staff.role)} />
              ))}
            </div>
          </Panel>
        </div>
      </div>
    </>
  );
}
