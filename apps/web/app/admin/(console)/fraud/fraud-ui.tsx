"use client";
import { useMemo, useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import {
  CheckCircle, Clock, Copy, DeviceMobile, DeviceMobileSlash, Envelope, Flag, Gavel, Info, Lock, LockOpen, MagnifyingGlass, Prohibit, ShieldCheck,
  ShieldWarning, UserCheck, Users, Warning,
} from "@phosphor-icons/react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { inputCls } from "@/components/admin/row-form";
import { Pill, when } from "@/components/admin/ui";
import { allowOnPhone, ban, banPhone, decideBanAppeal, decidePhoneAppeal, unbanPhone } from "./actions";

/* Data from public.admin_fraud (D-128): each phone once, with all its ids. */
type Account = {
  user_id: string; name: string | null; email: string; first_seen: string; last_seen: string; banned: boolean; ban_reason: string | null;
  allowed: boolean; blocked: boolean; attempts: number; premium: boolean;
};
export type Phone = { hash: string; device: string; hashes: string[]; last: string; banned: boolean; flags: string[]; accounts: Account[] };
export type BannedPhone = { hash: string; device: string; reason: string; banned_at: string; by: string | null; accounts: number };
export type Banned = { user_id: string; name: string | null; email: string; reason: string | null; banned_at: string };
export type Appeal = { id: string; user_id: string; name: string | null; reason: string; ban_reason: string | null; status: string; note: string | null; created_at: string };
export type PhoneAppeal = { id: string; hash: string; device: string; email: string; reason: string; status: string; note: string | null; created_at: string; ban_reason: string | null };
export type Flagged = { user_id: string; name: string | null; email: string; last: string; flags: string[] };
export type Event = { at: string; kind: string; detail: string | null; device: string | null; hash: string | null; user_id: string | null; name: string | null };
export type Stats = { blocked_second: number; banned_accounts: number; banned_phones: number; clones_7d: number; appeals_waiting: number; phones_seen: number };
export type FraudData = { stats: Stats; shared_phones: Phone[]; banned_phones: BannedPhone[]; banned: Banned[]; appeals: Appeal[]; phone_appeals: PhoneAppeal[]; flagged: Flagged[]; events: Event[] };

const FLAG: Record<string, string> = {
  "clone:second-user": "Dual app / second profile", "clone:data-dir": "Running inside a cloner", "clone:package": "Changed app", emulator: "Emulator",
  vm: "Windows in a virtual machine",
};
const flagLabel = (f: string) => FLAG[f] ?? (f.startsWith("cloner-installed:") ? `Cloner installed (${f.split(":")[1]})` : f);
const EVENT: Record<string, { label: string; icon: React.ReactNode; tone: string }> = {
  clone: { label: "Opened a dual / cloned copy of the app", icon: <Copy size={16} />, tone: "text-warning" },
  second_account: { label: "Second account paused on a phone", icon: <Users size={16} />, tone: "text-warning" },
  banned_phone_login: { label: "Signed in on a banned phone (account banned)", icon: <Prohibit size={16} />, tone: "text-error" },
  banned_phone_signup: { label: "Tried to sign up on a banned phone", icon: <Prohibit size={16} />, tone: "text-error" },
  phone_banned: { label: "Phone banned", icon: <Lock size={16} />, tone: "text-error" },
  phone_unbanned: { label: "Phone ban lifted", icon: <LockOpen size={16} />, tone: "text-success" },
  phone_appeal: { label: "Appeal from a banned phone", icon: <Gavel size={16} />, tone: "text-info" },
};
const BAN_PRESETS = ["More than one account to collect rewards", "Cheating in a challenge", "Sharing or selling our content", "Harassing other students", "Fake ad clicks"];

const initials = (name: string | null, email: string) => {
  const p = (name || email).trim().split(/\s+/);
  return ((p[0]?.[0] ?? "?") + (p[1]?.[0] ?? "")).toUpperCase();
};

/** What an account on a shared phone can do, in plain words. */
function status(a: Account, first: boolean): { label: string; tone: "ok" | "warn" | "error" | "info" } {
  if (a.banned) return { label: "Banned", tone: "error" };
  if (first) return { label: "Can use the app · first on this phone", tone: "ok" };
  if (a.allowed && !a.blocked) return { label: "Can use the app · allowed by an admin", tone: "info" };
  return { label: "Paused · second account on this phone", tone: "warn" };
}

function useRun() {
  const router = useRouter();
  const [pending, start] = useTransition();
  const run = (p: () => Promise<{ ok: boolean; message?: string; error?: string }>, after?: () => void) => start(async () => {
    const r = await p();
    if (r.ok) { toast.success(r.message ?? "Done"); after?.(); router.refresh(); } else toast.error(r.error);
  });
  return { pending, run };
}

/* ------------------------------------------------------------------ reason dialog (instead of browser pop-ups) */
type Ask = { title: string; text: string; cta: string; presets: string[]; onSubmit: (reason: string) => void; danger?: boolean } | null;
function ReasonDialog({ ask, close, pending }: { ask: Ask; close: () => void; pending: boolean }) {
  const [reason, setReason] = useState("");
  return (
    <Dialog open={ask !== null} onOpenChange={(o) => { if (!o) { setReason(""); close(); } }}>
      <DialogContent className="sm:max-w-md">
        <DialogHeader>
          <DialogTitle>{ask?.title}</DialogTitle>
          <DialogDescription>{ask?.text}</DialogDescription>
        </DialogHeader>
        <div className="space-y-2">
          <div className="flex flex-wrap gap-1.5">
            {ask?.presets.map((p) => (
              <button key={p} type="button" onClick={() => setReason(p)}
                className={`rounded-full border px-2.5 py-1 text-xs ${reason === p ? "border-secondary bg-secondary/10 font-bold" : "hover:bg-muted"}`}>{p}</button>
            ))}
          </div>
          <textarea value={reason} onChange={(e) => setReason(e.target.value)} rows={3} maxLength={500} placeholder="Reason (the student sees it in the app and by email)"
            className={`${inputCls} h-auto py-2`} />
        </div>
        <DialogFooter>
          <Button variant="outline" onClick={() => { setReason(""); close(); }}>Cancel</Button>
          <Button variant={ask?.danger ? "destructive" : "default"} disabled={pending || reason.trim().length < 3}
            onClick={() => { ask?.onSubmit(reason.trim()); setReason(""); }}>{ask?.cta}</Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}

function Stat({ icon, label, value, help, tone, onClick }: { icon: React.ReactNode; label: string; value: number; help: string; tone: string; onClick: () => void }) {
  return (
    <button type="button" onClick={onClick} title={help} className="flex items-center gap-3 rounded-2xl border bg-card p-4 text-left transition hover:border-secondary/60 hover:shadow-sm">
      <span className={`grid size-11 shrink-0 place-items-center rounded-xl ${tone}`}>{icon}</span>
      <span className="min-w-0"><span className="block text-2xl font-bold tabular-nums leading-tight">{value}</span><span className="text-xs text-muted-foreground">{label}</span></span>
    </button>
  );
}

const TABS = [["todo", "To do"], ["phones", "Shared phones"], ["banned", "Banned"], ["activity", "Activity"]] as const;
type Tab = (typeof TABS)[number][0];

/** Fraud & bans (D-079, redesigned D-128): what needs a decision first, phones listed once, plain statuses. */
export function FraudBoard({ d }: { d: FraudData }) {
  const { pending, run } = useRun();
  const [ask, setAsk] = useState<Ask>(null);
  const appealsWaiting = d.appeals.filter((a) => a.status === "pending").length + d.phone_appeals.filter((a) => a.status === "pending").length;
  const paused = useMemo(() => d.shared_phones.flatMap((p) => p.accounts.map((a, i) => ({ a, i, p })).filter(({ a, i }) => i > 0 && !a.banned && a.blocked)), [d.shared_phones]);
  const todo = appealsWaiting + paused.length;
  const [tab, setTab] = useState<Tab>(todo ? "todo" : "phones");
  const [q, setQ] = useState("");
  const m = (...xs: (string | null | undefined)[]) => !q.trim() || xs.some((x) => (x ?? "").toLowerCase().includes(q.trim().toLowerCase()));

  const banAccount = (a: { user_id: string; name: string | null; email: string }) => setAsk({
    title: `Ban ${a.name ?? a.email}?`, text: "They cannot use the app with this account. They get an email with the reason and can appeal in the app.",
    cta: "Ban account", presets: BAN_PRESETS, danger: true, onSubmit: (r) => run(() => ban(a.user_id, true, r, false), () => setAsk(null)),
  });
  const banWholePhone = (p: Phone) => setAsk({
    title: `Ban phone ${p.device}…?`, text: `Every account on it (${p.accounts.length}) is banned and nobody can create a new account on it. They can only appeal.`,
    cta: "Ban phone", presets: ["Many fake accounts on one phone", ...BAN_PRESETS.slice(1, 3)], danger: true, onSubmit: (r) => run(() => banPhone(p.hash, r), () => setAsk(null)),
  });
  const ctx = { pending, run, banAccount, banWholePhone };
  const count: Record<Tab, number> = { todo, phones: d.shared_phones.length, banned: d.banned.length + d.banned_phones.length, activity: d.events.length };

  return (
    <div className="space-y-4">
      <details className="group rounded-2xl border bg-card p-4 text-sm open:pb-3">
        <summary className="flex cursor-pointer list-none items-center gap-2 font-bold"><Info size={18} className="text-secondary" /> How one account per phone works
          <span className="ml-auto text-xs font-normal text-muted-foreground group-open:hidden">Show</span></summary>
        <ol className="mt-3 list-decimal space-y-1 pl-5 text-muted-foreground">
          <li>The <b className="text-foreground">first account</b> on a phone always works.</li>
          <li>Any <b className="text-foreground">other account</b> that logs in on that phone is <b className="text-foreground">paused</b> and gets an email explaining why.</li>
          <li>Real family phone (brothers and sisters)? Press <b className="text-foreground">Allow on this phone</b> once. It works straight away and they get an email.</li>
          <li>Fake accounts for rewards? <b className="text-foreground">Ban</b> the account, or ban the whole phone. Banned students get an email and can appeal.</li>
        </ol>
      </details>

      <div className="grid grid-cols-2 gap-3 xl:grid-cols-4">
        <Stat icon={<Gavel size={22} />} label="Waiting for you" value={todo} help="Appeals and paused second accounts" tone={todo ? "bg-warning-soft text-on-warning-soft" : "bg-sunken text-muted-foreground"} onClick={() => setTab("todo")} />
        <Stat icon={<Users size={22} />} label="Shared phones" value={d.shared_phones.length} help="Phones with more than one account" tone="bg-info-soft text-on-info-soft" onClick={() => setTab("phones")} />
        <Stat icon={<Prohibit size={22} />} label="Banned accounts" value={d.stats.banned_accounts} help="Accounts that cannot use the app" tone="bg-error-soft text-on-error-soft" onClick={() => setTab("banned")} />
        <Stat icon={<DeviceMobileSlash size={22} />} label="Banned phones" value={d.stats.banned_phones} help="No account can be used on these phones" tone="bg-error-soft text-on-error-soft" onClick={() => setTab("banned")} />
      </div>

      <div className="flex flex-wrap items-center gap-2">
        <div className="flex flex-wrap gap-1 rounded-xl bg-surface-alt p-1">
          {TABS.map(([k, l]) => (
            <button key={k} type="button" onClick={() => setTab(k)}
              className={`rounded-lg px-3.5 py-2 text-sm font-semibold transition ${tab === k ? "bg-card shadow-sm" : "text-muted-foreground hover:text-foreground"}`}>
              {l}{count[k] ? <span className={`ml-1.5 rounded-full px-1.5 text-xs tabular-nums ${k === "todo" ? "bg-warning text-white" : "bg-sunken"}`}>{count[k]}</span> : null}
            </button>
          ))}
        </div>
        <label className="relative ml-auto w-full sm:w-72">
          <MagnifyingGlass size={16} className="absolute left-3 top-1/2 -translate-y-1/2 text-muted-foreground" />
          <input value={q} onChange={(e) => setQ(e.target.value)} placeholder="Search name, email or phone id" className={`${inputCls} pl-9`} />
        </label>
      </div>

      {tab === "todo" ? <Todo d={d} paused={paused.filter(({ a, p }) => m(a.name, a.email, p.device))} ctx={ctx} match={m} /> : null}
      {tab === "phones" ? (
        d.shared_phones.length ? (
          <div className="grid gap-3 lg:grid-cols-2">{d.shared_phones.filter((p) => m(p.device, ...p.accounts.flatMap((a) => [a.name, a.email]))).map((p) => <PhoneCard key={p.hash} p={p} ctx={ctx} />)}</div>
        ) : <Empty icon={<ShieldCheck size={28} />} title="No shared phones" text="Every phone has one account." />
      ) : null}
      {tab === "banned" ? <BannedTab d={d} ctx={ctx} match={m} /> : null}
      {tab === "activity" ? <ActivityTab d={d} match={m} /> : null}
      <p className="text-xs text-muted-foreground">Phones are recognised by two hashed ids (phone-wide and Android ID) that are treated as one phone. A factory reset makes a phone look new. {d.stats.phones_seen} phones seen so far.</p>
      <ReasonDialog ask={ask} close={() => setAsk(null)} pending={pending} />
    </div>
  );
}

type Ctx = { pending: boolean; run: ReturnType<typeof useRun>["run"]; banAccount: (a: { user_id: string; name: string | null; email: string }) => void; banWholePhone: (p: Phone) => void };

function Empty({ icon, title, text }: { icon: React.ReactNode; title: string; text: string }) {
  return (
    <div className="grid place-items-center gap-1 rounded-2xl border border-dashed p-10 text-center">
      <span className="text-success">{icon}</span><b>{title}</b><span className="text-sm text-muted-foreground">{text}</span>
    </div>
  );
}

/* ------------------------------------------------------------------ to do */
function Todo({ d, paused, ctx, match }: { d: FraudData; paused: { a: Account; i: number; p: Phone }[]; ctx: Ctx; match: (...xs: (string | null | undefined)[]) => boolean }) {
  const waiting = [...d.phone_appeals.filter((a) => a.status === "pending" && match(a.email, a.device, a.reason)), ...d.appeals.filter((a) => a.status === "pending" && match(a.name, a.reason))];
  if (!waiting.length && !paused.length) return <Empty icon={<CheckCircle size={28} />} title="Nothing waiting for you" text="New appeals and paused second accounts show here." />;
  return (
    <div className="space-y-5">
      {waiting.length ? (
        <section className="space-y-2">
          <h3 className="text-sm font-bold">Appeals ({waiting.length})</h3>
          <div className="grid gap-3 lg:grid-cols-2">{waiting.map((a) => <AppealCard key={a.id} a={a} ctx={ctx} />)}</div>
        </section>
      ) : null}
      {paused.length ? (
        <section className="space-y-2">
          <h3 className="text-sm font-bold">Paused second accounts ({paused.length})</h3>
          <p className="text-xs text-muted-foreground">Each logged in on a phone that already had an account. Allow real family phones; ban fake accounts. Doing nothing keeps them paused.</p>
          <ul className="divide-y rounded-2xl border bg-card">
            {paused.map(({ a, p }) => (
              <li key={p.hash + a.user_id} className="flex flex-wrap items-center gap-3 p-3 text-sm">
                <span className="grid size-9 shrink-0 place-items-center rounded-full bg-warning-soft text-xs font-bold text-on-warning-soft">{initials(a.name, a.email)}</span>
                <div className="min-w-0 flex-1">
                  <b className="block truncate">{a.name ?? "No name"}</b>
                  <span className="block truncate text-xs text-muted-foreground">{a.email} · phone {p.device}… first used by <b>{p.accounts[0]?.name ?? p.accounts[0]?.email}</b> · {a.attempts} tests</span>
                </div>
                <Button size="sm" disabled={ctx.pending} onClick={() => ctx.run(() => allowOnPhone(p.hash, a.user_id, true))}><UserCheck size={16} /> Allow on this phone</Button>
                <Button size="sm" variant="outline" disabled={ctx.pending} onClick={() => ctx.banAccount(a)}><Prohibit size={16} /> Ban</Button>
              </li>
            ))}
          </ul>
        </section>
      ) : null}
    </div>
  );
}

function AppealCard({ a, ctx }: { a: Appeal | PhoneAppeal; ctx: Ctx }) {
  const phone = "email" in a;
  const [noteText, setNote] = useState("");
  return (
    <div className="space-y-2 rounded-2xl border bg-card p-4 text-sm">
      <div className="flex flex-wrap items-center gap-2">
        <span className={`grid size-8 place-items-center rounded-lg ${phone ? "bg-error-soft text-on-error-soft" : "bg-warning-soft text-on-warning-soft"}`}>{phone ? <DeviceMobileSlash size={16} /> : <Gavel size={16} />}</span>
        <b>{phone ? `Banned phone ${(a as PhoneAppeal).device}…` : (a as Appeal).name ?? "No name"}</b>
        {phone ? <span className="text-xs text-muted-foreground">{(a as PhoneAppeal).email}</span> : null}
        <span className="ml-auto flex items-center gap-1 text-xs text-muted-foreground"><Clock size={12} />{when(a.created_at)}</span>
      </div>
      <p className="text-xs text-muted-foreground">Banned for: {a.ban_reason ?? "—"}</p>
      <p className="rounded-xl bg-surface-alt p-3">“{a.reason}”</p>
      {a.status === "pending" ? (
        <div className="space-y-2">
          <input value={noteText} onChange={(e) => setNote(e.target.value)} maxLength={500} placeholder="Note to the student (optional, sent by email)" className={inputCls} />
          <div className="flex flex-wrap gap-2">
            <Button size="sm" disabled={ctx.pending} onClick={() => ctx.run(() => (phone ? decidePhoneAppeal(a.id, true, noteText) : decideBanAppeal(a.id, true, noteText)))}><CheckCircle size={16} /> Accept and unban</Button>
            <Button size="sm" variant="outline" disabled={ctx.pending} onClick={() => ctx.run(() => (phone ? decidePhoneAppeal(a.id, false, noteText) : decideBanAppeal(a.id, false, noteText)))}>Reject</Button>
          </div>
          <p className="flex items-center gap-1 text-xs text-muted-foreground"><Envelope size={12} /> The student gets an email with your decision.</p>
        </div>
      ) : (
        <p className="text-xs text-muted-foreground"><Pill tone={a.status === "accepted" ? "ok" : "neutral"}>{a.status === "accepted" ? "Accepted" : "Rejected"}</Pill> {a.note ? ` ${a.note}` : ""}</p>
      )}
    </div>
  );
}

/* ------------------------------------------------------------------ shared phone card */
function PhoneCard({ p, ctx }: { p: Phone; ctx: Ctx }) {
  const clones = p.flags.filter((f) => f.startsWith("clone:"));
  const pausedN = p.accounts.filter((a, i) => i > 0 && !a.banned && a.blocked).length;
  return (
    <div className={`rounded-2xl border bg-card ${p.banned ? "border-error/40" : ""}`}>
      <div className="flex flex-wrap items-center gap-2 border-b p-3">
        <span className={`grid size-9 place-items-center rounded-xl ${p.banned ? "bg-error-soft text-on-error-soft" : "bg-info-soft text-on-info-soft"}`}>
          {p.banned ? <DeviceMobileSlash size={18} /> : <DeviceMobile size={18} />}</span>
        <div className="min-w-0">
          <div className="text-sm font-bold">Phone <span className="font-mono">{p.device}…</span></div>
          <div className="text-xs text-muted-foreground">{p.accounts.length} accounts · last used {when(p.last)}</div>
        </div>
        <span className="ml-auto">
          {p.banned ? <Pill tone="error">Phone banned</Pill> : pausedN ? <Pill tone="warn">{pausedN} paused</Pill> : <Pill tone="ok">Sorted</Pill>}
        </span>
      </div>
      {p.flags.length ? (
        <div className="flex flex-wrap gap-1 px-3 pt-3">{p.flags.map((f) => (
          <span key={f} className={`inline-flex items-center gap-1 rounded-full px-2 py-0.5 text-xs ${f.startsWith("clone:") ? "bg-error-soft text-on-error-soft" : "bg-sunken text-muted-foreground"}`}>{f.startsWith("clone:") ? <Warning size={12} /> : <Flag size={12} />}{flagLabel(f)}</span>
        ))}{clones.length ? <span className="text-xs text-muted-foreground">Cloned copies are a strong sign of fake accounts.</span> : null}</div>
      ) : null}
      <ul className="divide-y">{p.accounts.map((a, i) => {
        const st = status(a, i === 0);
        return (
          <li key={a.user_id} className="flex flex-wrap items-center gap-3 p-3 text-sm">
            <span className={`grid size-9 shrink-0 place-items-center rounded-full text-xs font-bold ${i === 0 ? "bg-secondary text-white" : "bg-sunken"}`}>{initials(a.name, a.email)}</span>
            <div className="min-w-0 flex-1">
              <div className="flex flex-wrap items-center gap-1.5"><b className="truncate">{a.name ?? "No name"}</b>{a.premium ? <Pill tone="gold">Premium</Pill> : null}</div>
              <div className="truncate text-xs text-muted-foreground">{a.email} · since {when(a.first_seen)} · {a.attempts} tests</div>
              <div className="mt-1"><Pill tone={st.tone}>{st.label}</Pill>{a.banned && a.ban_reason ? <span className="ml-1.5 text-xs text-muted-foreground">{a.ban_reason}</span> : null}</div>
            </div>
            <div className="flex flex-wrap gap-1.5">
              {i > 0 && !a.banned ? (
                a.blocked ? <Button size="sm" disabled={ctx.pending} onClick={() => ctx.run(() => allowOnPhone(p.hash, a.user_id, true))}><UserCheck size={16} /> Allow on this phone</Button>
                  : <Button size="sm" variant="outline" disabled={ctx.pending} onClick={() => ctx.run(() => allowOnPhone(p.hash, a.user_id, false))}>Pause again</Button>
              ) : null}
              {a.banned ? <Button size="sm" variant="outline" disabled={ctx.pending} onClick={() => ctx.run(() => ban(a.user_id, false, "", false))}><LockOpen size={16} /> Remove ban</Button>
                : <Button size="sm" variant="ghost" disabled={ctx.pending} title="Ban this account" onClick={() => ctx.banAccount(a)}><Prohibit size={16} /> Ban</Button>}
            </div>
          </li>
        );
      })}</ul>
      <div className="flex flex-wrap items-center justify-end gap-2 border-t p-3">
        {p.banned ? (
          <Button size="sm" variant="outline" disabled={ctx.pending} onClick={() => { if (confirm("Lift the ban on this phone? Accounts banned only because of it open again.")) ctx.run(() => unbanPhone(p.hash)); }}><LockOpen size={16} /> Lift phone ban</Button>
        ) : (
          <Button size="sm" variant="destructive" disabled={ctx.pending} onClick={() => ctx.banWholePhone(p)}><Lock size={16} /> Ban this phone</Button>
        )}
      </div>
    </div>
  );
}

/* ------------------------------------------------------------------ banned */
function BannedTab({ d, ctx, match }: { d: FraudData; ctx: Ctx; match: (...xs: (string | null | undefined)[]) => boolean }) {
  const accounts = d.banned.filter((b) => match(b.name, b.email, b.reason));
  const phones = d.banned_phones.filter((p) => match(p.device, p.reason));
  const decided = [...d.phone_appeals, ...d.appeals].filter((a) => a.status !== "pending").slice(0, 12);
  if (!accounts.length && !phones.length && !decided.length) return <Empty icon={<ShieldCheck size={28} />} title="Nobody is banned" text="Ban from a phone card or from Users." />;
  return (
    <div className="space-y-5">
      {accounts.length ? (
        <section className="space-y-2">
          <h3 className="text-sm font-bold">Banned accounts ({accounts.length})</h3>
          <ul className="divide-y rounded-2xl border bg-card">
            {accounts.map((b) => (
              <li key={b.user_id} className="flex flex-wrap items-center gap-3 p-3 text-sm">
                <span className="grid size-9 shrink-0 place-items-center rounded-full bg-error-soft text-xs font-bold text-on-error-soft">{initials(b.name, b.email)}</span>
                <div className="min-w-0 flex-1"><b className="block truncate">{b.name ?? "No name"}</b><span className="block truncate text-xs text-muted-foreground">{b.email} · {when(b.banned_at)} · {b.reason}</span></div>
                <Button size="sm" variant="outline" disabled={ctx.pending} onClick={() => ctx.run(() => ban(b.user_id, false, "", false))}><LockOpen size={16} /> Remove ban</Button>
              </li>
            ))}
          </ul>
        </section>
      ) : null}
      {phones.length ? (
        <section className="space-y-2">
          <h3 className="text-sm font-bold">Banned phones ({phones.length})</h3>
          <ul className="divide-y rounded-2xl border bg-card">
            {phones.map((p) => (
              <li key={p.hash} className="flex flex-wrap items-center gap-3 p-3 text-sm">
                <span className="grid size-9 place-items-center rounded-xl bg-error-soft text-on-error-soft"><DeviceMobileSlash size={18} /></span>
                <div className="min-w-0 flex-1"><b>Phone <span className="font-mono">{p.device}…</span></b><span className="block text-xs text-muted-foreground">{p.reason} · {when(p.banned_at)}{p.by ? ` · by ${p.by}` : ""} · {p.accounts} {p.accounts === 1 ? "account" : "accounts"}</span></div>
                <Button size="sm" variant="outline" disabled={ctx.pending} onClick={() => { if (confirm("Lift this phone ban? Accounts banned only because of it open again.")) ctx.run(() => unbanPhone(p.hash)); }}><LockOpen size={16} /> Lift ban</Button>
              </li>
            ))}
          </ul>
        </section>
      ) : null}
      {decided.length ? (
        <section className="space-y-2">
          <h3 className="text-sm font-bold text-muted-foreground">Decided appeals</h3>
          <div className="grid gap-3 lg:grid-cols-2">{decided.map((a) => <AppealCard key={a.id} a={a} ctx={ctx} />)}</div>
        </section>
      ) : null}
    </div>
  );
}

/* ------------------------------------------------------------------ activity */
function ActivityTab({ d, match }: { d: FraudData; match: (...xs: (string | null | undefined)[]) => boolean }) {
  const events = d.events.filter((e) => match(e.name, e.device, e.detail, e.kind));
  const flagged = d.flagged.filter((f) => match(f.name, f.email, ...f.flags));
  return (
    <div className="grid gap-4 xl:grid-cols-[1.4fr_1fr]">
      <section className="space-y-2">
        <h3 className="text-sm font-bold">Latest events</h3>
        {events.length ? (
          <ol className="rounded-2xl border bg-card p-2">{events.map((e, i) => {
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
        ) : <Empty icon={<ShieldCheck size={28} />} title="No events yet" text="Paused accounts, cloned apps and bans show here." />}
      </section>
      <section className="space-y-2">
        <h3 className="text-sm font-bold">Phones with warning signs</h3>
        {flagged.length ? (
          <ul className="divide-y rounded-2xl border bg-card">{flagged.map((f) => (
            <li key={f.user_id} className="space-y-1.5 p-3 text-sm">
              <div className="flex items-center gap-2"><span className="grid size-8 place-items-center rounded-full bg-warning-soft text-xs font-bold text-on-warning-soft">{initials(f.name, f.email)}</span>
                <div className="min-w-0"><b>{f.name ?? "No name"}</b><div className="truncate text-xs text-muted-foreground">{f.email} · {when(f.last)}</div></div></div>
              <div className="flex flex-wrap gap-1">{f.flags.map((x) => (
                <span key={x} className={`inline-flex items-center gap-1 rounded-full px-2 py-0.5 text-xs ${x.startsWith("clone:") ? "bg-error-soft text-on-error-soft" : "bg-sunken text-muted-foreground"}`}>
                  {x.startsWith("clone:") ? <Warning size={12} /> : <Flag size={12} />}{flagLabel(x)}</span>
              ))}</div>
            </li>
          ))}</ul>
        ) : <Empty icon={<ShieldCheck size={28} />} title="No warning signs" text="Dual apps, cloners and emulators show here." />}
      </section>
    </div>
  );
}
