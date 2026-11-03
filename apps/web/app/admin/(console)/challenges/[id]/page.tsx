import { Suspense } from "react";
import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";
import { requireStaff } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";
import { ErrorState, PageHeader, PageSkeleton, Panel } from "@/components/admin/ui";
import { ChallengeForm, CloseButton, EntriesList, QuestionsPanel, type ChallengeRow, type EntryRow, type QRow, type Subject } from "../challenge-ui";
import { jambSubjects } from "../subjects";
import { CopyButton, LivePanel } from "../live-ui";
import type { LiveData } from "../actions";

export const metadata: Metadata = { title: "Challenge" };

/** A week after this one starts, as "YYYY-MM-DDTHH:mm" Lagos time (for the copy form). */
const nextWeek = (iso: string) => new Date(Date.parse(iso) + 7 * 86400_000 + 3600_000).toISOString().slice(0, 16);

const isLive = (c: { closed_at: string | null; starts_at: string; ends_at: string; published: boolean }) =>
  !c.closed_at && c.published && Date.parse(c.ends_at) > Date.now() && Date.parse(c.starts_at) <= Date.now();

export default function Page({ params }: { params: Promise<{ id: string }> }) {
  return <Suspense fallback={<PageSkeleton rows={10} />}><Edit params={params} /></Suspense>;
}

async function Edit({ params }: { params: Promise<{ id: string }> }) {
  const staff = await requireStaff(["super_admin", "admin", "editor"]);
  const { id } = await params;
  const supabaseS = await createClient();
  const subjects = await jambSubjects(supabaseS);
  if (id === "new") {
    return (
      <>
        <PageHeader title="New challenge" description="Save it first, then add the questions. Students only see it after you tick “Show to students”." />
        <Panel title="Challenge"><ChallengeForm subjects={subjects} /></Panel>
      </>
    );
  }
  if (!/^[0-9a-f-]{36}$/.test(id)) notFound();
  const supabase = await createClient();
  const [c, qs, entries, liveRes] = await Promise.all([
    supabase.from("challenges").select("*").eq("id", id).maybeSingle(),
    supabase.from("challenge_questions").select("id, position, body, options, answer, subject_id, difficulty").eq("challenge_id", id).order("position"),
    supabase.rpc("admin_challenge_entries", { p_id: id }),
    supabase.rpc("admin_challenge_live", { p_id: id }),
  ]);
  if (c.error) return <ErrorState message={c.error.message} />;
  if (!c.data) notFound();
  const ch = c.data as unknown as ChallengeRow;
  const rows = (entries.data ?? []) as unknown as EntryRow[];
  const live = isLive(ch);
  const canReview = staff.role === "super_admin" || staff.role === "admin";
  const ld = liveRes.data as unknown as LiveData | null;
  return (
    <>
      <PageHeader title={ch.title} description={ch.closed_at ? "Ended. Winners are saved; pay them in Money → Winners & payouts." : live ? "Live now." : "Not live yet."}
        actions={<div className="flex flex-wrap items-center gap-2"><Link href="/admin/challenges" className="text-sm text-muted-foreground hover:underline">All challenges</Link><CopyButton id={ch.id} defaultStart={nextWeek(ch.starts_at)} />{!ch.closed_at && ch.published ? <CloseButton id={ch.id} /> : null}</div>} />
      {ld && rows.length ? <Panel title="Live leaderboard and analysis" className="mb-4"><LivePanel id={ch.id} title={ch.title} initial={ld} /></Panel> : null}
      <div className="grid gap-4 xl:grid-cols-2">
        <Panel title="Challenge">{ch.closed_at ? <p className="text-sm text-muted-foreground">It has ended, so it cannot be changed.</p> : <ChallengeForm c={ch} subjects={subjects} />}</Panel>
        <Panel title={`Questions (${qs.data?.length ?? 0})`}><QuestionsPanel challengeId={ch.id} rows={(qs.data ?? []) as unknown as QRow[]} locked={rows.length > 0} subjects={subjects as Subject[]} mode={ch.mode} perLevel={ch.per_level ?? {}} subjectId={ch.subject_id} students={ld?.students_per_subject ?? {}} /></Panel>
      </div>
      <Panel title={`Entries (${rows.length})`} className="mt-4" bodyClassName="p-0"><EntriesList challengeId={ch.id} rows={rows} canReview={canReview} closed={!!ch.closed_at} /></Panel>
    </>
  );
}
