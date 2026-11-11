import { Suspense } from "react";
import Link from "next/link";
import type { Metadata } from "next";
import { ChatCircleText, Heart, Newspaper, Plus, PushPin } from "@phosphor-icons/react/dist/ssr";
import { requireStaff, canEditContent } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";
import { EmptyState, ErrorState, PageHeader, PageSkeleton, when } from "@/components/admin/ui";
import { NewsStatus } from "./news-status";
import { buttonVariants } from "@/components/ui/button";

export const metadata: Metadata = { title: "News" };

export default function Page() {
  return <Suspense fallback={<PageSkeleton rows={6} />}><NewsList /></Suspense>;
}

async function NewsList() {
  const staff = await requireStaff();
  const supabase = await createClient();
  const { data, error } = await supabase.from("news_posts").select("id, title, summary, category, status, publish_at, is_pinned").order("is_pinned", { ascending: false }).order("publish_at", { ascending: false }).limit(100);
  if (error) return <ErrorState message={error.message} />;
  const [meta, reported] = await Promise.all([
    supabase.rpc("news_meta", { p_ids: data.map((n) => n.id) }),
    supabase.from("news_comments").select("id", { count: "exact", head: true }).gt("reports", 0).is("reviewed_at", null),
  ]);
  const stats = new Map((meta.data ?? []).map((m) => [m.post_id, m]));
  const editable = canEditContent(staff.role);
  return (
    <>
      <PageHeader title="News" description="Announcements on the student Home screen (for example JAMB registration dates or new questions)." actions={<div className="flex gap-2">
        <Link href="/admin/news/comments" className={buttonVariants({ variant: "outline" })}><ChatCircleText size={18} /> Comments{reported.count ? <span className="ml-1 rounded-full bg-warning px-2 text-xs text-white">{reported.count}</span> : null}</Link>
        {editable ? <Link href="/admin/news/new" className={buttonVariants()}><Plus size={18} weight="bold" /> Post news</Link> : null}
      </div>} />
      {data.length ? (
        <div className="divide-y overflow-hidden rounded-2xl border bg-card">
          {data.map((n) => {
            return (
              <Link key={n.id} href={`/admin/news/${n.id}`} className="flex items-center gap-4 px-5 py-4 hover:bg-surface-alt">
                <span className="grid size-10 flex-none place-items-center rounded-xl bg-info-soft text-on-info-soft"><Newspaper size={20} /></span>
                <span className="min-w-0 grow">
                  <b className="flex items-center gap-1.5 truncate">{n.is_pinned ? <PushPin size={14} weight="fill" className="text-gold" /> : null}{n.title}</b>
                  <span className="block truncate text-sm text-muted-foreground">{n.summary || "No summary"}</span>
                </span>
                {stats.get(n.id) ? <span className="hidden items-center gap-3 text-xs text-muted-foreground md:flex"><span className="inline-flex items-center gap-1"><Heart size={14} />{stats.get(n.id)!.likes}</span><span className="inline-flex items-center gap-1"><ChatCircleText size={14} />{stats.get(n.id)!.comments}</span></span> : null}
                <span className="hidden text-xs text-muted-foreground sm:block">{when(n.publish_at)}</span>
                <NewsStatus status={n.status} publishAt={n.publish_at} />
              </Link>
            );
          })}
        </div>
      ) : (
        <div className="rounded-2xl border bg-card"><EmptyState icon={<Newspaper />} title="No news yet" action={editable ? <Link href="/admin/news/new" className={buttonVariants()}>Post the first news</Link> : null}>Posts show on the student Home screen.</EmptyState></div>
      )}
    </>
  );
}
