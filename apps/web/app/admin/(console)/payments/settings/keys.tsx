"use client";
import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { Check, Copy, Flask, Key, Lightning, SpinnerGap, Warning } from "@phosphor-icons/react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { inputCls } from "@/components/admin/row-form";
import { savePaystackKey, setPaystackMode, type PaystackKeyName } from "./actions";

export type KeysState = {
  mode: "test" | "live"; sk_live: string | null; pk_live: string | null; sk_test: string | null; pk_test: string | null; test_payments: number;
};
/** What the payment server is using right now (its ?health=1 answer; never a key). */
export type ServerState = { mode?: string; keys_from?: string; secret_key?: string; public_key?: string } | null;

const SLOTS: { name: PaystackKeyName; field: keyof KeysState; label: string; hint: string }[] = [
  { name: "paystack_sk_live", field: "sk_live", label: "Live secret key", hint: "sk_live_…" },
  { name: "paystack_pk_live", field: "pk_live", label: "Live public key", hint: "pk_live_…" },
  { name: "paystack_sk_test", field: "sk_test", label: "Test secret key", hint: "sk_test_…" },
  { name: "paystack_pk_test", field: "pk_test", label: "Test public key", hint: "pk_test_…" },
];

const WEBHOOK = `${process.env.NEXT_PUBLIC_SUPABASE_URL}/functions/v1/paystack-webhook`;
const CALLBACK = "https://cbt.solutiontee.com/pay/done";

/** Paystack keys and the Test / Live switch (D-133). Super admins with 2-step login only (checked again on the server). */
export function PaystackKeys({ initial, server, canEdit }: { initial: KeysState; server: ServerState; canEdit: boolean }) {
  const router = useRouter();
  const [pending, start] = useTransition();
  const [ask, setAsk] = useState<"test" | "live" | null>(null);
  const k = initial;
  const legacy = !k.sk_live && !k.sk_test;
  const ready = { live: Boolean(k.sk_live && k.pk_live), test: Boolean(k.sk_test && k.pk_test) };
  const mode = legacy ? (server?.mode === "test" ? "test" : "live") : k.mode;

  const switchTo = (m: "test" | "live") => start(async () => {
    const r = await setPaystackMode(m);
    if (r.ok) { toast.success(r.message ?? "Saved"); setAsk(null); router.refresh(); } else toast.error(r.error);
  });

  return (
    <section className="rounded-2xl border bg-card p-5 shadow-[var(--shadow-1)]">
      <div className="flex flex-wrap items-start justify-between gap-3">
        <div>
          <h2 className="text-[17px] font-bold">Paystack: Test or Live</h2>
          <p className="mt-1 max-w-2xl text-sm text-muted-foreground">Your Paystack keys are saved encrypted in Supabase Vault. Nobody can read them back here, and they never reach the app or a browser.</p>
        </div>
        <span className={`inline-flex items-center gap-1.5 rounded-full px-3 py-1 text-xs font-bold ${mode === "live" ? "bg-success-soft text-on-success-soft" : "bg-warning-soft text-on-warning-soft"}`}>
          {mode === "live" ? <Lightning size={14} weight="fill" /> : <Flask size={14} weight="fill" />} Now: {mode === "live" ? "Live (real money)" : "Test (no real money)"}
        </span>
      </div>

      {legacy ? (
        <div className="mt-4 flex gap-3 rounded-xl bg-warning-soft px-4 py-3 text-sm text-on-warning-soft">
          <Warning size={20} weight="fill" className="mt-0.5 shrink-0" />
          <div>
            <b className="block">No keys saved here yet</b>
            The payment server is using its old secret{server?.secret_key ? <>, which is a <b>{server.secret_key}</b> key</> : null}.
            {server?.secret_key === "test" ? " Payments so far are Paystack test payments: no real money." : null} Save your keys below, then choose Live.
          </div>
        </div>
      ) : null}

      {/* The switch */}
      <div className="mt-4 grid gap-3 sm:grid-cols-2">
        {(["live", "test"] as const).map((m) => {
          const on = mode === m;
          return (
            <button key={m} type="button" disabled={!canEdit || pending || on || !ready[m]} onClick={() => setAsk(m)}
              className={`flex items-start gap-3 rounded-2xl border-2 p-4 text-left transition-colors disabled:cursor-default ${on ? "border-[#2563B3] bg-[#EEF4FC] dark:bg-[#16284A]" : "border-border enabled:hover:border-[#2563B3]/50"} ${!on && !ready[m] ? "opacity-60" : ""}`}>
              <span className={`mt-0.5 grid size-9 shrink-0 place-items-center rounded-xl ${m === "live" ? "bg-success-soft text-on-success-soft" : "bg-warning-soft text-on-warning-soft"}`}>
                {m === "live" ? <Lightning size={18} weight="fill" /> : <Flask size={18} weight="fill" />}
              </span>
              <span>
                <b className="block">{m === "live" ? "Live" : "Test"} {on ? <span className="ml-1 text-xs font-bold text-[#2563B3]">· in use</span> : null}</b>
                <span className="text-[13px] leading-5 text-muted-foreground">
                  {m === "live" ? "Students pay with real cards, transfers and USSD." : "Only staff accounts can pay, with Paystack’s test cards. Students see “payments paused for a few minutes”."}
                  {on && legacy ? " In use now with the old server key." : !ready[m] ? ` Save both ${m} keys first.` : ""}
                </span>
              </span>
            </button>
          );
        })}
      </div>
      {ask ? (
        <div className="mt-3 flex flex-wrap items-center gap-3 rounded-xl border-2 border-[#2563B3]/40 px-4 py-3 text-sm">
          <span className="grow">{ask === "live" ? "Switch to Live? New payments use real money at once." : "Switch to Test? Students cannot pay until you switch back to Live."} Payments already started keep their own mode.</span>
          <Button size="sm" variant="ghost" onClick={() => setAsk(null)} disabled={pending}>Cancel</Button>
          <Button size="sm" onClick={() => switchTo(ask)} disabled={pending}>{pending ? <SpinnerGap size={14} className="animate-spin" /> : null} Switch to {ask === "live" ? "Live" : "Test"}</Button>
        </div>
      ) : null}

      {/* Keys */}
      <div className="mt-5 grid gap-3 lg:grid-cols-2">
        {SLOTS.map((s) => <KeySlot key={s.name} slot={s} saved={k[s.field] as string | null} canEdit={canEdit} />)}
      </div>
      {!canEdit ? <p className="mt-2 text-xs text-muted-foreground">Only a super admin with 2-step login can change keys or switch modes.</p> : null}

      {/* What to set in Paystack */}
      <div className="mt-5 rounded-xl bg-muted/60 p-4 text-sm">
        <b className="block">In your Paystack dashboard (Settings → API Keys &amp; Webhooks), on both the Test and the Live tab:</b>
        <Copyable label="Webhook URL" value={WEBHOOK} />
        <Copyable label="Callback URL" value={CALLBACK} />
        <p className="mt-2 text-xs text-muted-foreground">Payments are also confirmed without the webhook (every 2 minutes and on the result page), but set it for instant confirmation.</p>
      </div>
      {k.test_payments > 0 ? <p className="mt-3 text-xs text-muted-foreground">{k.test_payments} test payment{k.test_payments === 1 ? "" : "s"} so far; they are marked Test and left out of revenue.</p> : null}
    </section>
  );
}

