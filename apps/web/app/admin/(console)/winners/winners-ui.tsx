"use client";
import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { SpinnerGap } from "@phosphor-icons/react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { Label } from "@/components/ui/label";
import { ImageUpload } from "@/components/admin/image-upload";
import { Pill, when } from "@/components/admin/ui";
import { markPaid, payout, rejectClaim, setWallPost } from "./actions";

type Claim = { id: string; amount: number; adult: boolean; guardian_name: string | null; guardian_phone: string | null; bank_name: string; account_number: string;
  account_name: string; status: "submitted" | "paid" | "rejected"; admin_note: string | null; paid_at: string | null; created_at: string;
  bank_code: string | null; verified_name: string | null; payout_status: "none" | "checked" | "sending" | "sent" | "failed" | "reversed";
  payout_error: string | null; payout_at: string | null };
export type ClaimRow = { entry_id: string; challenge: string; closed_at: string; rank: number; prize: number; name: string | null; state: string | null;
  flags: string[]; review: string | null; claim: Claim | null; on_wall: boolean };
export type WallRow = { id: string; challenge_title: string; name: string; state: string | null; place: string; amount: number; receipt_path: string | null; note: string | null; published: boolean; created_at: string };

const naira = (n: number) => "₦" + n.toLocaleString("en-NG");

export function ClaimsList({ rows, payouts = false }: { rows: ClaimRow[]; payouts?: boolean }) {
  const [open, setOpen] = useState<string | null>(null);
  return (
    <ul className="divide-y">
      {rows.map((r) => (
        <li key={r.entry_id} className="px-5 py-3 text-sm">
          <div className="flex flex-wrap items-center gap-2">
            <b>{r.name || "No name"}</b><span className="text-muted-foreground">{r.state}</span>
            <Pill tone="warn">#{r.rank} · {naira(r.prize)}</Pill>
            {!r.claim ? <Pill>Waiting for account details</Pill> : r.claim.status === "paid" ? <Pill tone="ok">Paid {when(r.claim.paid_at)}</Pill>
              : r.claim.status === "rejected" ? <Pill tone="error">Rejected</Pill> : <Pill tone="info">Ready to pay</Pill>}
            {r.on_wall ? <Pill tone="ok">On the wall</Pill> : null}
          </div>
          <span className="text-muted-foreground">{r.challenge} · closed {when(r.closed_at)}</span>
          {r.flags?.length ? <span className="block text-xs text-warning">Check before paying: {r.flags.join(" · ")}</span> : null}
          {r.claim ? (
            <div className="mt-2 rounded-xl bg-surface-alt p-3">
              <div className="grid gap-1 sm:grid-cols-2">
                <span><span className="text-muted-foreground">Bank:</span> <b>{r.claim.bank_name}</b></span>
                <span><span className="text-muted-foreground">Account:</span> <b className="tabular-nums">{r.claim.account_number}</b></span>
                <span><span className="text-muted-foreground">Name on account:</span> <b>{r.claim.account_name}</b></span>
                <span><span className="text-muted-foreground">Age:</span> {r.claim.adult ? "18 or older" : <b>Under 18: pay the guardian</b>}</span>
                {!r.claim.adult ? <span className="sm:col-span-2"><span className="text-muted-foreground">Guardian:</span> {r.claim.guardian_name} · {r.claim.guardian_phone}</span> : null}
              </div>
              <p className="mt-2 text-xs text-muted-foreground">Check that the name on the account matches the winner (or their guardian) before you pay.</p>
              {payouts || r.claim.payout_status === "sending" ? <Payout claim={r.claim} winner={r.name} /> : null}
              {r.claim.status === "submitted" ? (
                open === r.claim.id ? <PayForm claim={r.claim} onDone={() => setOpen(null)} /> : (
                  <div className="mt-2 flex flex-wrap gap-2">
                    <Button size="sm" variant={payouts ? "outline" : "default"} onClick={() => setOpen(r.claim!.id)}>{payouts ? "I paid it myself" : "I have paid"}</Button>
                    <Reject id={r.claim.id} />
                  </div>
                )
              ) : null}
            </div>
          ) : null}
        </li>
      ))}
    </ul>
  );
}

