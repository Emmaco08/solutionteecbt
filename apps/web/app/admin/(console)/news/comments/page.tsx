import { Suspense } from "react";
import Link from "next/link";
import type { Metadata } from "next";
import { ChatCircleText } from "@phosphor-icons/react/dist/ssr";
import { requireStaff, canEditContent } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";
import { EmptyState, ErrorState, PageHeader, PageSkeleton } from "@/components/admin/ui";
import { cn } from "@/lib/utils";
import { CommentRow } from "./comment-row";

export const metadata: Metadata = { title: "News comments" };

const TABS = [["reported", "Reported"], ["hidden", "Hidden"], ["all", "All"]] as const;

export default function Page({ searchParams }: PageProps<"/admin/news/comments">) {
  return <Suspense fallback={<PageSkeleton rows={8} />}><Comments searchParams={searchParams} /></Suspense>;
}

async function Comments({ searchParams }: { searchParams: PageProps<"/admin/news/comments">["searchParams"] }) {
  const staff = await requireStaff();
  const sp = await searchParams;
  const tab = TABS.some(([k]) => k === sp.tab) ? String(sp.tab) : "reported";
  const supabase = await createClient();
  const { data, error } = await supabase.rpc("admin_news_comments", { p_filter: tab });
  if (error) return <ErrorState message={error.message} />;
  return (
    <>
      <PageHeader title="News comments" description="Students' comments on news posts. Three reports hide a comment until you look at it. Show it again to keep it, hide it, or delete it. Links are never allowed." />
      <div className="mb-4 flex gap-2">
        {TABS.map(([k, label]) => (
          <Link key={k} href={`/admin/news/comments?tab=${k}`} className={cn("h-10 rounded-xl border bg-card px-4 text-sm font-bold leading-10", k === tab && "border-blue bg-info-soft")}>{label}</Link>
        ))}
        <Link href="/admin/news" className="ml-auto h-10 px-2 text-sm leading-10 text-muted-foreground hover:text-foreground">Back to News</Link>
      </div>
      {data?.length ? (
        <ul className="divide-y overflow-hidden rounded-2xl border bg-card">
          {data.map((c) => <CommentRow key={c.id} c={c} editable={canEditContent(staff.role)} />)}
        </ul>
      ) : (
        <div className="rounded-2xl border bg-card"><EmptyState icon={<ChatCircleText />} title={tab === "reported" ? "Nothing reported" : "No comments here"}>{tab === "reported" ? "Reported comments show here first." : "Comments show here as students write them."}</EmptyState></div>
      )}
    </>
  );
}
