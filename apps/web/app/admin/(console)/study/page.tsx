import { Suspense } from "react";
import Link from "next/link";
import type { Metadata } from "next";
import { BookOpenText, Books, FilePdf, Notebook, Plus, VideoCamera } from "@phosphor-icons/react/dist/ssr";
import { requireStaff, canEditStudy } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";
import { EmptyState, ErrorState, PageHeader, PageSkeleton, Pill, when } from "@/components/admin/ui";
import { buttonVariants } from "@/components/ui/button";
import { cn } from "@/lib/utils";
import { KINDS, KIND_INFO, type StudyKind } from "./kinds";

export const metadata: Metadata = { title: "Study content" };

const ICONS = { video_solution: VideoCamera, lesson: VideoCamera, note: Notebook, novel: BookOpenText, doc: FilePdf } as const;

export default function Page({ searchParams }: PageProps<"/admin/study">) {
  return <Suspense fallback={<PageSkeleton rows={6} />}><StudyList searchParams={searchParams} /></Suspense>;
}

async function StudyList({ searchParams }: { searchParams: PageProps<"/admin/study">["searchParams"] }) {
  const staff = await requireStaff();
  const sp = await searchParams;
  const kind: StudyKind = (KINDS as readonly string[]).includes(String(sp.kind)) ? (sp.kind as StudyKind) : "video_solution";
  const supabase = await createClient();
  const [list, counts] = await Promise.all([
    supabase.from("study_items").select("id, title, subtitle, year, is_free, status, files, updated_at, exam_bodies(code), subjects(name)")
      .eq("kind", kind).is("deleted_at", null).order("sort", { ascending: true }).order("updated_at", { ascending: false }).limit(300),
    supabase.from("study_items").select("kind").is("deleted_at", null).limit(5000),
  ]);
  if (list.error) return <ErrorState message={list.error.message} />;
  const n = (k: string) => (counts.data ?? []).filter((r) => r.kind === k).length;
  const editable = canEditStudy(staff.role);
  const info = KIND_INFO[kind];
  const Icon = ICONS[kind];
  const add = editable ? <Link href={`/admin/study/new?kind=${kind}`} className={buttonVariants()}><Plus size={18} weight="bold" /> Add {info.one}</Link> : null;

  return (
    <>
      <PageHeader title="Study content" description="Videos, notes, novels and documents in the student Study tab. Free or Premium is set on each item and checked on the server." actions={add} />
      <div className="mb-4 flex flex-wrap gap-2" role="tablist">
        {KINDS.map((k) => (
          <Link key={k} href={`/admin/study?kind=${k}`} role="tab" aria-selected={k === kind}
            className={cn("inline-flex h-9 items-center rounded-full border px-3.5 text-sm font-bold", k === kind ? "border-primary bg-primary text-primary-foreground" : "bg-card hover:bg-surface-alt")}>
            {KIND_INFO[k].label} <span className="ml-1.5 rounded-full bg-black/10 px-1.5 py-px text-xs">{n(k)}</span>
          </Link>
        ))}
      </div>
      {sp.saved ? <p role="status" className="mb-4 rounded-xl bg-success-soft px-4 py-2.5 text-sm text-on-success-soft">Saved.</p> : null}
      {list.data.length ? (
        <div className="divide-y overflow-hidden rounded-2xl border bg-card">
          {list.data.map((r) => {
            const files = (r.files ?? {}) as Record<string, unknown>;
            const meta = [(r.exam_bodies as unknown as { code: string } | null)?.code, (r.subjects as unknown as { name: string } | null)?.name, r.year].filter(Boolean).join(" · ");
            const missing = (kind === "video_solution" || kind === "lesson") && !files["360"] ? "No video yet" : kind === "doc" && !files.pdf ? "No PDF yet" : null;
            return (
              <Link key={r.id} href={`/admin/study/${r.id}`} className="flex items-center gap-4 px-5 py-4 hover:bg-surface-alt">
                <span className="grid size-10 flex-none place-items-center rounded-xl bg-info-soft text-on-info-soft"><Icon size={20} /></span>
                <span className="min-w-0 grow">
                  <b className="block truncate">{r.title}</b>
                  <span className="block truncate text-sm text-muted-foreground">{[meta, r.subtitle].filter(Boolean).join(" — ") || "No subject"}</span>
                </span>
                {missing ? <Pill tone="warn">{missing}</Pill> : null}
                <span className="hidden text-xs text-muted-foreground sm:block">{when(r.updated_at)}</span>
                {r.is_free ? <Pill tone="info">Free</Pill> : <Pill tone="gold">Premium</Pill>}
                {r.status === "published" ? <Pill tone="ok">Published</Pill> : r.status === "review" ? <Pill tone="info">In review</Pill> : <Pill>Draft</Pill>}
              </Link>
            );
          })}
        </div>
      ) : (
        <div className="rounded-2xl border bg-card">
          <EmptyState icon={<Books />} title={`No ${info.label.toLowerCase()} yet`} action={add}>{info.hint}</EmptyState>
        </div>
      )}
    </>
  );
}