function KeySlot({ slot, saved, canEdit }: { slot: (typeof SLOTS)[number]; saved: string | null; canEdit: boolean }) {
  const router = useRouter();
  const [v, setV] = useState("");
  const [pending, start] = useTransition();
  const save = () => start(async () => {
    const r = await savePaystackKey(slot.name, v);
    if (r.ok) { toast.success(r.message ?? "Saved"); setV(""); router.refresh(); } else toast.error(r.error);
  });
  return (
    <div className="rounded-xl border p-3">
      <div className="flex items-center justify-between gap-2">
        <b className="flex items-center gap-1.5 text-sm"><Key size={16} weight="fill" className="text-muted-foreground" /> {slot.label}</b>
        {saved ? <span className="inline-flex items-center gap-1 font-mono text-xs text-on-success-soft"><Check size={12} weight="bold" /> {saved}</span> : <span className="text-xs text-muted-foreground">Not saved</span>}
      </div>
      {canEdit ? (
        <form className="mt-2 flex gap-2" onSubmit={(e) => { e.preventDefault(); save(); }}>
          <input type="password" autoComplete="off" spellCheck={false} value={v} onChange={(e) => setV(e.target.value)} placeholder={saved ? `Replace: ${slot.hint}` : slot.hint}
            aria-label={slot.label} className={`${inputCls} font-mono`} />
          <Button type="submit" size="sm" className="h-10" disabled={pending || !v.trim()}>{pending ? <SpinnerGap size={14} className="animate-spin" /> : null} Save</Button>
        </form>
      ) : null}
    </div>
  );
}

function Copyable({ label, value }: { label: string; value: string }) {
  const [done, setDone] = useState(false);
  return (
    <div className="mt-2 flex flex-wrap items-center gap-2">
      <span className="w-28 shrink-0 text-muted-foreground">{label}</span>
      <code className="min-w-0 flex-1 truncate rounded-lg bg-card px-2 py-1.5 text-xs">{value}</code>
      <button type="button" onClick={() => navigator.clipboard?.writeText(value).then(() => { setDone(true); setTimeout(() => setDone(false), 1500); })}
        className="inline-flex h-8 items-center gap-1 rounded-lg border px-2 text-xs font-bold hover:bg-card">{done ? <Check size={12} weight="bold" /> : <Copy size={12} />} {done ? "Copied" : "Copy"}</button>
    </div>
  );
}
