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

const PAGE = 50;

async function StudyList({ searchParams }: { searchParams: PageProps<"/admin/study">["searchParams"] }) {
  const staff = await requireStaff();
  const sp = await searchParams;
  const kind: StudyKind = (KINDS as readonly string[]).includes(String(sp.kind)) ? (sp.kind as StudyKind) : "video_solution";
  const q = typeof sp.q === "string" ? sp.q.trim().slice(0, 80) : "";
  const subject = Number(sp.subject) || null;
  const status = ["draft", "review", "published"].includes(String(sp.status)) ? String(sp.status) : "";
  const page = Math.max(1, Number(sp.page) || 1);
  const supabase = await createClient();

  let query = supabase.from("study_items").select("id, title, subtitle, year, is_free, status, files, updated_at, exam_bodies(code), subjects(name)", { count: "exact" })
    .eq("kind", kind).is("deleted_at", null);
  if (q) query = query.ilike("title", `%${q.replace(/[%_\\]/g, (c) => `\\${c}`)}%`);
  if (subject) query = query.eq("subject_id", subject);
  if (status) query = query.eq("status", status as "draft" | "review" | "published");
  const [list, subjects, ...counts] = await Promise.all([
    query.order("sort", { ascending: true }).order("updated_at", { ascending: false }).range((page - 1) * PAGE, page * PAGE - 1),
    supabase.from("subjects").select("id, name").order("sort"),
    ...KINDS.map((k) => supabase.from("study_items").select("id", { count: "exact", head: true }).eq("kind", k).is("deleted_at", null)),
  ]);
  if (list.error) return <ErrorState message={list.error.message} />;
  const n = (k: string) => counts[KINDS.indexOf(k as StudyKind)]?.count ?? 0;
  const total = list.count ?? 0;
  const pages = Math.max(1, Math.ceil(total / PAGE));
  const link = (over: Record<string, string | number | null>) => {
    const u = new URLSearchParams({ kind, ...(q ? { q } : {}), ...(subject ? { subject: String(subject) } : {}), ...(status ? { status } : {}), page: String(page) });
    for (const [k, v] of Object.entries(over)) {
      if (v === null || v === "") u.delete(k);
      else u.set(k, String(v));
    }
    return `/admin/study?${u}`;
  };
  const editable = canEditStudy(staff.role);
  const info = KIND_INFO[kind];
  const Icon = ICONS[kind];
  const add = editable ? <Link href={`/admin/study/new?kind=${kind}`} className={buttonVariants()}><Plus size={18} weight="bold" /> Add {info.one}</Link> : null;
  const sel = "h-10 rounded-xl border border-input bg-card px-3 text-sm";

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
      <form className="mb-4 flex flex-wrap gap-2" action="/admin/study">
        <input type="hidden" name="kind" value={kind} />
        <input name="q" defaultValue={q} placeholder={`Search ${info.label.toLowerCase()} by title`} aria-label="Search by title" className={`${sel} min-w-[220px] flex-1`} />
        <select name="subject" defaultValue={subject ?? ""} aria-label="Subject" className={sel}>
          <option value="">All subjects</option>{(subjects.data ?? []).map((x) => <option key={x.id} value={x.id}>{x.name}</option>)}
        </select>
        <select name="status" defaultValue={status} aria-label="Status" className={sel}>
          <option value="">Any status</option><option value="published">Published</option><option value="review">In review</option><option value="draft">Draft</option>
        </select>
        <button type="submit" className={buttonVariants({ variant: "outline" })}>Filter</button>
        {q || subject || status ? <Link href={`/admin/study?kind=${kind}`} className={buttonVariants({ variant: "ghost" })}>Clear</Link> : null}
      </form>
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
          <div className="flex items-center justify-between gap-3 px-5 py-3 text-sm">
            <span className="text-muted-foreground">{(page - 1) * PAGE + 1}–{Math.min(page * PAGE, total)} of {total.toLocaleString()}</span>
            <span className="flex gap-2">
              {page > 1 ? <Link href={link({ page: page - 1 })} className={buttonVariants({ variant: "outline", size: "sm" })}>Previous</Link> : null}
              <span className="self-center text-muted-foreground">Page {page} of {pages}</span>
              {page < pages ? <Link href={link({ page: page + 1 })} className={buttonVariants({ variant: "outline", size: "sm" })}>Next</Link> : null}
            </span>
          </div>
        </div>
      ) : (
        <div className="rounded-2xl border bg-card">
          {q || subject || status
            ? <EmptyState icon={<Books />} title="Nothing matches" action={<Link href={`/admin/study?kind=${kind}`} className={buttonVariants({ variant: "outline" })}>Clear the filters</Link>}>Try another word or subject.</EmptyState>
            : <EmptyState icon={<Books />} title={`No ${info.label.toLowerCase()} yet`} action={add}>{info.hint}</EmptyState>}
        </div>
      )}
    </>
  );
}
