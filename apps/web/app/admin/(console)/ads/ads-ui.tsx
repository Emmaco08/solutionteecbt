"use client";
import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { inputCls } from "@/components/admin/row-form";
import { EmptyState, Pill } from "@/components/admin/ui";
import { saveAds } from "./actions";

type Format = "banner" | "native" | "interstitial" | "rewarded";
export type AdsSettings = {
  level: string; test_mode: boolean;
  formats: Record<Format, boolean>; units: Record<Format, string>;
  rewards: { ai_prompts: number; note_hours: number; streak_freeze: number };
};
type Day = { day: string; banner: number | null; native: number | null; interstitial: number | null; rewarded_shown: number | null; unlocks: number | null; clicks: number | null };
export type AdsReport = { settings: Partial<AdsSettings> | null; days: Day[]; unlocks: Record<string, number> };

const LEVELS: { id: string; label: string; what: string }[] = [
  { id: "off", label: "Off", what: "No ads at all." },
  { id: "low", label: "Low", what: "A card ad every 12 list items, 2 break ads a day (10 min apart), 3 rewarded a day." },
  { id: "medium", label: "Medium", what: "Banners on Study and News, a card every 8 items, 4 break ads a day (6 min apart), 5 rewarded." },
  { id: "high", label: "High", what: "Banners on most lists, a card every 6 items, 6 break ads a day (4 min apart), 6 rewarded." },
  { id: "high_extra", label: "High Extra", what: "More banners, a card every 5 items, 8 break ads (3 min apart), also after videos, 8 rewarded." },
  { id: "max", label: "Max", what: "A card every 4 items, 10 break ads (2.5 min apart), 10 rewarded." },
  { id: "ultra", label: "Ultra", what: "A card every 3 items, 14 break ads (2 min apart), banners on Me too, 12 rewarded." },
];
const FORMATS: { id: Format; label: string; where: string }[] = [
  { id: "banner", label: "Banners", where: "At the top of lists, under the header" },
  { id: "native", label: "Card ads in lists", where: "Look like a card between items" },
  { id: "interstitial", label: "Break ads (full screen)", where: "After results, a challenge or a video, with gaps and daily caps" },
  { id: "rewarded", label: "Watch to unlock (rewarded)", where: "Extra AI prompts, a Premium note for a while, a streak freeze — always the student's choice" },
];

const defaults = (s: Partial<AdsSettings> | null): AdsSettings => ({
  level: s?.level ?? "off",
  test_mode: s?.test_mode ?? true,
  formats: { banner: true, native: true, interstitial: true, rewarded: true, ...(s?.formats ?? {}) },
  units: { banner: "", native: "", interstitial: "", rewarded: "", ...(s?.units ?? {}) },
  rewards: { ai_prompts: 2, note_hours: 24, streak_freeze: 1, ...(s?.rewards ?? {}) },
});

export function AdsBoard({ r }: { r: AdsReport }) {
  const router = useRouter();
  const [v, setV] = useState<AdsSettings>(() => defaults(r.settings));
  const [pending, start] = useTransition();
  const save = () => start(async () => {
    const res = await saveAds(v);
    if (res.ok) { toast.success(res.message ?? "Saved"); router.refresh(); } else toast.error(res.error);
  });
  const total = (k: keyof Day) => r.days.reduce((a, d) => a + (Number(d[k]) || 0), 0);
  return (
    <div className="space-y-8">
      <section className="rounded-2xl border border-border bg-card p-5">
        <h2 className="font-bold">Ads level</h2>
        <p className="text-sm text-muted-foreground">The app reads this when it opens, so no app update is needed.</p>
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

      <section className="rounded-2xl border border-border bg-card p-5">
        <h2 className="font-bold">Formats and ad unit ids</h2>
        <p className="text-sm text-muted-foreground">Create the units in AdMob (Apps → SolutionTee → Ad units) and paste their ids. Empty = Google&apos;s test ads.</p>
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
          <span><span className="font-bold">Test mode</span><span className="block text-xs text-muted-foreground">Google test ads, and rewards are given without AdMob&apos;s server check. Turn off before real ads.</span></span>
        </label>
      </section>

      <section className="rounded-2xl border border-border bg-card p-5">
        <h2 className="font-bold">Rewards for watching</h2>
        <div className="mt-3 flex flex-wrap gap-4">
          <label className="text-sm">Extra AI prompts per ad
            <input type="number" min={1} max={10} className={`${inputCls} mt-1 w-28`} value={v.rewards.ai_prompts} onChange={(e) => setV({ ...v, rewards: { ...v.rewards, ai_prompts: Number(e.target.value) } })} />
          </label>
          <label className="text-sm">Premium note opens for (hours)
            <input type="number" min={1} max={168} className={`${inputCls} mt-1 w-28`} value={v.rewards.note_hours} onChange={(e) => setV({ ...v, rewards: { ...v.rewards, note_hours: Number(e.target.value) } })} />
          </label>
          <p className="self-end text-sm text-muted-foreground">Streak freeze: 1 per ad, at most 2 held.</p>
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
          <Pill tone="gold">{total("unlocks")} rewarded unlocks</Pill>
          {Object.entries(r.unlocks).map(([k, n]) => <Pill key={k}>{k.replace("_", " ")}: {n}</Pill>)}
        </div>
        {r.days.length ? (
          <div className="mt-4 overflow-x-auto">
            <table className="w-full text-sm">
              <thead className="text-left text-muted-foreground">
                <tr><th className="py-2">Day</th><th>Banners</th><th>Cards</th><th>Break ads</th><th>Rewarded shown</th><th>Unlocks</th><th>Clicks</th></tr>
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
      </section>
    </div>
  );
}
