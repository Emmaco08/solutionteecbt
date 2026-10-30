"use client";
import { useActionState, useState, useTransition } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { Plus, SpinnerGap, Trash } from "@phosphor-icons/react";
import { toast } from "sonner";
import { Button, buttonVariants } from "@/components/ui/button";
import { Label } from "@/components/ui/label";
import { Switch } from "@/components/ui/switch";
import { FileUpload } from "@/components/admin/file-upload";
import { ImageUpload } from "@/components/admin/image-upload";
import { MathText } from "@/components/admin/math-text";
import { inputCls } from "@/components/admin/row-form";
import { deleteStudy, saveStudy } from "./actions";
import { KIND_INFO, type StudyKind, type StudyState } from "./kinds";

type Opt = { id: number; name: string };
type TopicOpt = { id: number; name: string; subject_id: number };
type Chapter = { title: string; summary: string };
export type StudyItem = {
  id?: string; kind: StudyKind; title?: string; subtitle?: string | null; exam_id?: number | null; subject_id?: number | null; topic_id?: number | null;
  year?: number | null; question_id?: string | null; body?: string | null; data?: Record<string, unknown>; files?: Record<string, unknown>;
  is_free?: boolean; status?: string; sort?: number;
};

const area = "w-full rounded-xl border border-input bg-card px-3 py-2.5 text-sm outline-none focus-visible:ring-2 focus-visible:ring-ring";
/** [{title, text}] → "Title | text" lines for editing. */
const lines = (v: unknown, a: string, b: string) => (Array.isArray(v) ? v.map((x) => `${x?.[a] ?? ""}${x?.[b] != null && x?.[b] !== "" ? ` | ${x[b]}` : ""}`).join("\n") : "");

