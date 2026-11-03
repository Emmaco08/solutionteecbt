"use client";
import { useMemo, useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import {
  CheckCircle, Clock, Copy, DeviceMobile, DeviceMobileSlash, Flag, Gavel, Lock, LockOpen, MagnifyingGlass, Prohibit, ShieldCheck,
  ShieldWarning, UserCircleMinus, Users, Warning,
} from "@phosphor-icons/react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { inputCls } from "@/components/admin/row-form";
import { Pill, when } from "@/components/admin/ui";
import { allowOnPhone, ban, banPhone, decideBanAppeal, decidePhoneAppeal, unbanPhone } from "./actions";

type Account = {
  user_id: string; name: string | null; email: string; first_seen: string; last_seen: string; banned: boolean; ban_reason: string | null;
  allowed: boolean; attempts: number; premium: boolean;
};
export type Phone = { hash: string; device: string; kind: string; last: string; banned: boolean; flags: string[]; accounts: Account[] };
export type BannedPhone = { hash: string; device: string; reason: string; banned_at: string; by: string | null; accounts: number };
export type Banned = { user_id: string; name: string | null; email: string; reason: string | null; banned_at: string };
export type Appeal = { id: string; user_id: string; name: string | null; reason: string; ban_reason: string | null; status: string; note: string | null; created_at: string };
export type PhoneAppeal = { id: string; hash: string; device: string; email: string; reason: string; status: string; note: string | null; created_at: string; ban_reason: string | null };
export type Flagged = { user_id: string; name: string | null; email: string; last: string; flags: string[] };
export type Event = { at: string; kind: string; detail: string | null; device: string | null; hash: string | null; user_id: string | null; name: string | null };
export type Stats = { shared_phones: number; blocked_second: number; banned_accounts: number; banned_phones: number; clones_7d: number; appeals_waiting: number; phones_seen: number };
export type FraudData = { stats: Stats; shared_phones: Phone[]; banned_phones: BannedPhone[]; banned: Banned[]; appeals: Appeal[]; phone_appeals: PhoneAppeal[]; flagged: Flagged[]; events: Event[] };

const FLAG: Record<string, string> = {
  "clone:second-user": "Dual app / second profile", "clone:data-dir": "Running inside a cloner", "clone:package": "Changed app", emulator: "Emulator",
};
const flagLabel = (f: string) => FLAG[f] ?? (f.startsWith("cloner-installed:") ? `Cloner installed (${f.split(":")[1]})` : f);
const EVENT: Record<string, { label: string; icon: React.ReactNode; tone: string }> = {
  clone: { label: "Opened a dual / cloned copy", icon: <Copy size={16} />, tone: "text-warning" },
  second_account: { label: "Second account on a phone", icon: <Users size={16} />, tone: "text-warning" },
  banned_phone_login: { label: "Signed in on a banned phone (banned)", icon: <Prohibit size={16} />, tone: "text-error" },
  banned_phone_signup: { label: "Tried to sign up on a banned phone", icon: <Prohibit size={16} />, tone: "text-error" },
  phone_banned: { label: "Phone banned", icon: <Lock size={16} />, tone: "text-error" },
  phone_unbanned: { label: "Phone ban lifted", icon: <LockOpen size={16} />, tone: "text-success" },
  phone_appeal: { label: "Appeal from a banned phone", icon: <Gavel size={16} />, tone: "text-info" },
};

function initials(name: string | null, email: string) {
  const s = (name || email).trim();
  const p = s.split(/\s+/);
  return ((p[0]?.[0] ?? "?") + (p[1]?.[0] ?? "")).toUpperCase();
}

/** High: banned accounts, cloned copies or 3+ accounts. Medium: 2 accounts. */
function risk(p: Phone): "high" | "medium" {
  const clone = p.flags.some((f) => f.startsWith("clone:"));
  return clone || p.accounts.length >= 3 || p.accounts.some((a) => a.banned) ? "high" : "medium";
}

function useRun() {
  const router = useRouter();
  const [pending, start] = useTransition();
  const run = (p: () => Promise<{ ok: boolean; message?: string; error?: string }>) => start(async () => {
    const r = await p(); if (r.ok) { toast.success(r.message ?? "Done"); router.refresh(); } else toast.error(r.error);
  });
  return { pending, run };
}

function Stat({ icon, label, value, tone, onClick }: { icon: React.ReactNode; label: string; value: number; tone: string; onClick?: () => void }) {
  return (
    <button type="button" onClick={onClick} className="flex items-center gap-3 rounded-2xl border bg-card p-3 text-left transition hover:border-secondary/60 hover:shadow-sm">
      <span className={`grid size-10 shrink-0 place-items-center rounded-xl ${tone}`}>{icon}</span>
      <span><span className="block text-xl font-bold tabular-nums leading-tight">{value}</span><span className="text-xs text-muted-foreground">{label}</span></span>
    </button>
  );
}

const TABS = [
  ["attention", "Needs attention"], ["phones", "Shared phones"], ["banned-phones", "Banned phones"], ["banned", "Banned accounts"], ["flagged", "Flagged phones"], ["activity", "Activity"],
] as const;
type Tab = (typeof TABS)[number][0];

/** Fraud & bans board (D-079): totals, tabs, search, phone cards with risk, and the actions. */
export function FraudBoard({ d }: { d: FraudData }) {
  const s = d.stats;
  const waitingAppeals = d.appeals.filter((a) => a.status === "pending").length + d.phone_appeals.filter((a) => a.status === "pending").length;
  const [tab, setTab] = useState<Tab>(waitingAppeals ? "attention" : "phones");
  const [q, setQ] = useState("");
  const m = (...xs: (string | null | undefined)[]) => !q.trim() || xs.some((x) => (x ?? "").toLowerCase().includes(q.trim().toLowerCase()));
  const phones = useMemo(() => {
    // The phone-wide id and the Android ID of the same phone list the same accounts: show each group once.
    const seen = new Set<string>();
    return d.shared_phones.filter((p) => {
      const key = p.accounts.map((a) => a.user_id).sort().join(",");
      if (seen.has(key)) return false;
      seen.add(key);
      return true;
    });
  }, [d.shared_phones]);
  const shown = {
    phones: phones.filter((p) => m(p.device, ...p.accounts.flatMap((a) => [a.name, a.email]))),
    bannedPhones: d.banned_phones.filter((p) => m(p.device, p.reason)),
    banned: d.banned.filter((b) => m(b.name, b.email, b.reason)),
    flagged: d.flagged.filter((f) => m(f.name, f.email, ...f.flags)),
    events: d.events.filter((e) => m(e.name, e.device, e.detail, e.kind)),
    appeals: d.appeals.filter((a) => m(a.name, a.reason)),
    phoneAppeals: d.phone_appeals.filter((a) => m(a.email, a.device, a.reason)),
  };
  const count: Record<Tab, number> = {
    attention: waitingAppeals, phones: phones.length, "banned-phones": d.banned_phones.length, banned: d.banned.length, flagged: d.flagged.length, activity: d.events.length,
  };
  return (
    <div className="space-y-4">
      <div className="grid grid-cols-2 gap-2 sm:grid-cols-3 xl:grid-cols-6">
        <Stat icon={<Gavel size={20} />} label="Appeals waiting" value={s.appeals_waiting} tone={s.appeals_waiting ? "bg-warning-soft text-on-warning-soft" : "bg-sunken text-muted-foreground"} onClick={() => setTab("attention")} />
        <Stat icon={<Users size={20} />} label="Phones with 2+ accounts" value={phones.length} tone="bg-info-soft text-on-info-soft" onClick={() => setTab("phones")} />
        <Stat icon={<UserCircleMinus size={20} />} label="Second accounts blocked" value={s.blocked_second} tone="bg-gold-soft text-on-gold-soft" onClick={() => setTab("phones")} />
        <Stat icon={<Copy size={20} />} label="Clone attempts (7 days)" value={s.clones_7d} tone={s.clones_7d ? "bg-warning-soft text-on-warning-soft" : "bg-sunken text-muted-foreground"} onClick={() => setTab("flagged")} />
        <Stat icon={<DeviceMobileSlash size={20} />} label="Banned phones" value={d.banned_phones.length} tone="bg-error-soft text-on-error-soft" onClick={() => setTab("banned-phones")} />
        <Stat icon={<Prohibit size={20} />} label="Banned accounts" value={s.banned_accounts} tone="bg-error-soft text-on-error-soft" onClick={() => setTab("banned")} />
      </div>

      <div className="flex flex-wrap items-center gap-2">
        <div className="flex flex-wrap gap-1 rounded-xl bg-surface-alt p-1">
          {TABS.map(([k, l]) => (
            <button key={k} type="button" onClick={() => setTab(k)}
              className={`rounded-lg px-3 py-1.5 text-sm font-semibold transition ${tab === k ? "bg-card shadow-sm" : "text-muted-foreground hover:text-foreground"}`}>
              {l}{count[k] ? <span className={`ml-1.5 rounded-full px-1.5 text-xs tabular-nums ${k === "attention" ? "bg-warning text-white" : "bg-sunken"}`}>{count[k]}</span> : null}
            </button>
          ))}
        </div>
        <label className="relative ml-auto w-full sm:w-72">
          <MagnifyingGlass size={16} className="absolute left-3 top-1/2 -translate-y-1/2 text-muted-foreground" />
          <input value={q} onChange={(e) => setQ(e.target.value)} placeholder="Search name, email or phone id" className={`${inputCls} pl-9`} />
        </label>
      </div>

      {tab === "attention" ? <Attention appeals={shown.appeals} phoneAppeals={shown.phoneAppeals} /> : null}
      {tab === "phones" ? (shown.phones.length ? <div className="grid gap-3 lg:grid-cols-2">{shown.phones.map((p) => <PhoneCard key={p.hash} p={p} />)}</div>
        : <Empty icon={<ShieldCheck size={28} />} title="No shared phones" text="Every phone has one account." />) : null}
      {tab === "banned-phones" ? <BannedPhones rows={shown.bannedPhones} /> : null}
      {tab === "banned" ? <BannedAccounts rows={shown.banned} /> : null}
      {tab === "flagged" ? <FlaggedList rows={shown.flagged} /> : null}
      {tab === "activity" ? <Activity rows={shown.events} /> : null}
      <p className="text-xs text-muted-foreground">How phones are recognised: a phone-wide id (the same for dual apps and app cloners) and the Android ID, both hashed. A factory reset makes a phone look new. {s.phones_seen} phone ids seen so far.</p>
    </div>
  );
}

function Empty({ icon, title, text }: { icon: React.ReactNode; title: string; text: string }) {
  return (
    <div className="grid place-items-center gap-1 rounded-2xl border border-dashed p-10 text-center">
      <span className="text-success">{icon}</span><b>{title}</b><span className="text-sm text-muted-foreground">{text}</span>
    </div>
  );
}

function PhoneCard({ p }: { p: Phone }) {
  const { pending, run } = useRun();
  const r = risk(p);
  const clones = p.flags.filter((f) => f.startsWith("clone:"));
  return (
    <div className={`rounded-2xl border bg-card ${r === "high" ? "border-error/40" : ""}`}>
      <div className="flex flex-wrap items-center gap-2 border-b p-3">
        <span className={`grid size-9 place-items-center rounded-xl ${p.banned ? "bg-error-soft text-on-error-soft" : "bg-info-soft text-on-info-soft"}`}>
          {p.banned ? <DeviceMobileSlash size={18} /> : <DeviceMobile size={18} />}</span>
        <div className="min-w-0">
          <div className="text-sm font-bold">Phone <span className="font-mono">{p.device}…</span></div>
          <div className="text-xs text-muted-foreground">{p.accounts.length} accounts · last seen {when(p.last)} · {p.kind === "drm" ? "phone-wide id" : "Android ID"}</div>
        </div>
        <span className="ml-auto flex flex-wrap gap-1">
          {p.banned ? <Pill tone="error">Phone banned</Pill> : <Pill tone={r === "high" ? "error" : "warn"}>{r === "high" ? "High risk" : "Check"}</Pill>}
        </span>
      </div>
      {clones.length || p.flags.length ? (
        <div className="flex flex-wrap gap-1 px-3 pt-3">{p.flags.map((f) => (
          <span key={f} className={`inline-flex items-center gap-1 rounded-full px-2 py-0.5 text-xs ${f.startsWith("clone:") ? "bg-error-soft text-on-error-soft" : "bg-sunken text-muted-foreground"}`}><Flag size={12} />{flagLabel(f)}</span>
        ))}</div>
      ) : null}
      <ul className="divide-y">{p.accounts.map((a, i) => (
        <li key={a.user_id} className="flex flex-wrap items-center gap-3 p-3 text-sm">
          <span className={`grid size-9 shrink-0 place-items-center rounded-full text-xs font-bold ${i === 0 ? "bg-secondary text-white" : "bg-sunken"}`}>{initials(a.name, a.email)}</span>
          <div className="min-w-0 flex-1">
            <div className="flex flex-wrap items-center gap-1.5"><b className="truncate">{a.name ?? "No name"}</b>
              {i === 0 ? <Pill tone="info">First on phone</Pill> : a.allowed ? <Pill tone="ok">Allowed</Pill> : <Pill tone="warn">Blocked</Pill>}
              {a.banned ? <Pill tone="error">Banned</Pill> : null}{a.premium ? <Pill tone="gold">Premium</Pill> : null}</div>
            <div className="truncate text-xs text-muted-foreground">{a.email} · since {when(a.first_seen)} · {a.attempts} tests</div>
          </div>
          <div className="flex gap-1">
            {i > 0 && !a.banned ? <Button size="sm" variant="outline" disabled={pending} onClick={() => run(() => allowOnPhone(p.hash, a.user_id, !a.allowed))}>{a.allowed ? "Block" : "Allow (family)"}</Button> : null}
            {!a.banned ? <Button size="sm" variant="ghost" disabled={pending} title="Ban this account only" onClick={() => {
              const reason = prompt(`Ban ${a.name ?? a.email}? Reason (they see it):`, "More than one account to get rewards");
              if (reason) run(() => ban(a.user_id, true, reason, false));
            }}><Prohibit size={16} /></Button> : null}
          </div>
        </li>
      ))}</ul>
      <div className="flex flex-wrap justify-end gap-2 border-t p-3">
        {p.banned ? (
          <Button size="sm" variant="outline" disabled={pending} onClick={() => { if (confirm("Lift the ban on this phone? Accounts banned only because of it open again.")) run(() => unbanPhone(p.hash)); }}><LockOpen size={16} /> Lift phone ban</Button>
        ) : (
          <Button size="sm" variant="destructive" disabled={pending} onClick={() => {
            const reason = prompt("Ban this phone and every account on it? Nobody can create or use an account on it; they can only appeal.\n\nReason (they see it):", "Many fake accounts on one phone");
            if (reason) run(() => banPhone(p.hash, reason));
          }}><Lock size={16} /> Ban phone</Button>
        )}
      </div>
    </div>
  );
}

function Attention({ appeals, phoneAppeals }: { appeals: Appeal[]; phoneAppeals: PhoneAppeal[] }) {
  const { pending, run } = useRun();
  const waiting = [...phoneAppeals.filter((a) => a.status === "pending"), ...appeals.filter((a) => a.status === "pending")];
  const done = [...phoneAppeals.filter((a) => a.status !== "pending"), ...appeals.filter((a) => a.status !== "pending")].slice(0, 20);
  if (!waiting.length && !done.length) return <Empty icon={<CheckCircle size={28} />} title="Nothing to do" text="No appeals right now." />;
  const card = (a: Appeal | PhoneAppeal) => {
    const phone = "email" in a;
    return (
      <div key={a.id} className="space-y-2 rounded-2xl border bg-card p-4 text-sm">
        <div className="flex flex-wrap items-center gap-2">
          <span className={`grid size-8 place-items-center rounded-lg ${phone ? "bg-error-soft text-on-error-soft" : "bg-warning-soft text-on-warning-soft"}`}>{phone ? <DeviceMobileSlash size={16} /> : <Gavel size={16} />}</span>
          <b>{phone ? `Banned phone ${(a as PhoneAppeal).device}…` : (a as Appeal).name ?? "No name"}</b>
          {phone ? <span className="text-xs text-muted-foreground">{(a as PhoneAppeal).email}</span> : null}
          <Pill tone={a.status === "pending" ? "warn" : a.status === "accepted" ? "ok" : "neutral"}>{a.status === "pending" ? "Waiting" : a.status === "accepted" ? "Accepted" : "Rejected"}</Pill>
          <span className="ml-auto flex items-center gap-1 text-xs text-muted-foreground"><Clock size={12} />{when(a.created_at)}</span>
        </div>
        <p className="text-xs text-muted-foreground">Banned for: {a.ban_reason ?? "—"}</p>
        <p className="rounded-xl bg-surface-alt p-3">{a.reason}</p>
        {a.status === "pending" ? (
          <form className="flex flex-wrap gap-2" action={(f) => {
            const accept = f.get("accept") === "1"; const note = String(f.get("note") ?? "");
            run(() => (phone ? decidePhoneAppeal(a.id, accept, note) : decideBanAppeal(a.id, accept, note)));
          }}>
            <input name="note" maxLength={500} placeholder={phone ? "Note (emailed to them)" : "Note (sent to them in the app)"} className={`${inputCls} min-w-48 flex-1`} />
            <Button type="submit" name="accept" value="1" size="sm" disabled={pending}><CheckCircle size={16} /> Accept and unban</Button>
            <Button type="submit" name="accept" value="0" size="sm" variant="outline" disabled={pending}>Reject</Button>
          </form>
        ) : a.note ? <p className="text-xs text-muted-foreground">Note: {a.note}</p> : null}
      </div>
    );
  };
  return (
    <div className="space-y-3">
      {waiting.length ? <div className="grid gap-3 lg:grid-cols-2">{waiting.map(card)}</div> : <Empty icon={<CheckCircle size={28} />} title="No appeals waiting" text="Decided appeals are below." />}
      {done.length ? <><h3 className="pt-2 text-sm font-bold text-muted-foreground">Decided</h3><div className="grid gap-3 lg:grid-cols-2">{done.map(card)}</div></> : null}
    </div>
  );
}

function BannedPhones({ rows }: { rows: BannedPhone[] }) {
  const { pending, run } = useRun();
  if (!rows.length) return <Empty icon={<ShieldCheck size={28} />} title="No banned phones" text="Ban a phone from its card in Shared phones." />;
  return (
    <div className="grid gap-3 lg:grid-cols-2">{rows.map((p) => (
      <div key={p.hash} className="flex flex-wrap items-center gap-3 rounded-2xl border bg-card p-4 text-sm">
        <span className="grid size-10 place-items-center rounded-xl bg-error-soft text-on-error-soft"><DeviceMobileSlash size={20} /></span>
        <div className="min-w-0 flex-1">
          <b>Phone <span className="font-mono">{p.device}…</span></b>
          <div className="text-xs text-muted-foreground">{p.reason}</div>
          <div className="text-xs text-muted-foreground">{when(p.banned_at)}{p.by ? ` · by ${p.by}` : ""} · {p.accounts} {p.accounts === 1 ? "account" : "accounts"}</div>
        </div>
        <Button size="sm" variant="outline" disabled={pending} onClick={() => { if (confirm("Lift this phone ban?")) run(() => unbanPhone(p.hash)); }}><LockOpen size={16} /> Lift</Button>
      </div>
    ))}</div>
  );
}

function BannedAccounts({ rows }: { rows: Banned[] }) {
  const { pending, run } = useRun();
  if (!rows.length) return <Empty icon={<ShieldCheck size={28} />} title="Nobody is banned" text="Ban students from Users or from a phone card." />;
  return (
    <div className="overflow-x-auto rounded-2xl border bg-card">
      <table className="w-full text-sm">
        <thead className="bg-surface-alt text-left text-xs text-muted-foreground"><tr><th className="px-4 py-2">Student</th><th>Reason</th><th>Banned</th><th className="pr-4" /></tr></thead>
        <tbody>{rows.map((b) => (
          <tr key={b.user_id} className="border-t">
            <td className="px-4 py-2"><div className="flex items-center gap-2"><span className="grid size-8 place-items-center rounded-full bg-error-soft text-xs font-bold text-on-error-soft">{initials(b.name, b.email)}</span>
              <div><b>{b.name ?? "No name"}</b><div className="text-xs text-muted-foreground">{b.email}</div></div></div></td>
            <td className="max-w-72 text-xs text-muted-foreground">{b.reason}</td>
            <td className="whitespace-nowrap text-xs text-muted-foreground">{when(b.banned_at)}</td>
            <td className="pr-4 text-right"><Button size="sm" variant="outline" disabled={pending} onClick={() => { if (confirm("Remove this ban?")) run(() => ban(b.user_id, false, "", false)); }}>Remove ban</Button></td>
          </tr>
        ))}</tbody>
      </table>
    </div>
  );
}

function FlaggedList({ rows }: { rows: Flagged[] }) {
  if (!rows.length) return <Empty icon={<ShieldCheck size={28} />} title="No flagged phones" text="Dual apps, cloners and emulators show here." />;
  return (
    <div className="grid gap-3 lg:grid-cols-2">{rows.map((f) => (
      <div key={f.user_id} className="space-y-2 rounded-2xl border bg-card p-4 text-sm">
        <div className="flex items-center gap-2"><span className="grid size-8 place-items-center rounded-full bg-warning-soft text-xs font-bold text-on-warning-soft">{initials(f.name, f.email)}</span>
          <div className="min-w-0"><b>{f.name ?? "No name"}</b><div className="truncate text-xs text-muted-foreground">{f.email} · {when(f.last)}</div></div></div>
        <div className="flex flex-wrap gap-1">{f.flags.map((x) => (
          <span key={x} className={`inline-flex items-center gap-1 rounded-full px-2 py-0.5 text-xs ${x.startsWith("clone:") ? "bg-error-soft text-on-error-soft" : "bg-sunken text-muted-foreground"}`}>
            {x.startsWith("clone:") ? <Warning size={12} /> : <Flag size={12} />}{flagLabel(x)}</span>
        ))}</div>
      </div>
    ))}</div>
  );
}

function Activity({ rows }: { rows: Event[] }) {
  if (!rows.length) return <Empty icon={<ShieldCheck size={28} />} title="No activity yet" text="Second accounts, clones and bans show here." />;
  return (
    <ol className="relative space-y-0 rounded-2xl border bg-card p-2">{rows.map((e, i) => {
      const k = EVENT[e.kind] ?? { label: e.kind, icon: <ShieldWarning size={16} />, tone: "text-muted-foreground" };
      return (
        <li key={i} className="flex gap-3 rounded-xl p-2 text-sm hover:bg-surface-alt">
          <span className={`mt-0.5 grid size-7 shrink-0 place-items-center rounded-full bg-surface-alt ${k.tone}`}>{k.icon}</span>
          <div className="min-w-0 flex-1">
            <div><b>{k.label}</b>{e.name ? <span className="text-muted-foreground"> · {e.name}</span> : null}</div>
            <div className="truncate text-xs text-muted-foreground">{[e.device ? `phone ${e.device}…` : null, e.kind === "clone" ? e.detail?.split(", ").map(flagLabel).join(", ") : e.detail].filter(Boolean).join(" · ")}</div>
          </div>
          <span className="whitespace-nowrap text-xs text-muted-foreground">{when(e.at)}</span>
        </li>
      );
    })}</ol>
  );
}
