"use client";
import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { Label } from "@/components/ui/label";
import { inputCls } from "@/components/admin/row-form";
import { EmptyState, Panel, Pill, when } from "@/components/admin/ui";
import { moderate, saveCommunitySettings } from "./actions";

export type ModItem = {
  kind: "post" | "comment"; id: string; name: string; user_id: string | null; body: string; image: string | null; status: string; reason: string | null;
  at: string; extra: string; reports: string[];
};
export type CommunitySettings = { on: boolean; ai_check: boolean; daily_posts: number; daily_comments: number; ai_answers_daily: number; report_hide: number };

function Row({ it }: { it: ModItem }) {
  const router = useRouter();
  const [pending, start] = useTransition();
  const [reason, setReason] = useState("");
  const act = (a: "show" | "reject" | "hide" | "delete") => {
    if (a === "delete" && !confirm("Delete this for good?")) return;
    start(async () => {
      const r = await moderate(it.kind, it.id, a, reason);
      if (!r.ok) return void toast.error(r.error);
      toast.success(r.message);
      router.refresh();
    });
  };
  return (
    <li className="grid gap-2 p-4">
      <div className="flex flex-wrap items-center gap-2 text-sm">
        <b>{it.name}</b>
        <span className="text-muted-foreground">{when(it.at)} · {it.extra}</span>
        <span className="ml-auto flex gap-2">
          {it.image ? <Pill tone="info">Has a picture</Pill> : null}
          {it.reports.length ? <Pill tone="warn">{it.reports.length} report{it.reports.length > 1 ? "s" : ""}</Pill> : null}
        </span>
      </div>
      <p className="whitespace-pre-wrap rounded-xl bg-muted px-3 py-2 text-sm">{it.body}</p>
      {it.reason ? <p className="text-xs text-muted-foreground">Reason: {it.reason}</p> : null}
      {it.reports.filter(Boolean).length ? <p className="text-xs text-muted-foreground">Reports: {it.reports.filter(Boolean).join(" · ")}</p> : null}
      <div className="flex flex-wrap items-end gap-2">
        {it.status !== "shown" ? <Button size="sm" disabled={pending} onClick={() => act("show")}>Show</Button> : null}
        {it.status === "shown" ? <Button size="sm" variant="outline" disabled={pending} onClick={() => act("hide")}>Hide</Button> : null}
        {it.status === "pending" ? (
          <>
            <input aria-label="Reason for the student" className={`${inputCls} max-w-xs`} placeholder="Reason for the student (optional)" value={reason} maxLength={280} onChange={(e) => setReason(e.target.value)} />
            <Button size="sm" variant="outline" disabled={pending} onClick={() => act("reject")}>Reject</Button>
          </>
        ) : null}
        <Button size="sm" variant="ghost" disabled={pending} onClick={() => act("delete")}>Delete</Button>
      </div>
    </li>
  );
}

export function ModList({ items, tab }: { items: ModItem[]; tab: string }) {
  return (
    <Panel title={`${items.length} item${items.length === 1 ? "" : "s"}`} bodyClassName="p-0">
      {items.length ? <ul className="divide-y">{items.map((it) => <Row key={`${it.kind}:${it.id}`} it={it} />)}</ul> : (
        <EmptyState title={tab === "waiting" ? "Nothing waiting" : "Nothing here"}>
          {tab === "waiting" ? "The AI checks posts in seconds. Anything it cannot decide shows here." : "Items show here when they need a look."}
        </EmptyState>
      )}
    </Panel>
  );
}

export function CommunitySettingsForm({ initial }: { initial: CommunitySettings }) {
  const router = useRouter();
  const [pending, start] = useTransition();
  const [f, setF] = useState(initial);
  const num = (k: keyof Omit<CommunitySettings, "on" | "ai_check">, label: string, max: number) => (
    <div><Label htmlFor={`cs-${k}`}>{label}</Label>
      <input id={`cs-${k}`} type="number" min={0} max={max} className={inputCls} value={f[k]} onChange={(e) => setF({ ...f, [k]: Number(e.target.value) })} /></div>
  );
  return (
    <div className="grid gap-4">
      <div className="flex flex-wrap gap-6">
        <label className="flex items-center gap-2 text-sm font-bold"><input type="checkbox" checked={f.on} onChange={(e) => setF({ ...f, on: e.target.checked })} /> Community on in the app</label>
        <label className="flex items-center gap-2 text-sm"><input type="checkbox" checked={f.ai_check} onChange={(e) => setF({ ...f, ai_check: e.target.checked })} /> AI checks every post and comment first (recommended)</label>
      </div>
      <div className="grid gap-3 md:grid-cols-4">
        {num("daily_posts", "Posts a student can make a day", 100)}
        {num("daily_comments", "Comments a day", 500)}
        {num("ai_answers_daily", "@solutiontee answers a day", 50)}
        {num("report_hide", "Reports that hide a post", 50)}
      </div>
      <div className="flex justify-end"><Button disabled={pending} onClick={() => start(async () => {
        const r = await saveCommunitySettings(f);
        if (!r.ok) return void toast.error(r.error);
        toast.success(r.message);
        router.refresh();
      })}>Save settings</Button></div>
    </div>
  );
}
