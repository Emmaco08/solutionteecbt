"use client";
import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { Coins, Fire, Gift, MagnifyingGlass, ShoppingCart, SpinnerGap, Trophy } from "@phosphor-icons/react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { Switch } from "@/components/ui/switch";
import { inputCls } from "@/components/admin/row-form";
import { Pill, when } from "@/components/admin/ui";
import { adjustXp, findStudent, saveXpRules, type XpUser } from "./actions";

export type XpRules = {
  enabled: boolean; daily_claim: number; daily_cap: number; test: number; test_min_questions: number; test_min_seconds: number; tests_per_day: number;
  mock: number; mocks_per_day: number; score_bonus_per_10: number; qotd: number; qotd_right: number; challenge_finish: number; referral: number;
  challenge_top: number[]; weekly_top: number[]; milestones: Record<string, number>; freeze_price: number; freeze_max: number;
  repair_price: number; repair_on: boolean; premium_prices: Record<string, number>; packs: { xp: number; naira: number }[];
};
export type XpOverview = {
  settings: XpRules;
  totals: { in_wallets: number; earned: number; bought: number; students: number };
  days: { day: string; given: number; sold: number; spent: number; claims: number }[];
  by_reason: Record<string, number>;
  top: { user_id: string; name: string | null; email: string; earned: number; bought: number }[];
};

const REASON: Record<string, string> = {
  daily_claim: "Daily claim", test: "Tests", mock: "Mocks", qotd: "Question of the day", challenge: "Challenges", referral: "Friends invited",
  admin: "Given by admin", pack: "Bought", premium: "Premium with XP", entry: "Challenge entries", streak: "Streak bonus", freeze: "Streak freezes",
};
const fmt = (n: number) => n.toLocaleString("en-NG");

function Num({ label, value, onChange, hint, suffix = "XP" }: { label: string; value: number; onChange: (v: number) => void; hint?: string; suffix?: string }) {
  return (
    <label className="block space-y-1 text-sm">
      <span className="font-semibold">{label}</span>
      <span className="flex items-center gap-2">
        <input type="number" min={0} value={value} onChange={(e) => onChange(Math.max(0, Math.round(Number(e.target.value) || 0)))} className={`${inputCls} w-28 tabular-nums`} />
        <span className="text-xs text-muted-foreground">{suffix}</span>
      </span>
      {hint ? <span className="block text-xs text-muted-foreground">{hint}</span> : null}
    </label>
  );
}

function Section({ icon, title, children }: { icon: React.ReactNode; title: string; children: React.ReactNode }) {
  return (
    <section className="rounded-2xl border bg-card p-4">
      <h3 className="mb-3 flex items-center gap-2 text-sm font-bold"><span className="grid size-7 place-items-center rounded-lg bg-gold-soft text-on-gold-soft">{icon}</span>{title}</h3>
      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">{children}</div>
    </section>
  );
}

