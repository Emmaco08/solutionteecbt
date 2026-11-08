"use client";
import { useState, useTransition } from "react";
import { toast } from "sonner";
import { ArrowSquareOut, Plus, Trash } from "@phosphor-icons/react";
import { Button } from "@/components/ui/button";
import { Switch } from "@/components/ui/switch";
import { Panel } from "@/components/admin/ui";
import { CMS_DEFAULTS, SECTION_KEYS, SECTION_LABELS, rewardsWords, type SiteCms } from "@/lib/site-cms";
import { saveSiteCms } from "./actions";

const field = "block w-full rounded-xl border border-input bg-card px-3.5 py-2.5 text-sm outline-none focus-visible:ring-2 focus-visible:ring-ring";

function Text({ label, value, onChange, rows, hint }: { label: string; value: string; onChange: (v: string) => void; rows?: number; hint?: string }) {
  return (
    <label className="block space-y-1.5">
      <span className="text-sm font-bold">{label}</span>
      {rows ? <textarea className={field} rows={rows} value={value} onChange={(e) => onChange(e.target.value)} />
        : <input className={field} value={value} onChange={(e) => onChange(e.target.value)} />}
      {hint ? <span className="block text-xs text-muted-foreground">{hint}</span> : null}
    </label>
  );
}

function Points({ value, onChange }: { value: string[]; onChange: (v: string[]) => void }) {
  return (
    <div className="space-y-2">
      <span className="text-sm font-bold">Points (up to 5)</span>
      {value.map((p, i) => (
        <div key={i} className="flex gap-2">
          <input className={field} value={p} onChange={(e) => onChange(value.map((x, j) => (j === i ? e.target.value : x)))} />
          <Button type="button" variant="outline" size="icon" aria-label="Remove point" onClick={() => onChange(value.filter((_, j) => j !== i))}><Trash size={16} /></Button>
        </div>
      ))}
      {value.length < 5 ? <Button type="button" variant="outline" size="sm" onClick={() => onChange([...value, ""])}><Plus size={16} /> Add a point</Button> : null}
    </div>
  );
}

