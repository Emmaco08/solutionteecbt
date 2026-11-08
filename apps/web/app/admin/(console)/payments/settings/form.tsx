"use client";
import { useState } from "react";
import { Label } from "@/components/ui/label";
import { Switch } from "@/components/ui/switch";
import { RowForm, inputCls } from "@/components/admin/row-form";
import { savePaymentSettings } from "./actions";

export type PaySettings = {
  play: { google: boolean; website: boolean };
  website_url: string;
  fees: { paystack: { on: boolean; pct: number; flat: number; flat_from: number; cap: number }; google: { on: boolean; pct: number } };
};

/** Same sum as the server's private.paystack_fee (naira here, for the example only). */
function paystackFee(price: number, f: PaySettings["fees"]["paystack"]) {
  if (!f.on || price <= 0) return 0;
  const pct = Math.min(Math.max(f.pct, 0), 20) / 100;
  let total = price / (1 - pct);
  if (f.flat > 0 && total >= f.flat_from) total = (price + f.flat) / (1 - pct);
  let fee = Math.ceil(total - price);
  if (f.cap > 0) fee = Math.min(fee, f.cap);
  return Math.max(fee, 0);
}

const ng = (n: number) => `₦${n.toLocaleString("en-NG")}`;

export function PaymentSettingsForm({ initial, plans, playUrl }: { initial: PaySettings; plans: { name: string; price: number; fee_id: string | null }[]; playUrl: string }) {
  const [s, setS] = useState(initial);
  const [play, setPlay] = useState(playUrl);
  const ps = s.fees.paystack, gs = s.fees.google;
  const setPay = (k: keyof typeof ps, v: number | boolean) => setS({ ...s, fees: { ...s.fees, paystack: { ...ps, [k]: v } } });
  const setGoogle = (k: keyof typeof gs, v: number | boolean) => setS({ ...s, fees: { ...s.fees, google: { ...gs, [k]: v } } });
  const field = (id: string, label: string, v: number, set: (n: number) => void, step = "0.1") => (
    <div className="space-y-1.5"><Label htmlFor={id}>{label}</Label>
      <input id={id} name={id} type="number" min={0} step={step} value={v} onChange={(e) => set(Number(e.target.value))} className={inputCls} /></div>
  );
  return (
    <RowForm action={savePaymentSettings} success="Saved" submitLabel="Save payment settings" className="space-y-6">
      <section className="rounded-2xl border bg-card p-5 shadow-[var(--shadow-1)]">
        <h2 className="text-[17px] font-bold">Google Play app: how students pay</h2>
        <p className="mt-1 text-sm text-muted-foreground">Choose one or both. The direct app from the website always uses Paystack.</p>
        <div className="mt-4 divide-y">
          <label className="flex items-center gap-4 py-3">
            <span className="grow"><b className="block text-sm">Google Play payments</b><small className="block text-[13px] text-muted-foreground">Card and other ways Google offers. Prices come from Play Console.</small></span>
            <Switch name="play_google" checked={s.play.google} onCheckedChange={(v) => setS({ ...s, play: { ...s.play, google: v } })} />
          </label>
          <label className="flex items-center gap-4 py-3">
            <span className="grow"><b className="block text-sm">“Pay on our website” button</b><small className="block text-[13px] text-muted-foreground">Opens the payment website with the plan chosen. Students pay with Paystack (card, transfer, USSD, OPay); Premium shows in the app at once.</small></span>
            <Switch name="play_website" checked={s.play.website} onCheckedChange={(v) => setS({ ...s, play: { ...s.play, website: v } })} />
          </label>
        </div>
        {s.play.website ? (
          <p className="mt-3 rounded-xl bg-warning-soft px-3 py-2 text-sm text-on-warning-soft">
            <b>Google Play rule:</b> outside Google’s billing-choice countries (US, UK, EEA), Google does not allow a Play app to send students
            to another way to pay. With this on, Google may reject an update or remove the app. You can turn it off here at any time, without an app update.
          </p>
        ) : null}
        {!s.play.google && !s.play.website ? <p className="mt-3 text-sm text-destructive">Choose at least one.</p> : null}
        <div className="mt-4 space-y-1.5"><Label htmlFor="website_url">Payment website</Label>
          <input id="website_url" name="website_url" value={s.website_url} onChange={(e) => setS({ ...s, website_url: e.target.value })} className={`${inputCls} font-mono`} /></div>
        <div className="mt-4 space-y-1.5"><Label htmlFor="play_url">Google Play link (for the website’s download button)</Label>
          <input id="play_url" name="play_url" value={play} onChange={(e) => setPlay(e.target.value)} placeholder="https://play.google.com/store/apps/details?id=…" className={`${inputCls} font-mono`} />
          <p className="text-xs text-muted-foreground">Empty: the website shows “Google Play: coming soon”. The website updates within an hour.</p></div>
      </section>

      <section className="rounded-2xl border bg-card p-5 shadow-[var(--shadow-1)]">
        <label className="flex items-center gap-4">
          <span className="grow"><b className="block text-[17px]">Add the Paystack processing fee</b><small className="block text-[13px] text-muted-foreground">The student pays the price plus the fee, shown as its own line before paying, so you receive the full price. Used in the direct app and on the website.</small></span>
          <Switch name="paystack_on" checked={ps.on} onCheckedChange={(v) => setPay("on", v)} />
        </label>
        <div className="mt-4 grid grid-cols-2 gap-3 md:grid-cols-4">
          {field("paystack_pct", "Percent (%)", ps.pct, (n) => setPay("pct", n))}
          {field("paystack_flat", "Flat fee (₦)", ps.flat, (n) => setPay("flat", n), "1")}
          {field("paystack_flat_from", "Flat fee from (₦)", ps.flat_from, (n) => setPay("flat_from", n), "1")}
          {field("paystack_cap", "Fee cap (₦)", ps.cap, (n) => setPay("cap", n), "1")}
        </div>
        <p className="mt-2 text-xs text-muted-foreground">Paystack Nigeria today: 1.5% + ₦100 (no ₦100 under ₦2,500), capped at ₦2,000. Check your Paystack dashboard.</p>
        <ul className="mt-3 space-y-1 text-sm">
          {plans.map((p) => {
            const fee = paystackFee(p.price, { ...ps, on: true });
            return <li key={p.name} className="tnum">{p.name}: {ng(p.price)} {ps.on ? <>+ {ng(fee)} fee = <b>{ng(p.price + fee)}</b></> : <span className="text-muted-foreground">(fee off; with fee it would be {ng(p.price + fee)})</span>}</li>;
          })}
        </ul>
      </section>

      <section className="rounded-2xl border bg-card p-5 shadow-[var(--shadow-1)]">
        <label className="flex items-center gap-4">
          <span className="grow"><b className="block text-[17px]">Add Google’s fee on Google Play</b><small className="block text-[13px] text-muted-foreground">Google sets its price from Play Console, so each plan needs a second product priced with the fee. When this is on, the app sells that product.</small></span>
          <Switch name="google_on" checked={gs.on} onCheckedChange={(v) => setGoogle("on", v)} />
        </label>
        <div className="mt-4 max-w-[200px]">{field("google_pct", "Google’s fee (%)", gs.pct, (n) => setGoogle("pct", n), "1")}</div>
        <ul className="mt-3 space-y-1 text-sm">
          {plans.map((p) => {
            const price = Math.ceil(p.price / (1 - Math.min(gs.pct, 50) / 100) / 50) * 50;
            return <li key={p.name} className="tnum">{p.name}: set the second product to <b>{ng(price)}</b> in Play Console {p.fee_id ? <span className="font-mono text-xs text-muted-foreground">({p.fee_id})</span> : <span className="text-warning">· add its ID in Plans &amp; prices</span>}</li>;
          })}
        </ul>
        {gs.on && plans.some((p) => !p.fee_id) ? <p className="mt-2 text-xs text-muted-foreground">Plans without a second product keep selling the normal product.</p> : null}
      </section>
    </RowForm>
  );
}
