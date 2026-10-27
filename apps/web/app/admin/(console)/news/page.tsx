import { Suspense } from "react";
import Link from "next/link";
import type { Metadata } from "next";
import { Newspaper, Plus, PushPin } from "@phosphor-icons/react/dist/ssr";
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
  const editable = canEditContent(staff.role);
  return (
    <>
      <PageHeader title="News" description="Announcements on the student Home screen (for example JAMB registration dates or new questions)." actions={editable ? <Link href="/admin/news/new" className={buttonVariants()}><Plus size={18} weight="bold" /> Post news</Link> : null} />
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