/** admin → Website (D-122): the CMS for cbt.solutiontee.com. */
export function WebsiteEditor({ initial, cash, teens }: { initial: SiteCms; cash: boolean; teens: boolean }) {
  const [c, setC] = useState<SiteCms>(initial);
  const [pending, start] = useTransition();
  const set = <K extends keyof SiteCms>(k: K, v: SiteCms[K]) => setC((x) => ({ ...x, [k]: v }));
  const dirty = JSON.stringify(c) !== JSON.stringify(initial);
  function save() {
    start(async () => {
      const r = await saveSiteCms(c);
      if (r.ok) toast.success(r.message ?? "Saved"); else toast.error(r.error);
    });
  }
  return (
    <div className="space-y-4 pb-24">
      <p className="rounded-xl border bg-card p-3 text-sm text-muted-foreground">
        Words you can use in any text: <code>{"{rewards}"}</code> (now: <b>{rewardsWords({ cash })}</b>, follows the cash prize switches),{" "}
        <code>{"{pct}"}</code>, <code>{"{maxPct}"}</code>, <code>{"{xp}"}</code>, <code>{"{finishXp}"}</code>, <code>{"{cashNaira}"}</code>, <code>{"{cashEvery}"}</code>,{" "}
        <code>{"{questions}"}</code>, <code>{"{firstYear}"}</code>, <code>{"{lastYear}"}</code>. Cash prizes are <b>{cash ? (teens ? "on for 13+" : "on for 18+") : "off"}</b>
        {" "}(Flags &amp; settings → Legal switches). The Privacy Policy and Terms follow that switch by themselves.
      </p>

      <div className="grid gap-4 xl:grid-cols-2">
        <Panel title="Sections on the website" bodyClassName="divide-y py-1">
          {SECTION_KEYS.map((k) => (
            <label key={k} className="flex cursor-pointer items-center gap-4 py-3">
              <span className="grow text-sm font-bold">{SECTION_LABELS[k]}</span>
              <Switch checked={c.sections[k]} aria-label={SECTION_LABELS[k]} onCheckedChange={(v) => set("sections", { ...c.sections, [k]: v })} />
            </label>
          ))}
        </Panel>

        <div className="space-y-4">
          <Panel title="Announcement bar (top of the page)">
            <div className="space-y-3">
              <label className="flex cursor-pointer items-center gap-4"><span className="grow text-sm font-bold">Show the bar</span>
                <Switch checked={c.announcement.on} aria-label="Show the announcement bar" onCheckedChange={(v) => set("announcement", { ...c.announcement, on: v })} /></label>
              <Text label="Text" value={c.announcement.text} onChange={(v) => set("announcement", { ...c.announcement, text: v })} hint="Short, for example: Weekly JAMB challenge this Saturday at 7 pm. Free to join!" />
              <Text label="Link (optional)" value={c.announcement.link} onChange={(v) => set("announcement", { ...c.announcement, link: v })} hint="Starts with https:// or / (for example /pay or #challenges)." />
            </div>
          </Panel>
          <Panel title="Top of the page (hero)">
            <div className="space-y-3">
              <Text label="Small badge" value={c.hero.badge} onChange={(v) => set("hero", { ...c.hero, badge: v })} />
              <div className="grid gap-3 sm:grid-cols-2">
                <Text label="Headline" value={c.hero.title} onChange={(v) => set("hero", { ...c.hero, title: v })} />
                <Text label="Gold words at the end" value={c.hero.highlight} onChange={(v) => set("hero", { ...c.hero, highlight: v })} />
              </div>
              <Text label="Text under the headline" rows={3} value={c.hero.subtitle} onChange={(v) => set("hero", { ...c.hero, subtitle: v })} />
            </div>
          </Panel>
        </div>

        {(["invite", "challenges"] as const).map((k) => (
          <Panel key={k} title={k === "invite" ? "Invite friends and earn" : "Practise in challenges and win"}>
            <div className="space-y-3">
              <Text label="Small heading" value={c[k].eyebrow} onChange={(v) => set(k, { ...c[k], eyebrow: v })} />
              <Text label="Title" value={c[k].title} onChange={(v) => set(k, { ...c[k], title: v })} />
              <Text label="Text" rows={3} value={c[k].text} onChange={(v) => set(k, { ...c[k], text: v })} />
              <Points value={c[k].points} onChange={(v) => set(k, { ...c[k], points: v })} />
              <p className="text-xs text-muted-foreground">The phone shows the real {k === "invite" ? "Invite friends" : "Challenges"} screen; it shows cash only while cash prizes are on.</p>
            </div>
          </Panel>
        ))}

        <Panel title="Start in three steps">
          <div className="space-y-3">
            <Text label="Title" value={c.how.title} onChange={(v) => set("how", { ...c.how, title: v })} />
            {c.how.steps.map((st, i) => (
              <div key={i} className="grid gap-2 rounded-xl border p-3 sm:grid-cols-[1fr_2fr]">
                <Text label={`Step ${i + 1}`} value={st.title} onChange={(v) => set("how", { ...c.how, steps: c.how.steps.map((x, j) => (j === i ? { ...x, title: v } : x)) })} />
                <Text label="Text" value={st.text} onChange={(v) => set("how", { ...c.how, steps: c.how.steps.map((x, j) => (j === i ? { ...x, text: v } : x)) })} />
              </div>
            ))}
          </div>
        </Panel>

        <Panel title="Download box and footer">
          <div className="space-y-3">
            <Text label="Download title" value={c.download.title} onChange={(v) => set("download", { ...c.download, title: v })} />
            <Text label="Download text" rows={2} value={c.download.text} onChange={(v) => set("download", { ...c.download, text: v })} />
            <Text label="Footer line" value={c.footer.tagline} onChange={(v) => set("footer", { tagline: v })} />
          </div>
        </Panel>

        <Panel title="Questions students ask (FAQ)" className="xl:col-span-2">
          <div className="space-y-3">
            <Text label="Title" value={c.faq.title} onChange={(v) => set("faq", { ...c.faq, title: v })} />
            {c.faq.items.map((it, i) => (
              <div key={i} className="grid gap-2 rounded-xl border p-3 md:grid-cols-[1fr_2fr_auto] md:items-end">
                <Text label={`Question ${i + 1}`} value={it.q} onChange={(v) => set("faq", { ...c.faq, items: c.faq.items.map((x, j) => (j === i ? { ...x, q: v } : x)) })} />
                <Text label="Answer" rows={2} value={it.a} onChange={(v) => set("faq", { ...c.faq, items: c.faq.items.map((x, j) => (j === i ? { ...x, a: v } : x)) })} />
                <Button type="button" variant="outline" size="icon" aria-label="Remove question" onClick={() => set("faq", { ...c.faq, items: c.faq.items.filter((_, j) => j !== i) })}><Trash size={16} /></Button>
              </div>
            ))}
            {c.faq.items.length < 15 ? <Button type="button" variant="outline" size="sm" onClick={() => set("faq", { ...c.faq, items: [...c.faq.items, { q: "", a: "" }] })}><Plus size={16} /> Add a question</Button> : null}
          </div>
        </Panel>
      </div>

      <div className="fixed inset-x-0 bottom-0 z-40 border-t bg-background/95 backdrop-blur lg:left-[var(--sidebar-w,0px)]">
        <div className="mx-auto flex max-w-6xl flex-wrap items-center justify-end gap-2 px-4 py-3">
          <a href="https://cbt.solutiontee.com" target="_blank" rel="noreferrer" className="mr-auto inline-flex items-center gap-1.5 text-sm font-bold text-secondary">Open the website <ArrowSquareOut size={16} /></a>
          <Button type="button" variant="outline" onClick={() => { if (window.confirm("Put every text back to the original words? (Save to keep it.)")) setC({ ...CMS_DEFAULTS, sections: c.sections }); }}>Original words</Button>
          <Button type="button" variant="outline" disabled={!dirty || pending} onClick={() => setC(initial)}>Undo changes</Button>
          <Button type="button" disabled={!dirty || pending} onClick={save}>{pending ? "Saving…" : "Save website"}</Button>
        </div>
      </div>
    </div>
  );
}