export function StudyForm({ item: it, exams, subjects, topics, canDelete }: { item: StudyItem; exams: (Opt & { code: string })[]; subjects: Opt[]; topics: TopicOpt[]; canDelete: boolean }) {
  const router = useRouter();
  const [state, action, saving] = useActionState<StudyState, FormData>(saveStudy, {});
  const [pending, start] = useTransition();
  const [subject, setSubject] = useState(it.subject_id ? String(it.subject_id) : "");
  const [body, setBody] = useState(it.body ?? "");
  const data = it.data ?? {};
  const files = it.files ?? {};
  const sizes = (files.sizes ?? {}) as Record<string, number>;
  const [chapters, setChapters] = useState<Chapter[]>(Array.isArray(data.chapters) ? (data.chapters as Chapter[]) : []);
  const k = it.kind;
  const info = KIND_INFO[k];
  const isVideo = k === "video_solution" || k === "lesson";
  const subjectTopics = topics.filter((t) => String(t.subject_id) === subject);

  return (
    <form action={action} className="grid items-start gap-4 lg:grid-cols-[minmax(0,1fr)_340px]">
      {it.id ? <input type="hidden" name="id" value={it.id} /> : null}
      <input type="hidden" name="kind" value={k} />
      <section className="space-y-4 rounded-2xl border bg-card p-5">
        <p className="rounded-xl bg-info-soft px-3 py-2 text-sm text-on-info-soft">{info.hint}</p>
        <div className="space-y-1.5"><Label htmlFor="title">Title</Label><input id="title" name="title" defaultValue={it.title ?? ""} required className={inputCls} /></div>
        <div className="space-y-1.5"><Label htmlFor="subtitle">Short line under the title</Label><input id="subtitle" name="subtitle" defaultValue={it.subtitle ?? ""} maxLength={200} className={inputCls} placeholder={isVideo ? "e.g. Mr Ade · Solved step by step" : ""} /></div>

        {isVideo ? (
          <div className="space-y-2">
            <Label>Video files</Label>
            <FileUpload name="f360" kind="video" label="360p (data saver, required)" defaultKey={files["360"] as string | undefined} defaultSize={sizes["360"]} />
            <FileUpload name="f720" kind="video" label="720p (HD, optional)" defaultKey={files["720"] as string | undefined} defaultSize={sizes["720"]} />
            {data.duration_s ? <input type="hidden" name="f360_duration_old" value={String(data.duration_s)} /> : null}
          </div>
        ) : null}
        {k === "video_solution" ? (
          <div className="space-y-1.5"><Label htmlFor="question_id">Question id (from the question bank)</Label>
            <input id="question_id" name="question_id" defaultValue={it.question_id ?? ""} className={inputCls} placeholder="Open the question and copy the id from the address bar" /></div>
        ) : <input type="hidden" name="question_id" value="" />}

        {k === "note" || k === "novel" ? (
          <div className="space-y-1.5">
            <Label htmlFor="body">{k === "note" ? "Note" : "Summary of the novel"}</Label>
            <textarea id="body" name="body" value={body} onChange={(e) => setBody(e.target.value)} rows={k === "note" ? 16 : 8} className={area} />
            {k === "note" && body ? (
              <div className="rounded-xl border bg-surface-alt p-4 text-sm leading-6"><b className="mb-1 block text-xs uppercase text-muted-foreground">Preview</b>
                {body.split(/\n{2,}/).map((p, i) => <p key={i} className="mb-2 whitespace-pre-line"><MathText text={p} /></p>)}</div>
            ) : null}
          </div>
        ) : <input type="hidden" name="body" value="" />}

        {k === "novel" ? (
          <>
            <div className="space-y-1.5"><Label htmlFor="author">Author</Label><input id="author" name="author" defaultValue={(data.author as string) ?? ""} className={inputCls} /></div>
            <div className="space-y-2">
              <Label>Chapters</Label>
              <input type="hidden" name="chapters" value={JSON.stringify(chapters.filter((c) => c.title.trim()))} />
              {chapters.map((c, i) => (
                <div key={i} className="space-y-2 rounded-xl border p-3">
                  <div className="flex gap-2">
                    <input aria-label={`Chapter ${i + 1} title`} value={c.title} placeholder={`Chapter ${i + 1}`} className={inputCls}
                      onChange={(e) => setChapters(chapters.map((x, j) => (j === i ? { ...x, title: e.target.value } : x)))} />
                    <Button type="button" variant="ghost" size="sm" aria-label={`Remove chapter ${i + 1}`} onClick={() => setChapters(chapters.filter((_, j) => j !== i))}><Trash size={16} /></Button>
                  </div>
                  <textarea aria-label={`Chapter ${i + 1} summary`} value={c.summary} rows={3} className={area} placeholder="What happens in this chapter"
                    onChange={(e) => setChapters(chapters.map((x, j) => (j === i ? { ...x, summary: e.target.value } : x)))} />
                </div>
              ))}
              <Button type="button" variant="outline" size="sm" onClick={() => setChapters([...chapters, { title: "", summary: "" }])}><Plus size={16} /> Add chapter</Button>
            </div>
            <div className="space-y-1.5"><Label htmlFor="themes">Themes (one per line: Theme | explanation)</Label>
              <textarea id="themes" name="themes" defaultValue={lines(data.themes, "title", "text")} rows={5} className={area} placeholder="Love and sacrifice | How Lakunle and Baroka …" /></div>
            <div className="space-y-1.5"><Label htmlFor="characters">Characters (one per line: Name | who they are)</Label>
              <textarea id="characters" name="characters" defaultValue={lines(data.characters, "name", "text")} rows={5} className={area} placeholder="Sidi | The village belle …" /></div>
          </>
        ) : null}

        {k === "doc" ? (
          <>
            <div className="space-y-2"><Label>PDF file</Label><FileUpload name="pdf" kind="pdf" label="PDF" defaultKey={files.pdf as string | undefined} defaultSize={sizes.pdf} /></div>
            <div className="space-y-1.5"><Label htmlFor="pages">Pages (filled in from the PDF; change it if wrong)</Label><input id="pages" name="pages" type="number" min={1} defaultValue={(data.pages as number) ?? ""} className={inputCls} /></div>
            <div className="space-y-1.5"><Label htmlFor="topics">Contents (one per line: Topic | page)</Label>
              <textarea id="topics" name="topics" defaultValue={lines(data.topics, "title", "page")} rows={6} className={area} placeholder="Mathematics | 12" /></div>
          </>
        ) : null}
      </section>

      <aside className="space-y-4 rounded-2xl border bg-card p-5">
        <div className="space-y-1.5"><Label htmlFor="exam_id">Exam</Label>
          <select id="exam_id" name="exam_id" defaultValue={it.exam_id ?? ""} className={inputCls}>
            <option value="">Any exam</option>{exams.map((e) => <option key={e.id} value={e.id}>{e.code}</option>)}
          </select></div>
        <div className="space-y-1.5"><Label htmlFor="subject_id">Subject</Label>
          <select id="subject_id" name="subject_id" value={subject} onChange={(e) => setSubject(e.target.value)} className={inputCls}>
            <option value="">No subject</option>{subjects.map((s) => <option key={s.id} value={s.id}>{s.name}</option>)}
          </select></div>
        <div className="space-y-1.5"><Label htmlFor="topic_id">Topic</Label>
          <select id="topic_id" name="topic_id" defaultValue={it.topic_id ?? ""} key={subject} className={inputCls} disabled={!subjectTopics.length}>
            <option value="">{subjectTopics.length ? "No topic" : "Pick a subject with topics"}</option>{subjectTopics.map((t) => <option key={t.id} value={t.id}>{t.name}</option>)}
          </select></div>
        {k !== "novel" ? (
          <div className="space-y-1.5"><Label htmlFor="year">Year</Label><input id="year" name="year" type="number" min={1978} max={2100} defaultValue={it.year ?? ""} className={inputCls} /></div>
        ) : <input type="hidden" name="year" value="" />}
        {k === "novel" || k === "doc" || k === "lesson" ? (
          <div className="space-y-1.5"><Label>Cover picture</Label><ImageUpload name="cover" kind="cover" defaultKey={files.cover as string | undefined} /></div>
        ) : <input type="hidden" name="cover" value="" />}
        <div className="space-y-1.5"><Label htmlFor="sort">Order (small numbers first)</Label><input id="sort" name="sort" type="number" defaultValue={it.sort ?? 0} className={inputCls} /></div>
        <div className="space-y-1.5"><Label htmlFor="status">Status</Label>
          <select id="status" name="status" defaultValue={it.status ?? "draft"} className={inputCls}>
            <option value="draft">Draft</option><option value="review">In review</option><option value="published">Published</option>
          </select></div>
        <label className="flex items-center justify-between gap-3 text-sm"><span>Free for everyone<span className="block text-xs text-muted-foreground">Off = Premium only. Free users also need this section on in Free vs Premium.</span></span><Switch name="is_free" defaultChecked={it.is_free} /></label>
        {state.error ? <p role="alert" className="rounded-xl bg-error-soft px-3 py-2 text-sm text-on-error-soft">{state.error}</p> : null}
        <div className="flex gap-2">
          <Button type="submit" disabled={saving} className="grow">{saving ? <SpinnerGap size={16} className="animate-spin" /> : null} Save</Button>
          <Link href={`/admin/study?kind=${k}`} className={buttonVariants({ variant: "outline" })}>Cancel</Link>
        </div>
        {it.id && canDelete ? (
          <Button type="button" variant="ghost" className="w-full text-error" disabled={pending}
            onClick={() => confirm(`Delete this ${info.one}?`) && start(async () => { const r = await deleteStudy(it.id!); if (r.ok) { toast.success("Deleted."); router.push(`/admin/study?kind=${k}`); } else toast.error(r.error); })}>
            <Trash size={16} /> Delete {info.one}
          </Button>
        ) : null}
      </aside>
    </form>
  );
}
