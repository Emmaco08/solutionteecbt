import { Suspense } from "react";
import type { Metadata } from "next";
import { BellRinging } from "@phosphor-icons/react/dist/ssr";
import { requireStaff } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";
import { EmptyState, ErrorState, PageHeader, PageSkeleton, Panel } from "@/components/admin/ui";
import { Compose, History, type NotifRow } from "./notif-ui";

export const metadata: Metadata = { title: "Notifications" };

export default function Page() {
  return <Suspense fallback={<PageSkeleton rows={8} />}><Notifications /></Suspense>;
}

async function Notifications() {
  await requireStaff(["super_admin", "admin", "editor"]);
  const supabase = await createClient();
  const [{ data, error }, news] = await Promise.all([
    supabase.rpc("admin_notifications", { p_limit: 100 }),
    supabase.from("news_posts").select("id, title").eq("status", "published").order("publish_at", { ascending: false }).limit(30),
  ]);
  if (error) return <ErrorState message={error.message} />;
  const rows = (data ?? []) as unknown as NotifRow[];
  return (
    <>
      <PageHeader title="Notifications" description="Messages to students' phones and their Notifications screen. Students can switch each topic off in Settings. Test on your own phone first with “Only my test phones”." />
      <div className="grid gap-4 xl:grid-cols-[1fr_1.1fr]">
        <Panel title="Write a message"><Compose news={news.data ?? []} /></Panel>
        <Panel title="Sent and scheduled" bodyClassName="p-0">
          {rows.length ? <History rows={rows} /> : (
            <EmptyState icon={<BellRinging />} title="No messages yet">Messages you send, news posts sent as notifications and new exam years appear here.</EmptyState>
          )}
        </Panel>
      </div>
    </>
  );
}
