import { Suspense } from "react";
import type { Metadata } from "next";
import { Users } from "@phosphor-icons/react/dist/ssr";
import { requireStaff } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";
import { EmptyState, ErrorState, PageHeader, PageSkeleton } from "@/components/admin/ui";
import { Stat } from "@/components/admin/charts";
import { UserTable } from "./user-table";

export const metadata: Metadata = { title: "Users" };
const PAGE = 50;

export default function Page({ searchParams }: PageProps<"/admin/users">) {
  return <Suspense fallback={<PageSkeleton rows={10} />}><UsersPage searchParams={searchParams} /></Suspense>;
}

async function UsersPage({ searchParams }: { searchParams: PageProps<"/admin/users">["searchParams"] }) {
  await requireStaff(["super_admin", "admin"]);
  const sp = await searchParams;
  const q = typeof sp.q === "string" ? sp.q.slice(0, 80) : "";
  const platform = typeof sp.platform === "string" && ["android", "direct", "play", "windows", "none"].includes(sp.platform) ? sp.platform : "";
  const plan = typeof sp.plan === "string" && ["premium", "free", "staff", "banned"].includes(sp.plan) ? sp.plan : "";
  const page = Math.max(1, Number(sp.page) || 1);
  const supabase = await createClient();
  const [list, sum] = await Promise.all([
    supabase.rpc("admin_list_users", { p_search: q || undefined, p_limit: PAGE, p_offset: (page - 1) * PAGE, p_platform: platform || undefined, p_plan: plan || undefined }),
    supabase.rpc("admin_users_summary"),
  ]);
  const { data, error } = list;
  if (error) return <ErrorState message={error.message} />;
  const total = Number(data?.[0]?.total ?? 0);
  const s = (sum.data ?? {}) as Record<string, number>;
  const filtered = Boolean(q || platform || plan);
  return (
    <>
      <PageHeader title="Users" description="Every account: which app they use (website Android app, Play Store app, Windows), their exams and subject combination, plan and activity. Open a student to see more, give Premium or ban them. Every change is logged." />
      <div className="mb-4 grid grid-cols-2 gap-3 sm:grid-cols-3 xl:grid-cols-6">
        <Stat label="All accounts" value={s.total ?? 0} sub={`${s.new_7d ?? 0} new this week`} />
        <Stat label="Active this week" value={s.active_7d ?? 0} sub="Opened the app or took a test" />
        <Stat label="Premium" value={s.premium ?? 0} sub={`${s.banned ?? 0} banned`} />
        <Stat label="Android app" value={s.android ?? 0} sub={`Website ${s.direct ?? 0} · Play ${s.play ?? 0}`} help="Older app versions do not say which Android app; they count in Android only until they update." />
        <Stat label="Windows app" value={s.windows ?? 0} />
        <Stat label="Not seen in an app" value={s.no_app ?? 0} sub="Website only or never opened" />
      </div>
      <UserTable rows={(data ?? []) as never} q={q} platform={platform} plan={plan} page={page} pages={Math.max(1, Math.ceil(total / PAGE))} total={total} />
      {!data?.length ? (
        <div className="mt-3 rounded-2xl border bg-card">
          <EmptyState icon={<Users />} title={filtered ? "No one matches" : "No students yet"}>
            {filtered ? "Try another search or filter. Search works on email, name, phone and school." : "Students appear here when they sign up in the app."}
          </EmptyState>
        </div>
      ) : null}
    </>
  );
}
