"use client";
import { useEffect, useState, useTransition } from "react";
import { usePathname, useRouter } from "next/navigation";
import { CaretLeft, CaretRight, MagnifyingGlass, Prohibit, SpinnerGap, Crown, ArrowCounterClockwise } from "@phosphor-icons/react";
import { toast } from "sonner";
import { Sheet, SheetContent, SheetHeader, SheetTitle, SheetDescription } from "@/components/ui/sheet";
import { Button } from "@/components/ui/button";
import { Pill } from "@/components/admin/ui";
import { getUserDetail, grantPremium, revokeEntitlement, setBan, type UserDetail } from "./actions";

type Row = { id: string; email: string; full_name: string | null; phone: string | null; state: string | null; created_at: string; last_sign_in_at: string | null; is_premium: boolean; premium_until: string | null; banned_at: string | null; staff_role: string | null };
const d = (iso: string | null) => (iso ? new Date(iso).toLocaleDateString("en-GB", { day: "numeric", month: "short", year: "numeric" }) : "Never");
const initials = (r: { full_name: string | null; email: string }) => (r.full_name || r.email).split(/[\s@.]+/).map((p) => p[0]).join("").slice(0, 2).toUpperCase();

export function UserTable({ rows, q, page, pages }: { rows: Row[]; q: string; page: number; pages: number }) {
  const router = useRouter();
  const path = usePathname();
  const [search, setSearch] = useState(q);
  const [open, setOpen] = useState<string | null>(null);
  const [pending, start] = useTransition();
  useEffect(() => {
    if (search === q) return;
    const t = setTimeout(() => start(() => router.push(search ? `${path}?q=${encodeURIComponent(search)}` : path)), 350);
    return () => clearTimeout(t);
  }, [search, q, path, router]);
  const goto = (p: number) => router.push(`${path}?${new URLSearchParams({ ...(q ? { q } : {}), page: String(p) })}`);

  return (
    <>
      <label className="relative mb-3 block max-w-md">
        <MagnifyingGlass size={18} className="absolute left-3 top-1/2 -translate-y-1/2 text-subtle" />
        <input value={search} onChange={(e) => setSearch(e.target.value)} placeholder="Search email, name or phone" aria-label="Search students"
          className="h-10 w-full rounded-xl border border-input bg-card pl-10 pr-9 text-sm outline-none focus-visible:ring-2 focus-visible:ring-ring" />
        {pending ? <SpinnerGap size={16} className="absolute right-3 top-1/2 -translate-y-1/2 animate-spin text-subtle" /> : null}
      </label>
      {rows.length ? (
        <div className="overflow-hidden rounded-2xl border bg-card">
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead className="bg-surface-alt text-left text-[11px] uppercase tracking-[0.6px] text-subtle">
                <tr><th className="px-5 py-2.5">Student</th><th className="px-3 py-2.5">Plan</th><th className="px-3 py-2.5">State</th><th className="px-3 py-2.5">Joined</th><th className="px-3 py-2.5">Last active</th><th className="px-3 py-2.5" /></tr>
              </thead>
              <tbody className="divide-y">
                {rows.map((r) => (
                  <tr key={r.id} className="cursor-pointer hover:bg-surface-alt" onClick={() => setOpen(r.id)}>
                    <td className="px-5 py-3">
                      <div className="flex items-center gap-3">
                        <span className="grid size-[34px] flex-none place-items-center rounded-full bg-info-soft text-xs font-bold text-on-info-soft">{initials(r)}</span>
                        <span className="min-w-0"><b className="block truncate">{r.full_name || "No name yet"}</b><span className="block truncate text-xs text-muted-foreground">{r.email}</span></span>
                      </div>
                    </td>
                    <td className="px-3 py-3">{r.staff_role ? <Pill tone="info">Staff</Pill> : r.is_premium ? <Pill tone="gold">Premium</Pill> : <Pill>Free</Pill>}</td>
                    <td className="px-3 py-3">{r.state ?? "—"}</td>
                    <td className="whitespace-nowrap px-3 py-3 text-muted-foreground">{d(r.created_at)}</td>
                    <td className="whitespace-nowrap px-3 py-3 text-muted-foreground">{d(r.last_sign_in_at)}</td>
                    <td className="px-3 py-3">{r.banned_at ? <Pill tone="error">Banned</Pill> : null}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
          <div className="flex items-center justify-end gap-1 border-t px-4 py-2.5 text-sm">
            <button className="grid size-9 place-items-center rounded-full hover:bg-muted disabled:opacity-40" disabled={page <= 1} onClick={() => goto(page - 1)} aria-label="Previous page"><CaretLeft size={18} /></button>
            <span>Page {page} of {pages}</span>
            <button className="grid size-9 place-items-center rounded-full hover:bg-muted disabled:opacity-40" disabled={page >= pages} onClick={() => goto(page + 1)} aria-label="Next page"><CaretRight size={18} /></button>
          </div>
        </div>
      ) : null}
      <Sheet open={open !== null} onOpenChange={(o) => !o && setOpen(null)}>
        <SheetContent className="w-full overflow-y-auto sm:max-w-[460px]">
          {open ? <UserDrawer id={open} onChanged={() => router.refresh()} /> : null}
        </SheetContent>
      </Sheet>
    </>
  );
}

function UserDrawer({ id, onChanged }: { id: string; onChanged: () => void }) {
  const [u, setU] = useState<UserDetail | null>(null);
  const [err, setErr] = useState("");
  const [pending, start] = useTransition();
  const load = () => getUserDetail(id).then((r) => (r.ok ? setU(r.data!) : setErr(r.error)));
  useEffect(() => { load(); /* eslint-disable-next-line react-hooks/exhaustive-deps */ }, [id]);

  if (err) return <p className="p-6 text-sm text-error">{err}</p>;
  if (!u) return <div className="space-y-3 p-6">{[0, 1, 2, 3].map((i) => <div key={i} className="h-14 animate-pulse rounded-xl bg-muted" />)}</div>;
  const p = u.profile;
  const banned = Boolean(p?.banned_at);
  const after = (msg: string) => (r: { ok: boolean; error?: string; message?: string }) => {
    if (r.ok) { toast.success(r.message ?? msg); load(); onChanged(); } else toast.error(r.error);
  };

  return (
    <div className="space-y-6 p-6">
      <SheetHeader className="p-0">
        <SheetTitle className="text-[21px]">{p?.full_name || "No name yet"}</SheetTitle>
        <SheetDescription>{u.email}{p?.state ? ` · ${p.state}` : ""}</SheetDescription>
        <div className="flex flex-wrap gap-2 pt-1">
          {u.staff_role ? <Pill tone="info">Staff: {u.staff_role.replace("_", " ")}</Pill> : null}
          {u.is_premium ? <Pill tone="gold">Premium</Pill> : <Pill>Free</Pill>}
          {banned ? <Pill tone="error">Banned</Pill> : <Pill tone="ok">Active</Pill>}
          {!u.email_confirmed ? <Pill tone="warn">Email not confirmed</Pill> : null}
        </div>
      </SheetHeader>

      <dl className="grid grid-cols-2 gap-3 text-sm">
        {[["Joined", d(u.created_at)], ["Last active", d(u.last_sign_in_at)], ["Phone", p?.phone || "—"], ["School", p?.school || "—"],
          ["Exams", p?.target_exams?.join(", ") || "—"], ["Target score", p?.target_score ?? "—"]].map(([k, v]) => (
          <div key={String(k)} className="rounded-xl bg-surface-alt p-3"><dt className="text-xs text-muted-foreground">{k}</dt><dd className="font-bold">{v}</dd></div>
        ))}
      </dl>

      <section className="space-y-3">
        <h3 className="text-sm font-bold">Give Premium</h3>
        <form action={(f) => start(async () => after("Premium given.")(await grantPremium(f)))} className="space-y-2">
          <input type="hidden" name="user_id" value={u.id} />
          <div className="flex gap-2">
            <select name="days" defaultValue="30" className="h-10 rounded-xl border border-input bg-card px-3 text-sm" aria-label="How long">
              <option value="7">7 days</option><option value="30">30 days</option><option value="90">90 days</option><option value="365">1 year</option>
            </select>
            <input name="reason" required minLength={3} placeholder="Reason (e.g. payment issue, prize)" className="h-10 min-w-0 grow rounded-xl border border-input bg-card px-3 text-sm" />
          </div>
          <Button type="submit" disabled={pending} className="w-full"><Crown size={16} weight="fill" /> Give Premium</Button>
          <p className="text-xs text-muted-foreground">If they already have Premium, the time is added to the end. Logged with your name.</p>
        </form>
      </section>

      <section className="space-y-2">
        <h3 className="text-sm font-bold">Premium history</h3>
        {u.entitlements.length ? u.entitlements.map((e) => {
          const active = !e.revoked_at && new Date(e.expires_at) > new Date();
          return (
            <div key={e.id} className="flex items-center gap-3 rounded-xl border p-3 text-sm">
              <div className="grow"><b className="capitalize">{e.plan ?? e.source}</b> <span className="text-muted-foreground">· {e.source}</span>
                <div className="text-xs text-muted-foreground">{d(e.starts_at)} to {d(e.expires_at)}{e.reason ? ` · ${e.reason}` : ""}</div></div>
              {e.revoked_at ? <Pill>Revoked</Pill> : active ? (
                <Button size="sm" variant="ghost" className="text-error" disabled={pending}
                  onClick={() => confirm("Remove this Premium access now?") && start(async () => after("Premium removed.")(await revokeEntitlement(e.id)))}>
                  <ArrowCounterClockwise size={14} /> Revoke
                </Button>
              ) : <Pill>Ended</Pill>}
            </div>
          );
        }) : <p className="text-sm text-muted-foreground">No Premium yet.</p>}
      </section>

      {!u.staff_role ? (
        <section className="space-y-2 rounded-2xl border border-error/30 p-4">
          <h3 className="text-sm font-bold">{banned ? "Banned" : "Ban this student"}</h3>
          {banned ? (
            <>
              <p className="text-sm text-muted-foreground">Reason: {p?.ban_reason}</p>
              <Button variant="outline" disabled={pending} onClick={() => start(async () => after("Ban removed.")(await setBan(u.id, false, "")))}>Remove ban</Button>
            </>
          ) : (
            <form action={(f) => { if (!confirm("Ban this student? The app shows them a ban screen, and unpaid rewards and prizes are cancelled. They can send one appeal within 14 days.")) return; start(async () => after("Student banned.")(await setBan(u.id, true, String(f.get("reason")), f.get("linked") === "on"))); }} className="space-y-2">
              <input name="reason" required minLength={3} placeholder="Reason (the student sees it; kept in the audit log)" className="h-10 w-full rounded-xl border border-input bg-card px-3 text-sm" />
              <label className="flex items-center gap-2 text-sm"><input type="checkbox" name="linked" /> Also ban other accounts on the same phone</label>
              <Button type="submit" variant="destructive" disabled={pending}><Prohibit size={16} /> Ban</Button>
            </form>
          )}
        </section>
      ) : null}
    </div>
  );
}
