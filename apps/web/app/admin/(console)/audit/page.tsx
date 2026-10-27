import { Suspense } from "react";
import Link from "next/link";
import type { Metadata } from "next";
import { ListChecks } from "@phosphor-icons/react/dist/ssr";
import { requireStaff } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";
import { EmptyState, ErrorState, PageHeader, PageSkeleton, Pill, when, type Tone } from "@/components/admin/ui";
import { cn } from "@/lib/utils";
import { AuditRow } from "./audit-row";

export const metadata: Metadata = { title: "Audit log" };

const AREAS: Record<string, { label: string; tone: Tone; tables: string[] }> = {
  content: { label: "Content", tone: "info", tables: ["questions", "passages", "topics", "exam_years", "import_batches", "news_posts", "exam_bodies", "subjects", "exam_subjects", "exam_configs"] },
  money: { label: "Money", tone: "gold", tables: ["plans", "entitlements"] },
  people: { label: "People", tone: "error", tables: ["staff", "profiles"] },
  settings: { label: "Settings", tone: "neutral", tables: ["access_rules", "feature_flags", "app_settings", "app_tabs", "onboarding_slides"] },
};
const areaOf = (t: string) => Object.entries(AREAS).find(([, a]) => a.tables.includes(t))?.[0] ?? "settings";

export default function Page({ searchParams }: PageProps<"/admin/audit">) {
  return <Suspense fallback={<PageSkeleton rows={10} />}><Audit searchParams={searchParams} /></Suspense>;
}

async function Audit({ searchParams }: { searchParams: PageProps<"/admin/audit">["searchParams"] }) {
  await requireStaff(["super_admin", "admin"]);
  const sp = await searchParams;
  const area = typeof sp.area === "string" && AREAS[sp.area] ? sp.area : "";
  const supabase = await createClient();
  let q = supabase.from("audit_log").select("id, at, actor, action, table_name, row_id, before, after").order("at", { ascending: false }).limit(100);
  if (area) q = q.in("table_name", AREAS[area]!.tables);
  const [{ data, error }, staff] = await Promise.all([q, supabase.rpc("admin_list_staff")]);
  if (error) return <ErrorState message={error.message} />;
  const names = new Map((staff.data ?? []).map((s) => [s.user_id, s.full_name || s.email]));
  return (
    <>
      <PageHeader title="Audit log" description="Every change to content, money, people and settings: who did it, when, and what changed. Rows cannot be edited or deleted." />
      <div className="mb-3 flex gap-1 overflow-x-auto border-b [scrollbar-width:none] [&::-webkit-scrollbar]:hidden">
        {[["", "All"], ...Object.entries(AREAS).map(([k, a]) => [k, a.label])].map(([k, label]) => (
          <Link key={k} href={k ? `/admin/audit?area=${k}` : "/admin/audit"}
            className={cn("relative h-11 whitespace-nowrap px-3 pt-3 text-sm font-bold text-muted-foreground hover:text-foreground",
              area === k && "text-foreground after:absolute after:inset-x-2 after:-bottom-px after:h-0.5 after:rounded after:bg-blue")}>{label}</Link>
        ))}
      </div>
      {data.length ? (
        <div className="divide-y overflow-hidden rounded-2xl border bg-card">
          {data.map((a) => (
            <AuditRow key={a.id}
              when={when(a.at)} who={a.actor ? names.get(a.actor) ?? "Former staff / student" : "System or server"}
              action={a.action.replace(/_/g, " ")} table={a.table_name.replace(/_/g, " ")} rowId={a.row_id ?? ""}
              area={<Pill tone={AREAS[areaOf(a.table_name)]!.tone}>{AREAS[areaOf(a.table_name)]!.label}</Pill>}
              before={a.before} after={a.after} />
          ))}
        </div>
      ) : <div className="rounded-2xl border bg-card"><EmptyState icon={<ListChecks />} title="Nothing logged yet">Changes made in this admin (or directly in the database) show up here.</EmptyState></div>}
      <p className="mt-3 text-xs text-muted-foreground">Showing the latest 100 entries.</p>
    </>
  );
}
