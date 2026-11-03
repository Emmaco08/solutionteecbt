"use client";
import { useEffect, useState, useTransition } from "react";
import { usePathname, useRouter } from "next/navigation";
import { ArrowsClockwise, ArrowUUpLeft, CaretLeft, CaretRight, CheckCircle, Circle, MagnifyingGlass, SpinnerGap, WarningCircle } from "@phosphor-icons/react";
import { toast } from "sonner";
import { Sheet, SheetContent, SheetDescription, SheetHeader, SheetTitle } from "@/components/ui/sheet";
import { Button } from "@/components/ui/button";
import { Pill, naira, when, type Tone } from "@/components/admin/ui";
import { checkPayment, getPayment, refundPayment, type PaymentDetail } from "./actions";

export type PaymentRow = {
  id: string; reference: string; provider: string; status: string; amount_kobo: number; list_kobo: number; discount_kobo: number;
  channel: string | null; source: string; created_at: string; verified_at: string | null; plan: string; email: string | null; promo: string | null;
};

const STATUS: Record<string, [string, Tone]> = {
  success: ["Paid", "ok"], pending: ["Waiting", "warn"], failed: ["Failed", "error"], abandoned: ["Not finished", "neutral"],
  needs_review: ["Needs review", "error"], refunded: ["Refunded", "neutral"],
};
const PROVIDER: Record<string, string> = { paystack: "Paystack", play: "Google Play", code: "100% code" };
const status = (s: string, created: string) => {
  // A Paystack checkout left open for a day is shown as not finished.
  if (s === "pending" && Date.now() - new Date(created).getTime() > 86_400_000) return STATUS.abandoned;
  return STATUS[s] ?? [s, "neutral" as Tone];
};