/** XP & streaks (D-081): totals, a 30-day chart of XP given vs spent, every rule, top students, one student's wallet. */
export function XpBoard({ d, plans }: { d: XpOverview; plans: { code: string; name: string }[] }) {
  const router = useRouter();
  const [pending, start] = useTransition();
  const [r, setR] = useState<XpRules>(d.settings);
  const set = <K extends keyof XpRules>(k: K) => (v: XpRules[K]) => setR({ ...r, [k]: v });
  const arr = (k: "challenge_top" | "weekly_top", i: number) => (v: number) => { const a = [...(r[k] ?? [])]; a[i] = v; setR({ ...r, [k]: a }); };
  const max = Math.max(1, ...d.days.map((x) => Math.max(x.given + x.sold, x.spent)));
  const given30 = d.days.reduce((n, x) => n + x.given + x.sold, 0), spent30 = d.days.reduce((n, x) => n + x.spent, 0);
  return (
    <div className="space-y-4">
      <div className="grid grid-cols-2 gap-2 lg:grid-cols-4">
        {[["XP in wallets", d.totals.in_wallets, <Coins key="c" size={20} />], ["Earned XP held", d.totals.earned, <Fire key="f" size={20} />],
          ["Bought XP held", d.totals.bought, <ShoppingCart key="s" size={20} />], ["Students with XP", d.totals.students, <Trophy key="t" size={20} />]].map(([l, v, ic]) => (
          <div key={String(l)} className="flex items-center gap-3 rounded-2xl border bg-card p-3">
            <span className="grid size-10 place-items-center rounded-xl bg-gold-soft text-on-gold-soft">{ic}</span>
            <span><span className="block text-xl font-bold tabular-nums">{fmt(Number(v))}</span><span className="text-xs text-muted-foreground">{l}</span></span>
          </div>
        ))}
      </div>

      <section className="rounded-2xl border bg-card p-4">
        <div className="mb-2 flex flex-wrap items-center gap-2">
          <h3 className="text-sm font-bold">Last 30 days: XP given vs spent</h3>
          <span className="ml-auto text-xs text-muted-foreground"><span className="mr-1 inline-block size-2 rounded-full bg-gold align-middle" />given {fmt(given30)} · <span className="mx-1 inline-block size-2 rounded-full bg-secondary align-middle" />spent {fmt(spent30)}</span>
        </div>
        {d.days.length ? (
          <div className="flex h-32 items-end gap-1">{d.days.map((x) => (
            <div key={x.day} className="flex flex-1 items-end gap-px" title={`${x.day}: given ${x.given + x.sold}, spent ${x.spent}, ${x.claims} daily claims`}>
              <div className="flex-1 rounded-t bg-gold" style={{ height: `${((x.given + x.sold) / max) * 120}px` }} />
              <div className="flex-1 rounded-t bg-secondary" style={{ height: `${(x.spent / max) * 120}px` }} />
            </div>
          ))}</div>
        ) : <p className="text-sm text-muted-foreground">No XP yet.</p>}
        <p className="mt-2 text-xs text-muted-foreground">When far more XP is given than spent for weeks, XP loses value: lower earning or add things to spend on.</p>
        {Object.keys(d.by_reason).length ? (
          <div className="mt-3 flex flex-wrap gap-1.5">{Object.entries(d.by_reason).sort((a, b) => Math.abs(b[1]) - Math.abs(a[1])).map(([k, v]) => (
            <span key={k} className={`rounded-full px-2 py-0.5 text-xs tabular-nums ${v < 0 ? "bg-info-soft text-on-info-soft" : "bg-sunken"}`}>{REASON[k] ?? k}: {v > 0 ? "+" : ""}{fmt(v)}</span>
          ))}</div>
        ) : null}
      </section>

      <form className="space-y-4" action={() => start(async () => { const x = await saveXpRules(r); if (x.ok) { toast.success(x.message ?? "Saved"); router.refresh(); } else toast.error(x.error); })}>
        <section className="flex flex-wrap items-center gap-3 rounded-2xl border bg-card p-4">
          <Switch checked={r.enabled} onCheckedChange={set("enabled")} aria-label="XP is on" />
          <div><b className="text-sm">XP is on</b><p className="text-xs text-muted-foreground">Off: XP is hidden in the app, nobody earns or spends it, challenge XP fees are ignored. Balances are kept.</p></div>
          <Button type="submit" className="ml-auto" disabled={pending}>{pending ? <SpinnerGap size={16} className="animate-spin" /> : null} Save rules</Button>
        </section>
        <Section icon={<Fire size={16} />} title="Earning">
          <Num label="Daily claim" value={r.daily_claim} onChange={set("daily_claim")} hint="First app open of the day" />
          <Num label="Test finished" value={r.test} onChange={set("test")} />
          <Num label="Full mock finished" value={r.mock} onChange={set("mock")} hint="JAMB 4 subjects / full paper" />
          <Num label="Score bonus per 10% above 50%" value={r.score_bonus_per_10} onChange={set("score_bonus_per_10")} />
          <Num label="Question of the day answered" value={r.qotd} onChange={set("qotd")} />
          <Num label="…and right" value={r.qotd_right} onChange={set("qotd_right")} hint="Added on top" />
          <Num label="Challenge or event finished" value={r.challenge_finish} onChange={set("challenge_finish")} />
          <Num label="Friend counted (referral)" value={r.referral} onChange={set("referral")} />
        </Section>
        <Section icon={<MagnifyingGlass size={16} />} title="Limits (stop farming)">
          <Num label="Most XP per day" value={r.daily_cap} onChange={set("daily_cap")} hint="Daily claim and streak bonuses are not counted" />
          <Num label="Tests that earn XP per day" value={r.tests_per_day} onChange={set("tests_per_day")} suffix="tests" />
          <Num label="Mocks that earn XP per day" value={r.mocks_per_day} onChange={set("mocks_per_day")} suffix="mocks" />
          <Num label="A test needs at least" value={r.test_min_questions} onChange={set("test_min_questions")} suffix="questions" />
          <Num label="…and at least" value={r.test_min_seconds} onChange={set("test_min_seconds")} suffix="seconds" />
        </Section>
        <Section icon={<Trophy size={16} />} title="Prizes in XP">
          {[0, 1, 2].map((i) => <Num key={`c${i}`} label={`Challenge ${["1st", "2nd", "3rd"][i]}`} value={r.challenge_top?.[i] ?? 0} onChange={arr("challenge_top", i)} />)}
          {[0, 1, 2].map((i) => <Num key={`w${i}`} label={`Weekly leaderboard ${["1st", "2nd", "3rd"][i]}`} value={r.weekly_top?.[i] ?? 0} onChange={arr("weekly_top", i)} hint={i === 0 ? "Given every Monday" : undefined} />)}
        </Section>
        <Section icon={<Fire size={16} />} title="Streaks">
          {Object.entries(r.milestones ?? {}).sort((a, b) => Number(a[0]) - Number(b[0])).map(([day, xp]) => (
            <Num key={day} label={`${day}-day streak bonus`} value={xp} onChange={(v) => setR({ ...r, milestones: { ...r.milestones, [day]: v } })} />
          ))}
          <Num label="Streak freeze price" value={r.freeze_price} onChange={set("freeze_price")} />
          <Num label="Freezes a student can hold" value={r.freeze_max} onChange={set("freeze_max")} suffix="freezes" />
          <label className="block space-y-1 text-sm"><span className="font-semibold">Streak repair</span>
            <span className="flex items-center gap-2"><Switch checked={r.repair_on} onCheckedChange={set("repair_on")} aria-label="Streak repair on" />
              <input type="number" min={0} value={r.repair_price} onChange={(e) => set("repair_price")(Math.max(0, Math.round(Number(e.target.value) || 0)))} className={`${inputCls} w-28 tabular-nums`} />
              <span className="text-xs text-muted-foreground">XP, within 24 h of losing it</span></span></label>
        </Section>
        <Section icon={<Gift size={16} />} title="Premium with XP">
          {plans.map((p) => <Num key={p.code} label={p.name} value={r.premium_prices?.[p.code] ?? 0} onChange={(v) => setR({ ...r, premium_prices: { ...r.premium_prices, [p.code]: v } })} hint="0 = not sold for XP" />)}
        </Section>
        <section className="rounded-2xl border bg-card p-4">
          <h3 className="mb-1 flex items-center gap-2 text-sm font-bold"><span className="grid size-7 place-items-center rounded-lg bg-gold-soft text-on-gold-soft"><ShoppingCart size={16} /></span>XP packs for money</h3>
          <p className="mb-3 text-xs text-muted-foreground">Bought XP can buy Premium, non-cash events and streak freezes — never entry to a cash-prize challenge (Google Play rules and Nigerian gaming law).</p>
          <div className="space-y-2">{(r.packs ?? []).map((p, i) => (
            <div key={i} className="flex flex-wrap items-center gap-2 text-sm">
              <input type="number" min={1} value={p.xp} aria-label="XP" onChange={(e) => { const a = [...r.packs]; a[i] = { ...p, xp: Math.max(1, Math.round(Number(e.target.value) || 1)) }; setR({ ...r, packs: a }); }} className={`${inputCls} w-28 tabular-nums`} />
              <span className="text-muted-foreground">XP for ₦</span>
              <input type="number" min={100} step={50} value={p.naira} aria-label="Price in naira" onChange={(e) => { const a = [...r.packs]; a[i] = { ...p, naira: Math.max(100, Math.round(Number(e.target.value) || 100)) }; setR({ ...r, packs: a }); }} className={`${inputCls} w-28 tabular-nums`} />
              <span className="text-xs text-muted-foreground">₦{(p.naira / Math.max(p.xp, 1)).toFixed(2)} per XP</span>
              <Button type="button" size="sm" variant="ghost" onClick={() => setR({ ...r, packs: r.packs.filter((_, j) => j !== i) })}>Remove</Button>
            </div>
          ))}</div>
          <Button type="button" size="sm" variant="outline" className="mt-2" onClick={() => setR({ ...r, packs: [...(r.packs ?? []), { xp: 500, naira: 500 }] })}>Add a pack</Button>
        </section>
        <div className="flex justify-end"><Button type="submit" disabled={pending}>{pending ? <SpinnerGap size={16} className="animate-spin" /> : null} Save rules</Button></div>
      </form>

      <div className="grid gap-4 lg:grid-cols-2">
        <section className="rounded-2xl border bg-card p-4">
          <h3 className="mb-2 text-sm font-bold">Top students by XP</h3>
          {d.top.length ? <ol className="space-y-1.5 text-sm">{d.top.map((t, i) => (
            <li key={t.user_id} className="flex items-center gap-2"><b className="w-6 tabular-nums">{i + 1}</b><span className="min-w-0 flex-1 truncate">{t.name ?? t.email}</span>
              <span className="font-bold tabular-nums">{fmt(t.earned + t.bought)}</span>{t.bought ? <span className="text-xs text-muted-foreground">({fmt(t.bought)} bought)</span> : null}</li>
          ))}</ol> : <p className="text-sm text-muted-foreground">Nobody has XP yet.</p>}
        </section>
        <StudentWallet />
      </div>
    </div>
  );
}

