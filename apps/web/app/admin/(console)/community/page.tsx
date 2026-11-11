import { Suspense } from "react";
import type { Metadata } from "next";
import Link from "next/link";
import { requireStaff } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";
import { ErrorState, PageHeader, PageSkeleton, Panel } from "@/components/admin/ui";
import { cn } from "@/lib/utils";
import { CommunitySettingsForm, ModList, type ModItem, type CommunitySettings } from "./community-ui";

export const metadata: Metadata = { title: "Community" };
const TABS = [["waiting", "Waiting"], ["hidden", "Hidden after reports"], ["rejected", "Rejected"], ["shown", "Shown"]] as const;
type Tab = (typeof TABS)[number][0];

export default function Page({ searchParams }: { searchParams: Promise<{ show?: string }> }) {
  return <Suspense fallback={<PageSkeleton rows={8} />}><Community searchParams={searchParams} /></Suspense>;
}

async function Community({ searchParams }: { searchParams: Promise<{ show?: string }> }) {
  await requireStaff(["super_admin", "admin"]);
  const { show } = await searchParams;
  const tab: Tab = (TABS.map((t) => t[0]) as string[]).includes(show ?? "") ? (show as Tab) : "waiting";
  const status = tab === "waiting" ? "pending" : tab;
  const supabase = await createClient();
  const [posts, comments, counts, settings, reports] = await Promise.all([
    supabase.from("community_posts").select("id, user_id, body, image_path, status, reason, likes_count, comments_count, created_at").eq("status", status).order("created_at", { ascending: false }).limit(100),
    supabase.from("community_comments").select("id, user_id, post_id, from_ai, body, status, reason, created_at").eq("status", status).order("created_at", { ascending: false }).limit(100),
    supabase.rpc("admin_community_counts"),
    supabase.from("app_settings").select("value").eq("key", "community").maybeSingle(),
    supabase.from("community_reports").select("kind, ref, reason").order("created_at", { ascending: false }).limit(1000),
  ]);
  if (posts.error) return <ErrorState message={posts.error.message} />;
  const ids = [...new Set([...(posts.data ?? []).map((p) => p.user_id), ...(comments.data ?? []).map((c) => c.user_id).filter(Boolean)])] as string[];
  const { data: people } = ids.length ? await supabase.from("profiles").select("id, full_name").in("id", ids) : { data: [] };
  const name = new Map((people ?? []).map((p) => [p.id, p.full_name || "Student"]));
  const rep = new Map<string, string[]>();
  for (const r of reports.data ?? []) rep.set(`${r.kind}:${r.ref}`, [...(rep.get(`${r.kind}:${r.ref}`) ?? []), r.reason ?? ""]);
  const items: ModItem[] = [
    ...(posts.data ?? []).map((p) => ({ kind: "post" as const, id: p.id, name: name.get(p.user_id) ?? "Student", user_id: p.user_id, body: p.body, image: p.image_path, status: p.status, reason: p.reason,
      at: p.created_at, extra: `${p.likes_count} likes · ${p.comments_count} comments`, reports: rep.get(`post:${p.id}`) ?? [] })),
    ...(comments.data ?? []).map((c) => ({ kind: "comment" as const, id: String(c.id), name: c.from_ai ? "SolutionTee AI" : name.get(c.user_id ?? "") ?? "Student", user_id: c.user_id, body: c.body, image: null,
      status: c.status, reason: c.reason, at: c.created_at, extra: "Comment", reports: rep.get(`comment:${c.id}`) ?? [] })),
  ].sort((a, b) => b.at.localeCompare(a.at));
  const ct = (counts.data ?? {}) as { pending?: number; hidden?: number; rejected_week?: number; posts_week?: number };
  const s = (settings.data?.value ?? {}) as Partial<CommunitySettings>;
  return (
    <>
      <PageHeader title="Community" description="Students post learning questions and tips in the app (Study → Community). The AI checks every post and comment before others see it; anything it cannot decide (and posts with pictures until the website is deployed) waits here. Three reports hide a post until you look." />
      <div className="mb-4 grid grid-cols-2 gap-3 md:grid-cols-4">
        {[["Waiting", ct.pending ?? 0], ["Hidden after reports", ct.hidden ?? 0], ["Rejected in 7 days", ct.rejected_week ?? 0], ["Posts in 7 days", ct.posts_week ?? 0]].map(([l, v]) => (
          <div key={l} className="rounded-2xl border bg-card p-4"><p className="text-xs text-muted-foreground">{l}</p><p className="text-2xl font-bold tabular-nums">{v}</p></div>
        ))}
      </div>
      <nav className="mb-4 flex flex-wrap gap-2" aria-label="Filter">
        {TABS.map(([k, l]) => (
          <Link key={k} href={k === "waiting" ? "/admin/community" : `/admin/community?show=${k}`}
            className={cn("rounded-full border px-3 py-1.5 text-sm font-bold", tab === k ? "border-primary bg-primary text-primary-foreground" : "hover:bg-muted")}>{l}</Link>
        ))}
      </nav>
      <ModList items={items} tab={tab} />
      <Panel title="Settings" className="mt-4">
        <CommunitySettingsForm initial={{ on: s.on !== false, ai_check: s.ai_check !== false, daily_posts: s.daily_posts ?? 10, daily_comments: s.daily_comments ?? 60, ai_answers_daily: s.ai_answers_daily ?? 5, report_hide: s.report_hide ?? 3 }} />
      </Panel>
    </>
  );
}
