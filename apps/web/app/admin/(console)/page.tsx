import { Suspense } from "react";
import Link from "next/link";
import type { Metadata } from "next";
import { ArrowRight, Database, FileCsv, Plus, WarningCircle, CheckCircle } from "@phosphor-icons/react/dist/ssr";
import { requireStaff, canManage } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";
import { hasR2 } from "@/lib/env";
import { Panel, ErrorState, PageSkeleton, when } from "@/components/admin/ui";
import { buttonVariants } from "@/components/ui/button";
import { Challenges, Learning, Overview, Payments, PeriodTabs, Students, TABS, type Analytics, type Tab } from "./analytics";

export const metadata: Metadata = { title: "Dashboard" };

type Dash = {
  students: number; new_students_7d: number; premium: number; questions: number; questions_published: number;
  questions_review: number; years_published: number; imports_7d: number; banned: number; by_subject: { name: string; n: number }[];
};

export default function Page({ searchParams }: PageProps<"/admin">) {
  return <Suspense fallback={<PageSkeleton rows={8} />}><Dashboard searchParams={searchParams} /></Suspense>;
}

async function Dashboard({ searchParams }: { searchParams: PageProps<"/admin">["searchParams"] }) {
  const staff = await requireStaff();
  const sp = await searchParams;
  const days = [7, 30, 90].includes(Number(sp.days)) ? Number(sp.days) : 30;
  const money = canManage(staff.role); // payments and revenue: admins only
  const tabs = TABS.filter(([k]) => k !== "payments" || money);
  const tab = (tabs.find(([k]) => k === sp.tab)?.[0] ?? "overview") as Tab;
  const supabase = await createClient();
  const [{ data, error }, analytics, audit, plans] = await Promise.all([
    supabase.rpc("admin_dashboard"),
    supabase.rpc("admin_analytics", { p_days: days }),
    canManage(staff.role) ? supabase.from("audit_log").select("id, at, action, table_name, row_id").order("at", { ascending: false }).limit(6) : Promise.resolve({ data: [] as { id: number; at: string; action: string; table_name: string; row_id: string | null }[] }),
    supabase.from("plans").select("description").ilike("description", "SAMPLE%"),
  ]);
  if (error) return <ErrorState message={error.message} />;
  const d = data as unknown as Dash;
  const a = analytics.data as unknown as Analytics | null;
  const hour = new Date().getHours();
  const greet = hour < 12 ? "Good morning" : hour < 17 ? "Good afternoon" : "Good evening";

  const attention = [
    d.questions_review > 0 && { tone: "warn", text: `${d.questions_review} question${d.questions_review === 1 ? "" : "s"} waiting for review`, href: "/admin/questions?status=review" },
    d.questions === 0 && { tone: "warn", text: "No questions yet. Import your first CSV.", href: "/admin/import" },
    d.years_published === 0 && d.questions > 0 && { tone: "warn", text: "No year is published, so students see nothing yet.", href: "/admin/exams" },
    (plans.data?.length ?? 0) > 0 && canManage(staff.role) && { tone: "warn", text: "Plan prices are still the SAMPLE prices. Confirm them.", href: "/admin/plans" },
    !hasR2() && { tone: "error", text: "Image storage (Cloudflare R2) is not set up, so image upload is off.", href: "/admin/settings" },
  ].filter(Boolean) as { tone: "warn" | "error"; text: string; href: string }[];

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

      <PeriodTabs days={days} tab={tab} tabs={tabs} />
      {!a ? <ErrorState message={analytics.error?.message ?? "Could not load the numbers."} /> : tab === "students" ? <Students a={a} />
        : tab === "learning" ? <Learning a={a} /> : tab === "challenges" ? <Challenges a={a} /> : tab === "payments" && money ? <Payments a={a} />
        : <Overview a={a} money={money} />}

      {tab === "overview" ? (
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
              {audit.data.map((ev) => (
                <li key={ev.id} className="flex justify-between gap-3 py-2.5">
                  <span><b className="capitalize">{ev.action.replace(/_/g, " ")}</b> <span className="text-muted-foreground">{ev.table_name.replace(/_/g, " ")}</span></span>
                  <span className="whitespace-nowrap text-xs text-muted-foreground">{when(ev.at)}</span>
                </li>
              ))}
            </ul>
          ) : <p className="py-6 text-center text-sm text-muted-foreground">{canManage(staff.role) ? "No admin activity yet." : "Activity is visible to admins."}</p>}
        </Panel>
      </div>
      ) : null}
    </div>
  );
}