export function PaymentTable({ rows, q, page, hasNext, tab }: { rows: PaymentRow[]; q: string; page: number; hasNext: boolean; tab: string }) {
  const router = useRouter();
  const path = usePathname();
  const [search, setSearch] = useState(q);
  const [open, setOpen] = useState<string | null>(null);
  const [pending, start] = useTransition();
  const qs = (extra: Record<string, string>) => `${path}?${new URLSearchParams({ ...(tab !== "all" ? { tab } : {}), ...(q ? { q } : {}), ...extra })}`;
  useEffect(() => {
    if (search === q) return;
    const t = setTimeout(() => start(() => router.push(`${path}?${new URLSearchParams({ ...(tab !== "all" ? { tab } : {}), ...(search ? { q: search } : {}) })}`)), 350);
    return () => clearTimeout(t);
  }, [search, q, path, router, tab]);

  return (
    <>
      <label className="relative mb-3 block max-w-md">
        <MagnifyingGlass size={18} className="absolute left-3 top-1/2 -translate-y-1/2 text-subtle" />
        <input value={search} onChange={(e) => setSearch(e.target.value)} placeholder="Search reference or email" aria-label="Search payments"
          className="h-10 w-full rounded-xl border border-input bg-card pl-10 pr-9 text-sm outline-none focus-visible:ring-2 focus-visible:ring-ring" />
        {pending ? <SpinnerGap size={16} className="absolute right-3 top-1/2 -translate-y-1/2 animate-spin text-subtle" /> : null}
      </label>
      {rows.length ? (
        <div className="overflow-hidden rounded-2xl border bg-card">
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead className="bg-surface-alt text-left text-[11px] uppercase tracking-[0.6px] text-subtle">
                <tr><th className="px-5 py-2.5">Reference</th><th className="px-3 py-2.5">Student</th><th className="px-3 py-2.5">Plan</th><th className="px-3 py-2.5 text-right">Amount</th><th className="px-3 py-2.5">Paid with</th><th className="px-3 py-2.5">Status</th><th className="px-3 py-2.5">Date</th></tr>
              </thead>
              <tbody className="divide-y">
                {rows.map((r) => {
                  const [label, tone] = status(r.status, r.created_at);
                  return (
                    <tr key={r.id} className="cursor-pointer hover:bg-surface-alt" onClick={() => setOpen(r.id)}>
                      <td className="px-5 py-3 font-mono text-xs">{r.reference.length > 26 ? r.reference.slice(0, 24) + "…" : r.reference}</td>
                      <td className="max-w-[220px] truncate px-3 py-3">{r.email ?? <span className="text-muted-foreground">Deleted account</span>}</td>
                      <td className="px-3 py-3">{r.plan}{r.promo ? <span className="block text-xs text-muted-foreground">{r.promo}</span> : null}</td>
                      <td className="tnum px-3 py-3 text-right font-bold">{naira(r.amount_kobo)}</td>
                      <td className="px-3 py-3 text-muted-foreground">{PROVIDER[r.provider] ?? r.provider}{r.channel ? ` · ${r.channel}` : ""}</td>
                      <td className="px-3 py-3"><Pill tone={tone}>{label}</Pill></td>
                      <td className="whitespace-nowrap px-3 py-3 text-muted-foreground">{when(r.created_at)}</td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
          <div className="flex items-center justify-end gap-1 border-t px-4 py-2.5 text-sm">
            <button className="grid size-9 place-items-center rounded-full hover:bg-muted disabled:opacity-40" disabled={page <= 1} onClick={() => router.push(qs({ page: String(page - 1) }))} aria-label="Previous page"><CaretLeft size={18} /></button>
            <span>Page {page}</span>
            <button className="grid size-9 place-items-center rounded-full hover:bg-muted disabled:opacity-40" disabled={!hasNext} onClick={() => router.push(qs({ page: String(page + 1) }))} aria-label="Next page"><CaretRight size={18} /></button>
          </div>
        </div>
      ) : null}
      <Sheet open={open !== null} onOpenChange={(o) => !o && setOpen(null)}>
        <SheetContent className="w-full overflow-y-auto sm:max-w-[460px]">
          {open ? <PaymentDrawer id={open} onChanged={() => router.refresh()} /> : null}
        </SheetContent>
      </Sheet>
    </>
  );
}

function PaymentDrawer({ id, onChanged }: { id: string; onChanged: () => void }) {
  const [d, setD] = useState<PaymentDetail | null>(null);
  const [err, setErr] = useState("");
  const [sure, setSure] = useState(false);
  const [pending, start] = useTransition();
  const load = () => getPayment(id).then((r) => (r.ok ? setD(r.data!) : setErr(r.error)));
  useEffect(() => {
    load();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [id]);

  if (err) return <p className="p-6 text-sm text-error">{err}</p>;
  if (!d) return <div className="space-y-3 p-6">{[0, 1, 2, 3].map((i) => <div key={i} className="h-14 animate-pulse rounded-xl bg-muted" />)}</div>;
  const p = d.payment;
  const [label, tone] = status(p.status, p.created_at);
  const run = (fn: () => Promise<{ ok: boolean; error?: string; message?: string }>) => start(async () => {
    const r = await fn();
    if (r.ok) { toast.success(r.message ?? "Done"); load(); onChanged(); } else toast.error(r.error);
    setSure(false);
  });

  return (
    <div className="space-y-6 p-6">
      <SheetHeader className="p-0">
        <span className="font-mono text-xs text-muted-foreground">{p.reference}</span>
        <SheetTitle className="tnum text-[28px]">{naira(p.amount_kobo)}</SheetTitle>
        <SheetDescription>{p.email ?? "Deleted account"} · {p.plan}</SheetDescription>
        <div className="flex flex-wrap gap-2 pt-1"><Pill tone={tone}>{label}</Pill><Pill>{PROVIDER[p.provider] ?? p.provider}</Pill>{p.source === "web" ? <Pill tone="info">Website</Pill> : <Pill tone="info">App</Pill>}</div>
      </SheetHeader>

      <dl className="grid grid-cols-2 gap-3 text-sm">
        {[["Price", naira(p.list_kobo)], ["Discount", p.discount_kobo ? `${naira(p.discount_kobo)}${p.promo ? ` (${p.promo})` : ""}` : "—"],
          ["Started", when(p.created_at)], ["Checked", when(p.verified_at)],
          ["Premium until", p.premium_revoked ? "Removed" : when(p.premium_until)], ["Paid with", p.channel ?? "—"]].map(([k, v]) => (
          <div key={k} className="rounded-xl bg-surface-alt p-3"><dt className="text-xs text-muted-foreground">{k}</dt><dd className="font-bold">{v}</dd></div>
        ))}
      </dl>

      <section>
        <h3 className="mb-2 text-sm font-bold">Timeline</h3>
        <ol className="space-y-2.5">
          {d.events.map((e, i) => (
            <li key={i} className="flex gap-2.5 text-sm">
              {e.ok ? <CheckCircle size={18} weight="fill" className="mt-0.5 flex-none text-success" /> : <WarningCircle size={18} weight="fill" className="mt-0.5 flex-none text-warning" />}
              <span className="min-w-0"><span className="block">{e.note ?? e.kind}</span><span className="block text-xs text-muted-foreground">{when(e.at)} · {e.provider} · {e.kind}</span></span>
            </li>
          ))}
          {!d.events.length ? <li className="flex gap-2.5 text-sm text-muted-foreground"><Circle size={18} /> No steps yet.</li> : null}
        </ol>
      </section>

      {p.provider === "paystack" ? (
        <div className="flex flex-wrap gap-2">
          {p.status === "pending" || p.status === "failed" ? (
            <Button variant="outline" size="sm" disabled={pending} onClick={() => run(() => checkPayment(p.reference))}>
              {pending ? <SpinnerGap size={14} className="animate-spin" /> : <ArrowsClockwise size={16} />} Check with Paystack again
            </Button>
          ) : null}
          {p.status === "success" ? (
            <Button variant={sure ? "destructive" : "outline"} size="sm" disabled={pending}
              onClick={() => (sure ? run(() => refundPayment(p.reference)) : setSure(true))}>
              <ArrowUUpLeft size={16} /> {sure ? "Tap again: refund and remove Premium" : "Refund"}
            </Button>
          ) : null}
        </div>
      ) : p.provider === "play" ? (
        <p className="rounded-xl bg-surface-alt p-3 text-sm text-muted-foreground">Google Play refunds are made in Play Console (Order management). Premium is removed here by itself when Google tells us.</p>
      ) : null}
      {p.status === "needs_review" ? (
        <p className="rounded-xl bg-error-soft p-3 text-sm text-on-error-soft">The amount paid did not match the price we asked for, so no Premium was given. Check this payment in the Paystack dashboard. If the student really paid, give Premium by hand in Users (with this reference as the reason), or refund it in Paystack.</p>
      ) : null}
    </div>
  );
}
