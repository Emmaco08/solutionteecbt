import { Suspense } from "react";
import type { Metadata } from "next";
import Link from "next/link";
import { Trophy } from "@phosphor-icons/react/dist/ssr";
import { requireStaff } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";
import { EmptyState, ErrorState, PageHeader, PageSkeleton, Panel, Pill, when, type Tone } from "@/components/admin/ui";
import { buttonVariants } from "@/components/ui/button";

export const metadata: Metadata = { title: "Challenges & events" };

export default function Page() {
  return <Suspense fallback={<PageSkeleton rows={8} />}><List /></Suspense>;
}

/** Now, read once per request (server component). */
const nowMs = () => Date.now();
const KIND: Record<string, string> = { cash: "Cash prize", event: "Event", practice: "Practice" };

async function List() {
  await requireStaff(["super_admin", "admin", "editor"]);
  const supabase = await createClient();
  const { data, error } = await supabase.from("challenges")
    .select("id, title, kind, starts_at, ends_at, closed_at, published, prizes, challenge_questions(count), challenge_entries(count)")
    .order("starts_at", { ascending: false }).limit(100);
  if (error) return <ErrorState message={error.message} />;
  const now = nowMs();
  const status = (c: { starts_at: string; ends_at: string; closed_at: string | null; published: boolean }): [string, Tone] =>
    !c.published ? ["Draft", "neutral"] : c.closed_at || Date.parse(c.ends_at) <= now ? ["Ended", "neutral"] : Date.parse(c.starts_at) <= now ? ["Live", "ok"] : ["Coming up", "info"];
  return (
    <>
      <PageHeader title="Challenges & events" description="Weekly cash challenges, events and practice rounds. One try per student, one question at a time, marked and timed on the server. Winners are saved and told the moment it closes. Entry is free (paid entry stays off until a lawyer confirms it, D-028)."
        actions={<Link href="/admin/challenges/new" className={buttonVariants()}>New challenge</Link>} />
      <Panel title="All challenges" bodyClassName="p-0">
        {data?.length ? (
          <ul className="divide-y">
            {data.map((c) => {
              const [label, tone] = status(c);
              const qs = (c.challenge_questions as unknown as { count: number }[])[0]?.count ?? 0;
              const entries = (c.challenge_entries as unknown as { count: number }[])[0]?.count ?? 0;
              return (
                <li key={c.id}>
                  <Link href={`/admin/challenges/${c.id}`} className="flex flex-wrap items-center gap-3 px-5 py-3 text-sm hover:bg-surface-alt">
                    <div className="min-w-0 flex-1">
                      <div className="flex flex-wrap items-center gap-2"><b>{c.title}</b><Pill tone={tone}>{label}</Pill><Pill>{KIND[c.kind]}</Pill></div>
                      <span className="text-muted-foreground">{when(c.starts_at)} → {when(c.ends_at)} · {qs} question{qs === 1 ? "" : "s"} · {entries} played
                        {c.prizes?.length ? ` · 1st ₦${c.prizes[0].toLocaleString("en-NG")}` : ""}</span>
                    </div>
                  </Link>
                </li>
              );
            })}
          </ul>
        ) : <EmptyState icon={<Trophy />} title="No challenges yet" action={<Link href="/admin/challenges/new" className={buttonVariants()}>New challenge</Link>}>Create your first weekly challenge. Students see it on Home and in Test → Challenges.</EmptyState>}
      </Panel>
    </>
  );
}