function StudentWallet() {
  const router = useRouter();
  const [q, setQ] = useState("");
  const [u, setU] = useState<XpUser | null | undefined>(undefined);
  const [amount, setAmount] = useState(100);
  const [reason, setReason] = useState("");
  const [pending, start] = useTransition();
  const find = () => start(async () => { const r = await findStudent(q); if (r.ok) setU(r.data ?? null); else toast.error(r.error); });
  return (
    <section className="rounded-2xl border bg-card p-4">
      <h3 className="mb-2 text-sm font-bold">A student&apos;s XP</h3>
      <form className="flex gap-2" action={find}>
        <input value={q} onChange={(e) => setQ(e.target.value)} placeholder="Email or name" className={`${inputCls} flex-1`} />
        <Button type="submit" variant="outline" disabled={pending}><MagnifyingGlass size={16} /> Find</Button>
      </form>
      {u === null ? <p className="mt-3 text-sm text-muted-foreground">No student found.</p> : null}
      {u ? (
        <div className="mt-3 space-y-3 text-sm">
          <div className="flex flex-wrap items-center gap-2"><b>{u.name ?? "No name"}</b><span className="text-xs text-muted-foreground">{u.email}</span>
            <Pill tone="gold">{fmt(u.earned + u.bought)} XP</Pill>{u.bought ? <Pill tone="info">{fmt(u.bought)} bought</Pill> : null}</div>
          <form className="flex flex-wrap gap-2" action={() => start(async () => {
            const r = await adjustXp(u.user_id, amount, reason);
            if (r.ok) { toast.success(r.message ?? "Done"); setReason(""); const again = await findStudent(u.email); if (again.ok) setU(again.data ?? null); router.refresh(); } else toast.error(r.error);
          })}>
            <input type="number" value={amount} onChange={(e) => setAmount(Math.round(Number(e.target.value) || 0))} aria-label="XP (use − to take away)" className={`${inputCls} w-28 tabular-nums`} />
            <input value={reason} onChange={(e) => setReason(e.target.value)} placeholder="Reason (the student sees it)" className={`${inputCls} min-w-40 flex-1`} />
            <Button type="submit" disabled={pending}>{amount < 0 ? "Take XP" : "Give XP"}</Button>
          </form>
          <ul className="max-h-72 divide-y overflow-auto rounded-xl border">{u.history.map((h, i) => (
            <li key={i} className="flex items-center gap-2 px-3 py-1.5">
              <span className={`w-16 font-bold tabular-nums ${h.amount > 0 ? "text-success" : "text-error"}`}>{h.amount > 0 ? "+" : ""}{fmt(h.amount)}</span>
              <span className="min-w-0 flex-1 truncate">{REASON[h.reason] ?? h.reason}{h.note ? ` · ${h.note}` : ""}{h.kind === "bought" ? " · bought" : ""}{h.by ? ` · by ${h.by}` : ""}</span>
              <span className="whitespace-nowrap text-xs text-muted-foreground">{when(h.at)}</span>
            </li>
          ))}</ul>
        </div>
      ) : null}
    </section>
  );
}
