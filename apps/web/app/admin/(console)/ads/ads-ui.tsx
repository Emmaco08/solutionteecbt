"use client";
import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { inputCls } from "@/components/admin/row-form";
import { EmptyState, Pill } from "@/components/admin/ui";
import { saveAds } from "./actions";
import { BANNER_SCREENS, BREAK_SPOTS, EARN_SPOTS, type AdsSettings, type Format, type Rules } from "./ads-shared";

export type { AdsSettings } from "./ads-shared";
type Day = { day: string; banner: number | null; native: number | null; interstitial: number | null; rewarded_shown: number | null; unlocks: number | null; clicks: number | null };
export type AdsReport = { settings: Partial<AdsSettings> | null; days: Day[]; unlocks: Record<string, number>; loads?: Record<string, number> };

const LEVELS: { id: string; label: string; what: string }[] = [
  { id: "off", label: "Off", what: "No ads at all." },
  { id: "low", label: "Low", what: "Hardly noticed: no banners, one card in News, a video break after every 3rd test (2 a day, 15 min apart). Watch-to-earn always open." },
  { id: "medium", label: "Medium", what: "Banners on Study, News and AI tutor, 1 card on Home, cards every 8 items, a break after every 2nd test and after videos (4 a day), 'earn XP' video after tests." },
  { id: "high", label: "High", what: "Banners on most screens incl. Home, cards every 6, a break after every test and around videos (8 a day, 5 min), app-open ad after 4 h away, a sticky banner at the bottom, cards inside notes." },
  { id: "high_extra", label: "High Extra", what: "Banners also on results, review, Me and XP, cards every 4, breaks after notes, quizzes and every 3rd AI answer (12 a day, 3 min), app-open after 1 h." },
  { id: "max", label: "Max", what: "Cards every 3, breaks also when opening Study sections (18 a day, 2 min), app-open after 30 min, 'earn' videos at most breaks." },
  { id: "ultra", label: "Ultra", what: "The strongest AdMob allows: banners almost everywhere, a card every 2 items, 4 on Home, breaks at every natural break (25 a day, 90 s), random breaks between screens, sticky banners top and bottom, app-open after 5 min." },
  { id: "custom", label: "Custom", what: "You choose every placement below." },
];
const FORMATS: { id: Format; label: string; where: string }[] = [
  { id: "banner", label: "Banners", where: "At the top of screens, under the header" },
  { id: "native", label: "Card ads", where: "Look like a card on Home and between list items" },
  { id: "interstitial", label: "Break ads (full-screen video)", where: "After tests, around videos and at other breaks, with gaps and daily caps" },
  { id: "app_open", label: "App-open ads", where: "Full screen when a student comes back to the app after a while" },
  { id: "rewarded", label: "Watch to earn (rewarded video)", where: "AI prompts, XP, a locked year for a while, a Premium note, a streak freeze — always the student's choice" },
  { id: "rewarded_interstitial", label: "'Earn XP' break videos", where: "A skippable video offered at breaks that gives XP" },
];

const defaultRules: Rules = {
  banner_screens: ["study", "news", "ai"], home_cards: 1, native_every: 8, news_card: true, inter_every_tests: 2, inter_spots: ["video_end"],
  ai_every: 0, interstitial_gap_s: 480, interstitial_per_day: 4, app_open_after_min: 0, rint_spots: ["test"], rewarded_per_day: 8,
  banner_sticky: "off", random_break_pct: 0, note_cards_every: 0,
};
const defaults = (s: Partial<AdsSettings> | null): AdsSettings => ({
  level: s?.level ?? "off",
  test_mode: s?.test_mode ?? true,
  formats: { banner: true, native: true, interstitial: true, rewarded: true, app_open: true, rewarded_interstitial: true, ...(s?.formats ?? {}) },
  units: { banner: "", native: "", interstitial: "", rewarded: "", app_open: "", rewarded_interstitial: "", ...(s?.units ?? {}) },
  rewards: { ai_prompts: 2, note_hours: 24, streak_freeze: 1, year_ads: 1, year_minutes: 60, xp_ads: 1, xp_amount: 5, xp_daily_cap: 20, ...(s?.rewards ?? {}) },
  custom: { ...defaultRules, ...(s?.custom ?? {}) },
});

