import { Suspense } from "react";
import type { Metadata } from "next";
import { requireStaff } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";
import { ErrorState, PageHeader, PageSkeleton, Panel } from "@/components/admin/ui";
import { SafetyForm, SafetyList, type Row, type SafetySettings } from "./safety-ui";

export const metadata: Metadata = { title: "Safety checks" };

export default function Page() {
  return <Suspense fallback={<PageSkeleton rows={10} />}><Safety /></Suspense>;
}

async function Safety() {
  await requireStaff(["super_admin", "admin"]);
  const supabase = await createClient();
  const [cfg, list] = await Promise.all([
    supabase.from("app_settings").select("value").eq("key", "auto_safety").maybeSingle(),
    supabase.rpc("admin_safety_list", { p_limit: 100 }),
  ]);
  if (list.error) return <ErrorState message={list.error.message} />;
  const v = (cfg.data?.value ?? {}) as Partial<SafetySettings>;
  const settings: SafetySettings = { on: v.on === true, alerts: v.alerts === true, warn: v.warn ?? 40, ban: v.ban ?? 80, points: (v.points ?? {}) as SafetySettings["points"] };
  return (
    <>
      <PageHeader title="Safety checks" description="Risk points from shared phones, second accounts, unfair tests, challenge disqualifications, blocked invites, refunded payments, hidden comments and AI rule-breaking. Points fade after 90 days. A student gets a warning email first; a ban comes only at the ban level, a day or more after the warning, and with at least two kinds of flags. Staff are never banned. Every ban can be appealed." />
      <div className="grid items-start gap-4 xl:grid-cols-[380px_minmax(0,1fr)]">
        <Panel title="Settings"><SafetyForm initial={settings} /></Panel>
        <Panel title="Students with points" bodyClassName="p-0"><SafetyList rows={(list.data ?? []) as unknown as Row[]} warn={settings.warn} ban={settings.ban} /></Panel>
      </div>
    </>
  );
}
