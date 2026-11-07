"use client";
import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { Prohibit, Robot, ShieldCheck, ShieldWarning } from "@phosphor-icons/react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { inputCls } from "@/components/admin/row-form";
import { EmptyState, Pill, when } from "@/components/admin/ui";
import { decide } from "./actions";

export type SafetyRow = {
  user_id: string; full_name: string | null; email: string; banned_at: string | null;
  level: number | null; blocked_until: string | null; forever: boolean | null; reason: string | null;
  reported_at: string | null; decision: string | null; decided_at: string | null; strikes_30d: number;
  recent: { at: string; kind: string; text: string | null }[] | null;
};

function status(r: SafetyRow): { label: string; tone: "error" | "warn" | "ok" | "neutral" | "info" } {
  if (r.banned_at) return { label: "Account banned", tone: "error" };
  if (r.decision === "block_ai") return { label: "AI blocked by admin", tone: "error" };
  if (r.forever && !r.decision) return { label: "Waiting for your decision", tone: "warn" };
  if (r.blocked_until && new Date(r.blocked_until) > new Date()) return { label: `AI paused until ${when(r.blocked_until)}`, tone: "info" };
  if (r.decision === "lift") return { label: "Lifted", tone: "ok" };
  return { label: "Warnings only", tone: "neutral" };
}

export function SafetyBoard({ rows }: { rows: SafetyRow[] }) {
  const waiting = rows.filter((r) => r.forever && !r.decision && !r.banned_at);
  if (!rows.length) {
    return <EmptyState icon={<ShieldCheck />} title="All calm">No student has tried to break the AI tutor&apos;s rules in the last 30 days.</EmptyState>;
  }
  return (
    <div className="space-y-6">
      {waiting.length ? (
        <p className="rounded-2xl bg-warning-soft px-4 py-3 text-sm font-bold text-on-warning-soft">
          {waiting.length} {waiting.length === 1 ? "student is" : "students are"} waiting for your decision.
        </p>
      ) : null}
      <div className="grid gap-4">
        {rows.map((r) => <Row key={r.user_id} r={r} />)}
      </div>
    </div>
  );
}

function Row({ r }: { r: SafetyRow }) {
  const router = useRouter();
  const [pending, start] = useTransition();
  const [note, setNote] = useState("");
  const s = status(r);
  const run = (d: "lift" | "block_ai" | "ban") => start(async () => {
    const res = await decide(r.user_id, d, note);
    if (res.ok) { toast.success(res.message ?? "Done"); setNote(""); router.refresh(); } else toast.error(res.error);
  });
  return (
    <section className="rounded-2xl border border-border bg-card p-4">
      <div className="flex flex-wrap items-start justify-between gap-3">
        <div>
          <h3 className="font-bold">{r.full_name || "No name"}</h3>
          <p className="text-sm text-muted-foreground">{r.email}</p>
        </div>
        <div className="flex flex-wrap items-center gap-2">
          <Pill tone={s.tone}>{s.label}</Pill>
          <Pill tone="neutral">{r.strikes_30d} {r.strikes_30d === 1 ? "warning" : "warnings"} in 30 days</Pill>
          {r.level ? <Pill tone="gold">Level {r.level} of 3</Pill> : null}
        </div>
      </div>
      {r.reason ? <p className="mt-3 text-sm">{r.reason}</p> : null}
      {r.recent?.length ? (
        <ul className="mt-3 space-y-2">
          {r.recent.map((k, i) => (
            <li key={i} className="rounded-xl bg-sunken px-3 py-2 text-sm">
              <span className="mr-2 text-xs font-bold text-muted-foreground">{when(k.at)} · {k.kind === "data_leak" ? "Asked for private data" : "Tried to break the rules"}</span>
              <span className="break-words">“{k.text ?? ""}”</span>
            </li>
          ))}
        </ul>
      ) : null}
      {!r.banned_at ? (
        <div className="mt-4 flex flex-wrap items-center gap-2">
          <input className={`${inputCls} min-w-60 flex-1`} placeholder="Reason the student sees (needed to block or ban)" value={note} onChange={(e) => setNote(e.target.value)} />
          <Button variant="outline" disabled={pending} onClick={() => run("lift")}><ShieldCheck /> Lift</Button>
          <Button variant="outline" disabled={pending} onClick={() => run("block_ai")}><Robot /> Block AI</Button>
          <Button variant="destructive" disabled={pending} onClick={() => run("ban")}><Prohibit /> Ban account</Button>
        </div>
      ) : (
        <p className="mt-3 flex items-center gap-2 text-sm text-muted-foreground"><ShieldWarning size={16} /> Unban from Fraud &amp; bans.</p>
      )}
    </section>
  );
}