function Num({ label, value, onChange, min, max, hint }: { label: string; value: number; onChange: (n: number) => void; min: number; max: number; hint?: string }) {
  return (
    <label className="text-sm">
      {label}
      <input type="number" min={min} max={max} className={`${inputCls} mt-1 w-28`} value={value} onChange={(e) => onChange(Number(e.target.value))} />
      {hint ? <span className="mt-0.5 block text-xs text-muted-foreground">{hint}</span> : null}
    </label>
  );
}

function Checks({ items, value, onChange }: { items: { id: string; label: string }[]; value: string[]; onChange: (v: string[]) => void }) {
  return (
    <div className="mt-2 grid gap-2 sm:grid-cols-2 lg:grid-cols-3">
      {items.map((i) => (
        <label key={i.id} className="flex items-center gap-2 rounded-lg bg-sunken px-3 py-2 text-sm">
          <input type="checkbox" className="size-4" checked={value.includes(i.id)}
            onChange={(e) => onChange(e.target.checked ? [...value, i.id] : value.filter((x) => x !== i.id))} />
          {i.label}
        </label>
      ))}
    </div>
  );
}

export function AdsBoard({ r }: { r: AdsReport }) {
  const router = useRouter();
  const [v, setV] = useState<AdsSettings>(() => defaults(r.settings));
  const [pending, start] = useTransition();
  const c = v.custom;
  const setC = (p: Partial<Rules>) => setV({ ...v, custom: { ...c, ...p } });
  const rw = v.rewards;
  const setR = (p: Partial<AdsSettings["rewards"]>) => setV({ ...v, rewards: { ...rw, ...p } });
  const save = () => start(async () => {
    const res = await saveAds(v);
    if (res.ok) { toast.success(res.message ?? "Saved"); router.refresh(); } else toast.error(res.error);
  });
  const total = (k: keyof Day) => r.days.reduce((a, d) => a + (Number(d[k]) || 0), 0);
  return (
    <div className="space-y-8">
      <section className="rounded-2xl border border-border bg-card p-5">
        <h2 className="font-bold">Ads level</h2>
        <p className="text-sm text-muted-foreground">The app reads this when it opens, so no app update is needed. Premium students never see ads. Never during exams, CBT, challenges or checkout.</p>
        <div className="mt-4 grid gap-2 sm:grid-cols-2 lg:grid-cols-4">
          {LEVELS.map((l) => (
            <button key={l.id} type="button" onClick={() => setV({ ...v, level: l.id })}
              className={`rounded-xl border p-3 text-left transition ${v.level === l.id ? "border-primary bg-info-soft" : "border-border hover:bg-sunken"}`}>
              <span className="font-bold">{l.label}</span>
              <span className="mt-1 block text-xs text-muted-foreground">{l.what}</span>
            </button>
          ))}
        </div>
      </section>

      {v.level === "custom" ? (
        <section className="rounded-2xl border border-border bg-card p-5">
          <h2 className="font-bold">Custom level</h2>
          <h3 className="mt-4 text-sm font-bold">Banners on these screens</h3>
          <Checks items={BANNER_SCREENS} value={c.banner_screens} onChange={(x) => setC({ banner_screens: x })} />
          <label className="mt-3 flex flex-wrap items-center gap-2 text-sm">
            Sticky banner (stays on screen while scrolling, on every screen except exams, CBT, challenges and checkout):
            <select className="rounded-lg border border-border bg-background px-2 py-1" value={c.banner_sticky}
              onChange={(e) => setC({ banner_sticky: e.target.value as Rules["banner_sticky"] })}>
              <option value="off">Off</option><option value="top">Top</option><option value="bottom">Bottom</option><option value="both">Top and bottom</option>
            </select>
          </label>
          <h3 className="mt-6 text-sm font-bold">Card ads</h3>
          <div className="mt-2 flex flex-wrap gap-4">
            <Num label="Cards on Home" value={c.home_cards} min={0} max={6} onChange={(x) => setC({ home_cards: x })} />
            <Num label="A card after every N list items" value={c.native_every} min={0} max={30} hint="0 = no cards in lists" onChange={(x) => setC({ native_every: x })} />
            <Num label="Inside lesson notes: a card every N blocks" value={c.note_cards_every} min={0} max={30} hint="0 = none" onChange={(x) => setC({ note_cards_every: x })} />
            <label className="flex items-center gap-2 self-end text-sm"><input type="checkbox" className="size-4" checked={c.news_card} onChange={(e) => setC({ news_card: e.target.checked })} /> A card in News</label>
          </div>
          <h3 className="mt-6 text-sm font-bold">Break ads (full-screen video)</h3>
          <div className="mt-2 flex flex-wrap gap-4">
            <Num label="After every Nth test" value={c.inter_every_tests} min={0} max={10} hint="0 = never after tests" onChange={(x) => setC({ inter_every_tests: x })} />
            <Num label="At least seconds apart" value={c.interstitial_gap_s} min={60} max={3600} onChange={(x) => setC({ interstitial_gap_s: x })} />
            <Num label="At most per day" value={c.interstitial_per_day} min={0} max={40} onChange={(x) => setC({ interstitial_per_day: x })} />
            <Num label="Random break when changing screens (%)" value={c.random_break_pct} min={0} max={30} hint="0 = off; still gaps and caps" onChange={(x) => setC({ random_break_pct: x })} />
            <Num label="After every Nth AI answer" value={c.ai_every} min={0} max={20} hint="needs 'After AI answers'" onChange={(x) => setC({ ai_every: x })} />
          </div>
          <Checks items={BREAK_SPOTS} value={c.inter_spots} onChange={(x) => setC({ inter_spots: x })} />
          <h3 className="mt-6 text-sm font-bold">App-open ads and watch-to-earn</h3>
          <div className="mt-2 flex flex-wrap gap-4">
            <Num label="App-open after minutes away" value={c.app_open_after_min} min={0} max={1440} hint="0 = never" onChange={(x) => setC({ app_open_after_min: x })} />
            <Num label="Rewarded videos per day" value={c.rewarded_per_day} min={0} max={50} onChange={(x) => setC({ rewarded_per_day: x })} />
          </div>
          <p className="mt-3 text-sm">Offer a skippable &quot;earn XP&quot; video at:</p>
          <Checks items={EARN_SPOTS} value={c.rint_spots} onChange={(x) => setC({ rint_spots: x })} />
        </section>
      ) : null}

      <section className="rounded-2xl border border-border bg-card p-5">
        <h2 className="font-bold">Formats and ad unit ids</h2>
        <p className="text-sm text-muted-foreground">Create the units in AdMob (Apps → SolutionTee → Ad units) and paste their ids. In test mode Google&apos;s test ads are used.</p>
        <div className="mt-4 space-y-3">
          {FORMATS.map((f) => (
            <div key={f.id} className="flex flex-wrap items-center gap-3 rounded-xl bg-sunken p-3">
              <label className="flex min-w-60 flex-1 items-center gap-3">
                <input type="checkbox" className="size-5" checked={v.formats[f.id]} onChange={(e) => setV({ ...v, formats: { ...v.formats, [f.id]: e.target.checked } })} />
                <span><span className="font-bold">{f.label}</span><span className="block text-xs text-muted-foreground">{f.where}</span></span>
              </label>
              <input className={`${inputCls} min-w-72 flex-1 font-mono text-xs`} placeholder="ca-app-pub-…/…" value={v.units[f.id]}
                onChange={(e) => setV({ ...v, units: { ...v.units, [f.id]: e.target.value } })} />
            </div>
          ))}
        </div>
        <label className="mt-4 flex items-center gap-3">
          <input type="checkbox" className="size-5" checked={v.test_mode} onChange={(e) => setV({ ...v, test_mode: e.target.checked })} />
          <span><span className="font-bold">Test mode</span><span className="block text-xs text-muted-foreground">Google test ads; rewards are given without AdMob&apos;s server check. Keep on until the app is on Google Play and approved in AdMob.</span></span>
        </label>
      </section>

      <section className="rounded-2xl border border-border bg-card p-5">
        <h2 className="font-bold">Watch to earn</h2>
        <p className="text-sm text-muted-foreground">Premium is only for money or XP. XP from ads can be spent in the app but never on cash-prize entries (AdMob does not allow cash-like rewards).</p>
        <div className="mt-3 flex flex-wrap gap-4">
          <Num label="Videos to open a locked year" value={rw.year_ads} min={1} max={20} onChange={(x) => setR({ year_ads: x })} />
          <Num label="…open for minutes" value={rw.year_minutes} min={10} max={1440} onChange={(x) => setR({ year_minutes: x })} />
          <Num label="Videos for XP" value={rw.xp_ads} min={1} max={20} onChange={(x) => setR({ xp_ads: x })} />
          <Num label="…gives XP" value={rw.xp_amount} min={1} max={100} onChange={(x) => setR({ xp_amount: x })} />
          <Num label="XP videos per day" value={rw.xp_daily_cap} min={0} max={100} onChange={(x) => setR({ xp_daily_cap: x })} />
          <Num label="AI prompts per video" value={rw.ai_prompts} min={1} max={10} onChange={(x) => setR({ ai_prompts: x })} />
          <Num label="Premium note opens for (hours)" value={rw.note_hours} min={1} max={168} onChange={(x) => setR({ note_hours: x })} />
          <p className="self-end text-sm text-muted-foreground">Streak freeze: 1 per video, at most 2 held.</p>
        </div>
      </section>

      <div className="flex items-center gap-3">
        <Button onClick={save} disabled={pending}>{pending ? "Saving…" : "Save"}</Button>
        <Pill tone={v.level === "off" ? "neutral" : v.test_mode ? "warn" : "ok"}>{v.level === "off" ? "Off" : v.test_mode ? "Test ads" : "Live ads"}</Pill>
      </div>

      <section className="rounded-2xl border border-border bg-card p-5">
        <h2 className="font-bold">Last 30 days</h2>
        <p className="text-sm text-muted-foreground">Counted by the app. Money is in your AdMob account, which pays out.</p>
        <div className="mt-3 flex flex-wrap gap-2">
          <Pill tone="info">{total("banner") + total("native") + total("interstitial")} ads seen</Pill>
          <Pill tone="gold">{total("unlocks")} rewarded videos</Pill>
          {Object.entries(r.unlocks).map(([k, n]) => <Pill key={k}>{k.replace("_", " ")}: {n}</Pill>)}
        </div>
        {r.days.length ? (
          <div className="mt-4 overflow-x-auto">
            <table className="w-full text-sm">
              <thead className="text-left text-muted-foreground">
                <tr><th className="py-2">Day</th><th>Banners</th><th>Cards</th><th>Break ads</th><th>Rewarded shown</th><th>Rewards</th><th>Clicks</th></tr>
              </thead>
              <tbody>
                {r.days.map((d) => (
                  <tr key={d.day} className="border-t border-border">
                    <td className="py-2 font-bold">{d.day}</td><td>{d.banner ?? 0}</td><td>{d.native ?? 0}</td><td>{d.interstitial ?? 0}</td>
                    <td>{d.rewarded_shown ?? 0}</td><td>{d.unlocks ?? 0}</td><td>{d.clicks ?? 0}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        ) : <EmptyState title="No ads yet">Turn on a level and the numbers show here.</EmptyState>}
        {r.loads && Object.keys(r.loads).length ? (
          <details className="mt-4 text-sm">
            <summary className="cursor-pointer font-bold">Ad loading (last 7 days)</summary>
            <p className="mt-1 text-xs text-muted-foreground">#ok = loaded. #e3 = Google had no ad to show, #e2 = network, #e0/#e1 = setup problem.</p>
            <ul className="mt-2 grid gap-1 sm:grid-cols-2">
              {Object.entries(r.loads).sort().map(([k, n]) => <li key={k} className="font-mono text-xs">{k}: {n}</li>)}
            </ul>
          </details>
        ) : null}
      </section>
    </div>
  );
}
