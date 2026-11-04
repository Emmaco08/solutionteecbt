"use client";
import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { Label } from "@/components/ui/label";
import { inputCls } from "@/components/admin/row-form";
import { Panel, Pill } from "@/components/admin/ui";
import { deleteLine, saveLine, setActive } from "./actions";

export type Line = { id: number; body: string; author: string | null; kind: "quote" | "tip" | "fact"; active: boolean; sort: number };
const KINDS = { quote: "Quote", tip: "Study tip", fact: "Fact" } as const;

function Editor({ line, onDone }: { line?: Line; onDone?: () => void }) {
  const router = useRouter();
  const [pending, start] = useTransition();
  const [f, setF] = useState({ body: line?.body ?? "", author: line?.author ?? "", kind: line?.kind ?? "quote", sort: String(line?.sort ?? 999) });
  const submit = () =>
    start(async () => {
      const r = await saveLine({ id: line?.id, ...f });
      if (!r.ok) return void toast.error(r.error);
      toast.success(r.message);
      if (!line) setF({ body: "", author: "", kind: "quote", sort: "999" });
      onDone?.();
      router.refresh();
    });
  return (
    <div className="grid gap-3 md:grid-cols-[1fr_200px_140px_100px_auto] md:items-end">
      <div><Label htmlFor={`b${line?.id ?? "new"}`}>Line</Label><textarea id={`b${line?.id ?? "new"}`} rows={2} className={inputCls} value={f.body} maxLength={280} onChange={(e) => setF({ ...f, body: e.target.value })} placeholder="Small steps every day beat one big push the night before the exam." /></div>
      <div><Label htmlFor={`a${line?.id ?? "new"}`}>Author (optional)</Label><input id={`a${line?.id ?? "new"}`} className={inputCls} value={f.author} maxLength={80} onChange={(e) => setF({ ...f, author: e.target.value })} /></div>
      <div><Label htmlFor={`k${line?.id ?? "new"}`}>Type</Label>
        <select id={`k${line?.id ?? "new"}`} className={inputCls} value={f.kind} onChange={(e) => setF({ ...f, kind: e.target.value as Line["kind"] })}>
          {Object.entries(KINDS).map(([k, v]) => <option key={k} value={k}>{v}</option>)}
        </select>
      </div>
      <div><Label htmlFor={`s${line?.id ?? "new"}`}>Order</Label><input id={`s${line?.id ?? "new"}`} type="number" min={0} className={inputCls} value={f.sort} onChange={(e) => setF({ ...f, sort: e.target.value })} /></div>
      <div className="flex gap-2"><Button onClick={submit} disabled={pending}>{line ? "Save" : "Add line"}</Button>{line ? <Button variant="ghost" onClick={onDone}>Cancel</Button> : null}</div>
    </div>
  );
}

export function LineList({ lines, todayId }: { lines: Line[]; todayId: number | null }) {
  const router = useRouter();
  const [editing, setEditing] = useState<number | null>(null);
  const [pending, start] = useTransition();
  const act = (fn: () => Promise<{ ok: boolean; error?: string; message?: string }>) =>
    start(async () => {
      const r = await fn();
      if (!r.ok) toast.error(r.error ?? "Could not save");
      else { toast.success(r.message ?? "Done"); router.refresh(); }
    });
  const shown = lines.filter((l) => l.active).length;
  return (
    <>
      <Panel title="Add a line" className="mb-4"><Editor /></Panel>
      <Panel title={`All lines (${shown} shown, ${lines.length - shown} paused)`} bodyClassName="p-0">
        <ul className="divide-y">
          {lines.map((l) => (
            <li key={l.id} className="p-4">
              {editing === l.id ? <Editor line={l} onDone={() => setEditing(null)} /> : (
                <div className="flex flex-wrap items-start gap-3">
                  <span className="w-10 pt-0.5 text-xs tabular-nums text-muted-foreground">#{l.sort}</span>
                  <div className={`min-w-0 flex-1 ${l.active ? "" : "opacity-50"}`}>
                    <p className="font-medium">{l.body}</p>
                    <p className="text-xs text-muted-foreground">{KINDS[l.kind]}{l.author ? ` · ${l.author}` : ""}</p>
                  </div>
                  <div className="flex flex-wrap items-center gap-2">
                    {l.id === todayId ? <Pill tone="ok">Today</Pill> : null}
                    {!l.active ? <Pill>Paused</Pill> : null}
                    <Button size="sm" variant="outline" onClick={() => setEditing(l.id)} disabled={pending}>Edit</Button>
                    <Button size="sm" variant="outline" onClick={() => act(() => setActive(l.id, !l.active))} disabled={pending}>{l.active ? "Pause" : "Show"}</Button>
                    <Button size="sm" variant="ghost" onClick={() => { if (confirm("Delete this line?")) act(() => deleteLine(l.id)); }} disabled={pending}>Delete</Button>
                  </div>
                </div>
              )}
            </li>
          ))}
        </ul>
      </Panel>
    </>
  );
}
