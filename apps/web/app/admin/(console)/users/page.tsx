import { Suspense } from "react";
import type { Metadata } from "next";
import { Users } from "@phosphor-icons/react/dist/ssr";
import { requireStaff } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";
import { EmptyState, ErrorState, PageHeader, PageSkeleton } from "@/components/admin/ui";
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
  const page = Math.max(1, Number(sp.page) || 1);
  const supabase = await createClient();
  const { data, error } = await supabase.rpc("admin_list_users", { p_search: q || undefined, p_limit: PAGE, p_offset: (page - 1) * PAGE });
  if (error) return <ErrorState message={error.message} />;
  const total = Number(data?.[0]?.total ?? 0);
  return (
    <>
      <PageHeader title="Users" description={`${total.toLocaleString()} account${total === 1 ? "" : "s"}${q ? ` matching “${q}”` : ""}. Open a student to see their plan, give Premium or ban them. Every change is logged.`} />
      <UserTable rows={data ?? []} q={q} page={page} pages={Math.max(1, Math.ceil(total / PAGE))} />
      {!data?.length ? (
        <div className="mt-3 rounded-2xl border bg-card">
          <EmptyState icon={<Users />} title={q ? "No one matches that search" : "No students yet"}>
            {q ? "Search by email, name or phone number." : "Students appear here when they sign up in the app."}
          </EmptyState>
        </div>
      ) : null}
    </>
  );
}
