import { Suspense } from "react";
import type { Metadata } from "next";
import Link from "next/link";
import { requireStaff } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";
import { hasR2 } from "@/lib/env";
import { presignGet } from "@/lib/r2";
import { ErrorState, PageHeader, PageSkeleton, Panel } from "@/components/admin/ui";
import { cn } from "@/lib/utils";
import { BanList, CommunitySettingsForm, ModList, ProfileList, type BanItem, type ModItem, type CommunitySettings, type ProfileItem } from "./community-ui";

export const metadata: Metadata = { title: "Community" };
const TABS = [["waiting", "Waiting"], ["profiles", "@handles and bios"], ["hidden", "Hidden after reports"], ["rejected", "Rejected"], ["shown", "Shown"]] as const;
type Tab = (typeof TABS)[number][0];

export default function Page({ searchParams }: { searchParams: Promise<{ show?: string }> }) {
  return <Suspense fallback={<PageSkeleton rows={8} />}><Community searchParams={searchParams} /></Suspense>;
}

async function Community({ searchParams }: { searchParams: Promise<{ show?: string }> }) {
  await requireStaff(["super_admin", "admin"]);
  const { show } = await searchParams;
  const tab: Tab = (TABS.map((t) => t[0]) as string[]).includes(show ?? "") ? (show as Tab) : "waiting";
  const status = tab === "waiting" || tab === "profiles" ? "pending" : tab;
  const supabase = await createClient();
  const [posts, comments, counts, settings, reports, waitingProfiles, bans] = await Promise.all([
    supabase.from("community_posts").select("id, user_id, body, image_path, images, quote_of, status, reason, likes_count, comments_count, reposts_count, created_at").eq("status", status).order("created_at", { ascending: false }).limit(100),
    supabase.from("community_comments").select("id, user_id, post_id, parent_id, from_ai, body, status, reason, created_at").eq("status", status).order("created_at", { ascending: false }).limit(100),
    supabase.rpc("admin_community_counts"),
    supabase.from("app_settings").select("value").eq("key", "community").maybeSingle(),
    supabase.from("community_reports").select("kind, ref, reason").order("created_at", { ascending: false }).limit(1000),
    supabase.from("community_profiles").select("user_id, handle, pending_handle, bio, pending_bio, pending_at").not("pending_at", "is", null).order("pending_at").limit(100),
    supabase.from("community_bans").select("user_id, until, reason").gt("until", new Date().toISOString()).order("until").limit(100),
  ]);
  if (posts.error) return <ErrorState message={posts.error.message} />;
  const quoteIds = [...new Set((posts.data ?? []).map((p) => p.quote_of).filter(Boolean))] as string[];
  const { data: quoted } = quoteIds.length ? await supabase.from("community_posts").select("id, body").in("id", quoteIds) : { data: [] };
  const quote = new Map((quoted ?? []).map((q) => [q.id, q.body]));
  const ids = [...new Set([...(posts.data ?? []).map((p) => p.user_id), ...(comments.data ?? []).map((c) => c.user_id).filter(Boolean),
    ...(waitingProfiles.data ?? []).map((w) => w.user_id), ...(bans.data ?? []).map((b) => b.user_id)])] as string[];
  const [{ data: people }, { data: handles }] = ids.length
    ? await Promise.all([supabase.from("profiles").select("id, full_name").in("id", ids), supabase.from("community_profiles").select("user_id, handle").in("user_id", ids)])
    : [{ data: [] }, { data: [] }];
  const handle = new Map((handles ?? []).map((h) => [h.user_id, h.handle]));
  const name = new Map((people ?? []).map((p) => [p.id, `${p.full_name || "Student"}${handle.get(p.id) ? ` · @${handle.get(p.id)}` : ""}`]));
  // Staff see the pictures of what they review (private R2, short signed links).
  const sign = async (keys: string[]) => (hasR2() ? Promise.all(keys.slice(0, 4).map((k) => presignGet(k).catch(() => ""))) : []);
  const rep = new Map<string, string[]>();
  for (const r of reports.data ?? []) rep.set(`${r.kind}:${r.ref}`, [...(rep.get(`${r.kind}:${r.ref}`) ?? []), r.reason ?? ""]);
  const items: ModItem[] = [
    ...(await Promise.all((tab === "profiles" ? [] : posts.data ?? []).map(async (p) => {
      const keys = ((p.images as string[] | null)?.length ? (p.images as string[]) : p.image_path ? [p.image_path] : []);
      return { kind: "post" as const, id: p.id, name: name.get(p.user_id) ?? "Student", user_id: p.user_id, body: p.body, image: keys[0] ?? null, pictures: await sign(keys),
        quote: p.quote_of ? (quote.get(p.quote_of) ?? "(deleted post)") : null, status: p.status, reason: p.reason, at: p.created_at,
        extra: `${p.likes_count} likes · ${p.comments_count} replies · ${p.reposts_count} reposts`, reports: rep.get(`post:${p.id}`) ?? [] };
    }))),
    ...(tab === "profiles" ? [] : comments.data ?? []).map((c) => ({ kind: "comment" as const, id: String(c.id), name: c.from_ai ? "SolutionTee AI" : name.get(c.user_id ?? "") ?? "Student", user_id: c.user_id, body: c.body, image: null,
      pictures: [], quote: null, status: c.status, reason: c.reason, at: c.created_at, extra: c.parent_id ? "Reply in a thread" : "Reply", reports: rep.get(`comment:${c.id}`) ?? [] })),
  ].sort((a, b) => b.at.localeCompare(a.at));
  const ct = (counts.data ?? {}) as { pending?: number; hidden?: number; rejected_week?: number; posts_week?: number; profiles_pending?: number; quotes_week?: number; reposts_week?: number };
  const { data: strikes } = (bans.data ?? []).length
    ? await supabase.from("community_strikes").select("user_id").in("user_id", (bans.data ?? []).map((b) => b.user_id))
    : { data: [] };
  const banItems: BanItem[] = (bans.data ?? []).map((b) => ({ user_id: b.user_id, name: name.get(b.user_id) ?? "Student", until: b.until, reason: b.reason,
    strikes: (strikes ?? []).filter((x) => x.user_id === b.user_id).length }));
  const profiles: ProfileItem[] = (waitingProfiles.data ?? []).map((w) => ({ user_id: w.user_id, name: (name.get(w.user_id) ?? "Student").split(" · ")[0], handle: w.handle,
    pending_handle: w.pending_handle, bio: w.bio, pending_bio: w.pending_bio, at: w.pending_at as string }));
  const s = (settings.data?.value ?? {}) as Partial<CommunitySettings>;
  return (
    <>
      <PageHeader title="Community" actions={<Link href="/admin/community/feed" className="rounded-full border px-3 py-1.5 text-sm font-bold hover:bg-muted">Open the feed</Link>} description="Students post, reply, repost and quote in the app (Study → Community). The AI checks every post, reply, @handle and bio before others see it: greetings and friendly school chat are fine; adult content, politics, betting, sports gossip, bullying, contacts, scams and exam expo are not. Anything it cannot decide waits here. Three reports hide a post until you look." />
      <div className="mb-4 grid grid-cols-2 gap-3 md:grid-cols-4">
        {[["Waiting", ct.pending ?? 0], ["@handles and bios waiting", ct.profiles_pending ?? 0], ["Hidden after reports", ct.hidden ?? 0], ["Rejected in 7 days", ct.rejected_week ?? 0],
          ["Posts in 7 days", ct.posts_week ?? 0], ["Quotes in 7 days", ct.quotes_week ?? 0], ["Reposts in 7 days", ct.reposts_week ?? 0]].map(([l, v]) => (
          <div key={l} className="rounded-2xl border bg-card p-4"><p className="text-xs text-muted-foreground">{l}</p><p className="text-2xl font-bold tabular-nums">{v}</p></div>
        ))}
      </div>
      <nav className="mb-4 flex flex-wrap gap-2" aria-label="Filter">
        {TABS.map(([k, l]) => (
          <Link key={k} href={k === "waiting" ? "/admin/community" : `/admin/community?show=${k}`}
            className={cn("rounded-full border px-3 py-1.5 text-sm font-bold", tab === k ? "border-primary bg-primary text-primary-foreground" : "hover:bg-muted")}>{l}</Link>
        ))}
      </nav>
      {tab === "profiles" ? <ProfileList items={profiles} /> : <ModList items={items} tab={tab} />}
      <Panel title="Posting paused" className="mt-4">
        <BanList items={banItems} />
      </Panel>
      <Panel title="Settings" className="mt-4">
        <CommunitySettingsForm initial={{ on: s.on !== false, ai_check: s.ai_check !== false, daily_posts: s.daily_posts ?? 10, daily_comments: s.daily_comments ?? 60,
          ai_answers_daily: s.ai_answers_daily ?? 5, report_hide: s.report_hide ?? 3, moderation: s.moderation === "before" ? "before" : "after",
          strikes_limit: s.strikes_limit ?? 3, strike_days: s.strike_days ?? 30, ban_hours: s.ban_hours ?? 24, ai_auto: s.ai_auto !== false,
          ai_auto_daily: s.ai_auto_daily ?? 15, ad_every: s.ad_every ?? 5 }} />
      </Panel>
    </>
  );
}
