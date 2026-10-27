import { Suspense } from "react";
import type { Metadata } from "next";
import { requireStaff } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";
import { ErrorState, PageHeader, PageSkeleton, Panel } from "@/components/admin/ui";
import { InviteForm, StaffList } from "./staff-ui";

export const metadata: Metadata = { title: "Staff" };

export default function Page() {
  return <Suspense fallback={<PageSkeleton rows={5} />}><Staff /></Suspense>;
}

async function Staff() {
  const me = await requireStaff(["super_admin", "admin"]);
  const supabase = await createClient();
  const { data, error } = await supabase.rpc("admin_list_staff");
  if (error) return <ErrorState message={error.message} />;
  const superAdmin = me.role === "super_admin";
  return (
    <>
      <PageHeader title="Staff" description="Who can use this admin. Super admins invite people and set roles. Every staff member must use 2-step login." />
      <div className="grid items-start gap-4 xl:grid-cols-[minmax(0,1fr)_380px]">
        <StaffList rows={data ?? []} meId={me.id} canEdit={superAdmin} />
        <div className="space-y-4">
          {superAdmin ? <Panel title="Invite someone"><InviteForm /></Panel> : null}
          <Panel title="What each role can do">
            <ul className="space-y-2.5 text-sm">
              <li><b>Super admin:</b> everything, including staff.</li>
              <li><b>Admin:</b> everything except staff: users, plans, rules, settings.</li>
              <li><b>Editor:</b> questions, imports, passages, years, news.</li>
              <li><b>Teacher:</b> read-only for now (classes come in Phase 5).</li>
            </ul>
          </Panel>
        </div>
      </div>
    </>
  );
}
