"use client";
import { useEffect, useState, useTransition } from "react";
import Link from "next/link";
import { usePathname, useRouter, useSearchParams } from "next/navigation";
import { CaretLeft, CaretRight, PencilSimple } from "@phosphor-icons/react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { Pill } from "@/components/admin/ui";
import { MathText } from "@/components/admin/math-text";
import { setStatus } from "./actions";

export type QRow = {
  id: string; body: string; year: number; number: number | null; status: "draft" | "review" | "published";
  difficulty: string | null; exam: string; subject: string; topic: string;
};
const TONE = { draft: "neutral", review: "warn", published: "ok" } as const;
const LABEL = { draft: "Draft", review: "Needs review", published: "Published" } as const;

export function QuestionTable({ rows, editable, savedId, page, pages, total }: {
  rows: QRow[]; editable: boolean; savedId: string; page: number; pages: number; total: number;
}) {
  const router = useRouter();
  const path = usePathname();
  const sp = useSearchParams();
  const [pickedAll, setPicked] = useState<Set<string>>(new Set());
  // Only rows on this page count as selected (filters or paging drop the rest).
  const picked = new Set([...pickedAll].filter((id) => rows.some((r) => r.id === id)));
  const [pending, start] = useTransition();

  useEffect(() => { if (savedId) toast.success("Question saved."); }, [savedId]);

  const toggle = (id: string) => setPicked((s) => { const n = new Set(s); if (n.has(id)) n.delete(id); else n.add(id); return n; });
  const all = rows.length > 0 && rows.every((r) => picked.has(r.id));
  const bulk = (status: QRow["status"]) => start(async () => {
    const res = await setStatus([...picked], status);
    if (!res.ok) toast.error(res.error);
    else { toast.success(`${res.data} question${res.data === 1 ? "" : "s"} set to ${LABEL[status].toLowerCase()}.`); router.refresh(); }
  });
  const goto = (p: number) => { const n = new URLSearchParams(sp); n.set("page", String(p)); router.push(`${path}?${n}`); };

  return (
    <div className="space-y-3">
      {editable && picked.size ? (
        <div className="flex flex-wrap items-center gap-2 rounded-xl bg-primary py-2 pl-4 pr-2 text-primary-foreground">
          <b className="mr-auto text-sm">{picked.size} selected</b>
          <Button size="sm" className="bg-gold text-navy hover:bg-gold/90" disabled={pending} onClick={() => bulk("published")}>Publish</Button>
          <Button size="sm" variant="outline" className="border-white/40 bg-transparent text-white hover:bg-white/10" disabled={pending} onClick={() => bulk("review")}>Mark for review</Button>
          <Button size="sm" variant="outline" className="border-white/40 bg-transparent text-white hover:bg-white/10" disabled={pending} onClick={() => bulk("draft")}>Back to draft</Button>
        </div>
      ) : null}
      <div className="overflow-hidden rounded-2xl border bg-card">
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead className="bg-surface-alt text-left text-[11px] uppercase tracking-[0.6px] text-subtle">
              <tr>
                {editable ? <th className="w-10 px-4 py-2.5"><input type="checkbox" aria-label="Select all on this page" checked={all} onChange={() => setPicked(all ? new Set() : new Set(rows.map((r) => r.id)))} /></th> : null}
                <th className="px-3 py-2.5">Question</th><th className="px-3 py-2.5">Exam</th><th className="px-3 py-2.5">Subject · topic</th>
                <th className="px-3 py-2.5">Level</th><th className="px-3 py-2.5">Status</th><th className="w-12" />
              </tr>
            </thead>
            <tbody className="divide-y">
              {rows.map((r) => (
                <tr key={r.id} className={r.id === savedId ? "bg-success-soft/50" : "hover:bg-surface-alt"}>
                  {editable ? <td className="px-4 py-3 align-top"><input type="checkbox" aria-label="Select question" checked={picked.has(r.id)} onChange={() => toggle(r.id)} /></td> : null}
                  <td className="min-w-[260px] max-w-[460px] px-3 py-3 font-medium">
                    <Link href={`/admin/questions/${r.id}`} className="line-clamp-2 hover:underline"><MathText text={r.body} /></Link>
                  </td>
                  <td className="whitespace-nowrap px-3 py-3"><b>{r.exam}</b> <span className="text-muted-foreground">{r.year}{r.number ? ` · Q${r.number}` : ""}</span></td>
                  <td className="px-3 py-3">{r.subject}<div className="text-xs text-muted-foreground">{r.topic || "No topic"}</div></td>
                  <td className="px-3 py-3 capitalize">{r.difficulty ?? "—"}</td>
                  <td className="px-3 py-3"><Pill tone={TONE[r.status]}>{LABEL[r.status]}</Pill></td>
                  <td className="px-2 py-3"><Link href={`/admin/questions/${r.id}`} aria-label="Edit question" className="grid size-9 place-items-center rounded-full hover:bg-muted"><PencilSimple size={18} /></Link></td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
        <div className="flex items-center justify-between gap-3 border-t px-4 py-2.5 text-sm">
          <span className="text-muted-foreground">{total.toLocaleString()} matching</span>
          <div className="flex items-center gap-1">
            <button className="grid size-9 place-items-center rounded-full hover:bg-muted disabled:opacity-40" disabled={page <= 1} onClick={() => goto(page - 1)} aria-label="Previous page"><CaretLeft size={18} /></button>
            <span>Page {page} of {pages}</span>
            <button className="grid size-9 place-items-center rounded-full hover:bg-muted disabled:opacity-40" disabled={page >= pages} onClick={() => goto(page + 1)} aria-label="Next page"><CaretRight size={18} /></button>
          </div>
        </div>
      </div>
    </div>
  );
}