/** Pay with Paystack (D-090): 1. check whose account it is, 2. send. Paystack's webhook marks it paid. */
function Payout({ claim, winner }: { claim: Claim; winner: string | null }) {
  const router = useRouter();
  const [pending, start] = useTransition();
  const run = (step: "check" | "send" | "verify") => start(async () => {
    const r = await payout(claim.id, step);
    if (r.ok) toast.success(r.message ?? "Done"); else toast.error(r.error);
    router.refresh();
  });
  const ps = claim.payout_status ?? "none";
  if (claim.status !== "submitted" && ps !== "sent") return null;
  if (!claim.bank_code) {
    return <p className="mt-2 text-xs text-muted-foreground">Sent from an older app (bank typed by hand), so it cannot be paid with Paystack. Pay it yourself, then tap &ldquo;I paid it myself&rdquo;.</p>;
  }
  // A hint only: do the two names share a word (3+ letters)? The admin decides.
  const words = (x?: string | null) => new Set((x ?? "").toLowerCase().split(/[^a-z]+/).filter((w) => w.length >= 3));
  const same = (a?: string | null, b?: string | null) => [...words(a)].some((w) => words(b).has(w));
  return (
    <div className="mt-3 rounded-xl border bg-card p-3">
      <b className="block text-sm">Pay with Paystack</b>
      {claim.verified_name ? (
        <p className="mt-1 text-sm">Paystack says the account is <b>{claim.verified_name}</b>
          {same(claim.verified_name, claim.account_name) || same(claim.verified_name, winner) ? <Pill tone="ok">matches</Pill> : <Pill tone="warn">check the name</Pill>}</p>
      ) : <p className="mt-1 text-xs text-muted-foreground">First check whose account it is. Paystack looks it up; nothing is sent.</p>}
      {ps === "sending" ? <p className="mt-1 text-sm"><Pill tone="info">On its way</Pill> sent {when(claim.payout_at)}. Paystack confirms in a few minutes.</p> : null}
      {ps === "sent" ? <p className="mt-1 text-sm"><Pill tone="ok">Sent</Pill> The winner was told.</p> : null}
      {ps === "failed" || ps === "reversed" ? <p className="mt-1 text-sm text-error">{ps === "reversed" ? "Reversed by the bank" : "Not sent"}: {claim.payout_error}</p> : null}
      <div className="mt-2 flex flex-wrap gap-2">
        {ps === "none" || ps === "checked" || ps === "failed" ? <Button size="sm" variant="outline" disabled={pending} onClick={() => run("check")}>Check account</Button> : null}
        {(ps === "checked" || ps === "failed") && claim.verified_name ? (
          <Button size="sm" disabled={pending} onClick={() => { if (confirm(`Send ${naira(claim.amount)} to ${claim.verified_name} (${claim.bank_name} ${claim.account_number}) now?`)) run("send"); }}>
            Send {naira(claim.amount)}
          </Button>
        ) : null}
        {ps === "sending" ? <Button size="sm" variant="outline" disabled={pending} onClick={() => run("verify")}>Ask Paystack again</Button> : null}
      </div>
    </div>
  );
}

function PayForm({ claim, onDone }: { claim: Claim; onDone: () => void }) {
  const router = useRouter();
  const [pending, start] = useTransition();
  return (
    <form className="mt-3 space-y-3" action={(f) => start(async () => {
      f.set("claim_id", claim.id);
      const r = await markPaid(f);
      if (r.ok) { toast.success(r.message ?? "Saved"); onDone(); router.refresh(); } else toast.error(r.error);
    })}>
      <div className="space-y-1.5"><Label>Transfer receipt (for the Winners wall)</Label><ImageUpload name="receipt" kind="receipt" />
        <span className="block text-xs text-muted-foreground">Crop or cover the account number and balance before uploading.</span></div>
      <label className="flex items-start gap-2 text-sm"><input type="checkbox" name="publish" defaultChecked className="mt-1" /> Post it on the Winners wall</label>
      <label className="flex items-start gap-2 text-sm"><input type="checkbox" name="hidden_ok" className="mt-1" /> I checked: the account number, balance and other private details are hidden</label>
      <div className="space-y-1.5"><Label htmlFor={`note-${claim.id}`}>Winner&apos;s message (optional, with their permission)</Label>
        <input id={`note-${claim.id}`} name="note" maxLength={300} className="h-10 w-full rounded-xl border border-input bg-card px-3 text-sm" /></div>
      <div className="flex gap-2"><Button type="submit" disabled={pending}>{pending ? <SpinnerGap size={16} className="animate-spin" /> : null} Mark paid</Button>
        <Button type="button" variant="ghost" onClick={onDone}>Cancel</Button></div>
    </form>
  );
}

function Reject({ id }: { id: string }) {
  const router = useRouter();
  const [pending, start] = useTransition();
  return (
    <Button size="sm" variant="ghost" disabled={pending} onClick={() => {
      const note = prompt("Why is this claim rejected? (the winner is not told automatically)") ?? "";
      if (!note) return;
      start(async () => { const r = await rejectClaim(id, note); if (r.ok) { toast.success(r.message ?? "Rejected"); router.refresh(); } else toast.error(r.error); });
    }}>Reject</Button>
  );
}

export function WallList({ rows }: { rows: WallRow[] }) {
  const router = useRouter();
  const [pending, start] = useTransition();
  if (!rows.length) return <p className="px-5 py-6 text-sm text-muted-foreground">Nothing posted yet. Posts appear here after you mark a winner paid.</p>;
  return (
    <ul className="divide-y">
      {rows.map((w) => (
        <li key={w.id} className="flex items-center gap-3 px-5 py-3 text-sm">
          {w.receipt_path ? <img src={`/admin/api/image?key=${encodeURIComponent(w.receipt_path)}`} alt="Receipt" className="size-12 rounded-lg border object-cover" /> : null}
          <div className="min-w-0 flex-1"><b>{w.name}</b> <span className="text-muted-foreground">{w.state}</span>
            <span className="block text-muted-foreground">{w.place} · {naira(w.amount)} · {w.challenge_title}</span></div>
          <Button size="sm" variant="ghost" disabled={pending} onClick={() => start(async () => { const r = await setWallPost(w.id, !w.published); if (r.ok) { toast.success(r.message ?? "Saved"); router.refresh(); } else toast.error(r.error); })}>
            {w.published ? "Hide" : "Show"}</Button>
        </li>
      ))}
    </ul>
  );
}
