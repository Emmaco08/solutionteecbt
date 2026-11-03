"use client";
import { useTransition } from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { inputCls } from "@/components/admin/row-form";
import { Pill, when } from "@/components/admin/ui";
import { allowOnPhone, ban, decideBanAppeal } from "./actions";

type Account = { user_id: string; name: string | null; email: string; first_seen: string; banned: boolean; allowed: boolean };
export type Phone = { device: string; hash: string; accounts: Account[] };
export type Banned = { user_id: string; name: string | null; email: string; reason: string | null; banned_at: string };
export type Appeal = { id: string; user_id: string; name: string | null; reason: string; ban_reason: string | null; status: string; note: string | null; created_at: string };

function useRun() {
  const router = useRouter();
  const [pending, start] = useTransition();
  const run = (p: () => Promise<{ ok: boolean; message?: string; error?: string }>) => start(async () => {
    const r = await p(); if (r.ok) { toast.success(r.message ?? "Done"); router.refresh(); } else toast.error(r.error);
  });
  return { pending, run };
}

export function PhonesList({ rows }: { rows: Phone[] }) {
  const { pending, run } = useRun();
  return (
    <ul className="divide-y">{rows.map((p) => (
      <li key={p.hash} className="space-y-2 p-4 text-sm">
        <p className="text-xs text-muted-foreground">Phone <span className="font-mono">{p.device}…</span> · {p.accounts.length} accounts. The first one owns the phone.</p>
        <ul className="space-y-1.5">{p.accounts.map((a, i) => (
          <li key={a.user_id} className="flex flex-wrap items-center gap-2">
            <b>{a.name ?? "No name"}</b><span className="text-xs text-muted-foreground">{a.email} · since {when(a.first_seen)}</span>
            {i === 0 ? <Pill tone="info">First</Pill> : a.allowed ? <Pill tone="ok">Allowed</Pill> : <Pill tone="warn">Blocked on this phone</Pill>}
            {a.banned ? <Pill tone="error">Banned</Pill> : null}
            <span className="ml-auto flex gap-1">
              {i > 0 ? <Button size="sm" variant="outline" disabled={pending} onClick={() => run(() => allowOnPhone(p.hash, a.user_id, !a.allowed))}>{a.allowed ? "Stop allowing" : "Allow (family)"}</Button> : null}
              {!a.banned ? <Button size="sm" variant="ghost" disabled={pending} onClick={() => {
                const reason = prompt("Reason for the ban (the student sees it):", "More than one account to get rewards");
                if (reason) run(() => ban(a.user_id, true, reason, true));
              }}>Ban all on this phone</Button> : null}
            </span>
          </li>
        ))}</ul>
      </li>
    ))}</ul>
  );
}

export function BannedList({ rows }: { rows: Banned[] }) {
  const { pending, run } = useRun();
  return (
    <ul className="divide-y">{rows.map((b) => (
      <li key={b.user_id} className="flex flex-wrap items-center gap-2 p-4 text-sm">
        <div><b>{b.name ?? "No name"}</b> <span className="text-xs text-muted-foreground">{b.email}</span>
          <span className="block text-xs text-muted-foreground">{b.reason} · {when(b.banned_at)}</span></div>
        <Button className="ml-auto" size="sm" variant="outline" disabled={pending} onClick={() => { if (confirm("Remove this ban?")) run(() => ban(b.user_id, false, "", false)); }}>Remove ban</Button>
      </li>
    ))}</ul>
  );
}

export function AppealsList({ rows }: { rows: Appeal[] }) {
  const { pending, run } = useRun();
  return (
    <ul className="divide-y">{rows.map((a) => (
      <li key={a.id} className="space-y-2 p-4 text-sm">
        <div className="flex flex-wrap items-center gap-2"><b>{a.name ?? "No name"}</b>
          <Pill tone={a.status === "pending" ? "warn" : a.status === "accepted" ? "ok" : "neutral"}>{a.status === "pending" ? "Waiting" : a.status === "accepted" ? "Accepted" : "Rejected"}</Pill>
          <span className="ml-auto text-xs text-muted-foreground">{when(a.created_at)}</span></div>
        <p className="text-xs text-muted-foreground">Banned for: {a.ban_reason}</p>
        <p className="rounded-lg bg-surface-alt p-2">{a.reason}</p>
        {a.status === "pending" ? (
          <form className="flex flex-wrap gap-2" action={(f) => {
            const accept = f.get("accept") === "1"; const note = String(f.get("note") ?? "");
            run(() => decideBanAppeal(a.id, accept, note));
          }}>
            <input name="note" maxLength={500} placeholder="Note to the student (optional)" className={`${inputCls} flex-1`} />
            <Button type="submit" name="accept" value="1" size="sm" disabled={pending}>Accept and unban</Button>
            <Button type="submit" name="accept" value="0" size="sm" variant="outline" disabled={pending}>Reject</Button>
          </form>
        ) : a.note ? <p className="text-xs text-muted-foreground">Note: {a.note}</p> : null}
      </li>
    ))}</ul>
  );
}
