import { Suspense } from "react";
import Link from "next/link";
import type { Metadata } from "next";
import { ArrowRight, Database, FileCsv, Plus, Trophy, Sparkle, CurrencyNgn, WarningCircle, CheckCircle } from "@phosphor-icons/react/dist/ssr";
import { requireStaff, canManage } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";
import { hasR2 } from "@/lib/env";
import { Panel, Pill, ErrorState, PageSkeleton, when } from "@/components/admin/ui";
import { buttonVariants } from "@/components/ui/button";

export const metadata: Metadata = { title: "Dashboard" };

type Dash = {
  students: number; new_students_7d: number; premium: number; questions: number; questions_published: number;
  questions_review: number; years_published: number; imports_7d: number; banned: number; by_subject: { name: string; n: number }[];
};

export default function Page() {
  return <Suspense fallback={<PageSkeleton rows={8} />}><Dashboard /></Suspense>;
}

async function Dashboard() {
  const staff = await requireStaff();
  const supabase = await createClient();
  const [{ data, error }, audit, plans] = await Promise.all([
    supabase.rpc("admin_dashboard"),
    canManage(staff.role) ? supabase.from("audit_log").select("id, at, action, table_name, row_id").order("at", { ascending: false }).limit(6) : Promise.resolve({ data: [] as { id: number; at: string; action: string; table_name: string; row_id: string | null }[] }),
    supabase.from("plans").select("description").ilike("description", "SAMPLE%"),
  ]);
  if (error) return <ErrorState message={error.message} />;
  const d = data as unknown as Dash;
  const hour = new Date().getHours();
  const greet = hour < 12 ? "Good morning" : hour < 17 ? "Good afternoon" : "Good evening";

  const attention = [
    d.questions_review > 0 && { tone: "warn", text: `${d.questions_review} question${d.questions_review === 1 ? "" : "s"} waiting for review`, href: "/admin/questions?status=review" },
    d.questions === 0 && { tone: "warn", text: "No questions yet. Import your first CSV.", href: "/admin/import" },
    d.years_published === 0 && d.questions > 0 && { tone: "warn", text: "No year is published, so students see nothing yet.", href: "/admin/exams" },
    (plans.data?.length ?? 0) > 0 && canManage(staff.role) && { tone: "warn", text: "Plan prices are still the SAMPLE prices. Confirm them.", href: "/admin/plans" },
    !hasR2() && { tone: "error", text: "Image storage (Cloudflare R2) is not set up, so image upload is off.", href: "/admin/settings" },
  ].filter(Boolean) as { tone: "warn" | "error"; text: string; href: string }[];

  const kpis = [
    { label: "Students", value: d.students, sub: `+${d.new_students_7d} in the last 7 days` },
    { label: "Premium students", value: d.premium, sub: d.students ? `${Math.round((d.premium / d.students) * 100)}% of students` : "No students yet" },
    { label: "Questions", value: d.questions, sub: `${d.questions_published} published` },
    { label: "Years published", value: d.years_published, sub: `${d.imports_7d} import${d.imports_7d === 1 ? "" : "s"} this week` },
  ];
  const maxSubj = Math.max(1, ...d.by_subject.map((s) => s.n));

  return (
    <div className="space-y-4">
      <div className="mb-2 flex flex-wrap items-end justify-between gap-4">
        <div>
          <p className="text-sm text-muted-foreground">{new Date().toLocaleDateString("en-GB", { weekday: "long", day: "numeric", month: "long" })}</p>
          <h1 className="mt-1 text-[30px] font-bold leading-9 tracking-[-0.5px]">{greet}, {staff.name.split(" ")[0]}</h1>
          <p className="mt-1 text-sm text-muted-foreground">Here is what is happening on SolutionTee.</p>
        </div>
        <div className="flex flex-wrap gap-2">
          <Link href="/admin/import" className={buttonVariants({ variant: "outline" })}><FileCsv size={18} /> Import CSV</Link>
          <Link href="/admin/questions/new" className={buttonVariants()}><Plus size={18} weight="bold" /> New question</Link>
        </div>
      </div>

      {attention.length ? (
        <div className="grid gap-3 sm:grid-cols-2 xl:grid-cols-4">
          {attention.map((a) => (
            <Link key={a.text} href={a.href} className="flex items-center gap-3 rounded-2xl border bg-card p-3.5 transition hover:-translate-y-px hover:shadow-[var(--shadow-2)]">
              <span className={`grid size-[34px] flex-none place-items-center rounded-[10px] ${a.tone === "error" ? "bg-error-soft text-on-error-soft" : "bg-warning-soft text-on-warning-soft"}`}><WarningCircle size={18} weight="fill" /></span>
              <span className="grow text-sm font-bold leading-5">{a.text}</span>
              <ArrowRight size={16} className="text-subtle" />
            </Link>
          ))}
        </div>
      ) : (
        <p className="flex items-center gap-2 rounded-2xl border bg-card px-4 py-3 text-sm"><CheckCircle size={18} weight="fill" className="text-success" /> Nothing needs your attention right now.</p>
      )}

      <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
        {kpis.map((k) => (
          <div key={k.label} className="rounded-2xl border bg-card p-5 shadow-[var(--shadow-1)]">
            <span className="text-sm font-bold text-muted-foreground">{k.label}</span>
            <b className="tnum mt-1.5 block text-[28px] leading-[34px] tracking-[-0.4px]">{k.value.toLocaleString()}</b>
            <span className="text-xs text-muted-foreground">{k.sub}</span>
          </div>
        ))}
      </div>

      <div className="grid gap-4 xl:grid-cols-3">
        <Panel title="Questions by subject" className="xl:col-span-2" actions={<Link href="/admin/questions" className="text-sm font-bold text-[var(--c-link)]">Open bank</Link>}>
          {d.by_subject.length ? (
            <div className="space-y-3.5">
              {d.by_subject.map((s) => (
                <div key={s.name}>
                  <div className="flex justify-between text-sm"><b>{s.name}</b><span className="tnum text-muted-foreground">{s.n.toLocaleString()}</span></div>
                  <div className="mt-1.5 h-2 overflow-hidden rounded-full bg-muted"><div className="h-full rounded-full bg-blue" style={{ width: `${(s.n / maxSubj) * 100}%` }} /></div>
                </div>
              ))}
            </div>
          ) : (
            <div className="flex flex-col items-center py-8 text-center">
              <Database size={32} className="text-subtle" />
              <p className="mt-2 text-sm text-muted-foreground">No questions yet. Import a CSV or add one by hand.</p>
            </div>
          )}
        </Panel>
        <Panel title="Recent activity" actions={canManage(staff.role) ? <Link href="/admin/audit" className="text-sm font-bold text-[var(--c-link)]">View all</Link> : null}>
          {audit.data?.length ? (
            <ul className="divide-y text-sm">
              {audit.data.map((a) => (
                <li key={a.id} className="flex justify-between gap-3 py-2.5">
                  <span><b className="capitalize">{a.action.replace(/_/g, " ")}</b> <span className="text-muted-foreground">{a.table_name.replace(/_/g, " ")}</span></span>
                  <span className="whitespace-nowrap text-xs text-muted-foreground">{when(a.at)}</span>
                </li>
              ))}
            </ul>
          ) : <p className="py-6 text-center text-sm text-muted-foreground">{canManage(staff.role) ? "No admin activity yet." : "Activity is visible to admins."}</p>}
        </Panel>
      </div>

      <div className="grid gap-4 md:grid-cols-3">
        {[
          { icon: <CurrencyNgn size={20} />, title: "Revenue and payments", phase: "Phase 4", text: "Paystack and Google Play payments, verified on the server." },
          { icon: <Sparkle size={20} />, title: "AI tutor health", phase: "Phase 4", text: "Prompts answered, speed and the NVIDIA rate limit." },
          { icon: <Trophy size={20} />, title: "Live challenge", phase: "Phase 4b", text: "Players, fair-play checks and winners." },
        ].map((c) => (
          <div key={c.title} className="rounded-2xl border border-dashed bg-card/60 p-5">
            <div className="flex items-center justify-between"><span className="text-muted-foreground">{c.icon}</span><Pill>{c.phase}</Pill></div>
            <b className="mt-3 block">{c.title}</b>
            <p className="mt-1 text-sm text-muted-foreground">{c.text}</p>
          </div>
        ))}
      </div>
    </div>
  );
}
