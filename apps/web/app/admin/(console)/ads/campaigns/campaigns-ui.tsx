"use client";
import { useEffect, useRef, useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { FileVideo, ImageSquare, SpinnerGap, Trash } from "@phosphor-icons/react";
import { Button } from "@/components/ui/button";
import { inputCls } from "@/components/admin/row-form";
import { EmptyState, Pill } from "@/components/admin/ui";
import { faststart } from "@/lib/mp4-faststart";
import { campaignReport, deleteCampaign, saveCampaign } from "./actions";
import { PLACEMENTS, type Campaign, type CampaignReport } from "./shared";

const blank: Campaign = {
  brand: "", name: "", status: "draft", starts_on: null, ends_on: null, placements: ["banner", "card"],
  share_pct: 50, cap_per_day: 3, weight: 1, link: "", cta: "Learn more",
  banner_key: null, card_key: null, card_title: "", card_body: "", break_kind: "image", break_key: null, video_key: null, skip_after_s: 5,
};

const tone = (c: Campaign) => (c.live ? "ok" : c.status === "active" ? "warn" : "neutral") as "ok" | "warn" | "neutral";
const pct = (a: number, b: number) => (b > 0 ? `${((100 * a) / b).toFixed(1)}%` : "–");

/** Uploads one picture or video to R2 (public/ads/…) and returns its key. */
function AdFile({ label, value, video, onChange }: { label: string; value: string | null; video?: boolean; onChange: (k: string | null) => void }) {
  const [busy, setBusy] = useState(false);
  const [local, setLocal] = useState("");
  const input = useRef<HTMLInputElement>(null);
  const preview = local || (value ? `/admin/api/image?key=${encodeURIComponent(value)}` : "");
  async function onFile(f: File) {
    setBusy(true);
    try {
      const body: Blob = video ? (await faststart(f)).blob : f;
      const r = await fetch("/admin/api/upload", {
        method: "POST", headers: { "content-type": "application/json" },
        body: JSON.stringify({ kind: video ? "ad_video" : "ad_image", contentType: f.type, size: body.size }),
      });
      const j = await r.json();
      if (!r.ok) throw new Error(j.error ?? "Upload failed");
      const put = await fetch(j.url, { method: "PUT", headers: { "content-type": f.type }, body });
      if (!put.ok) throw new Error("Upload to storage failed. Check the R2 CORS settings.");
      setLocal(URL.createObjectURL(f));
      onChange(j.key);
      toast.success(video ? "Video uploaded." : "Picture uploaded.");
    } catch (e) {
      toast.error(e instanceof Error ? e.message : "Upload failed");
    } finally {
      setBusy(false);
    }
  }
  return (
    <div className="rounded-xl bg-sunken p-3">
      <p className="text-sm font-bold">{label}</p>
      <input ref={input} type="file" className="hidden" accept={video ? "video/mp4" : "image/webp,image/png,image/jpeg,image/gif"}
        onChange={(e) => { const f = e.target.files?.[0]; if (f) onFile(f); e.target.value = ""; }} />
      <div className="mt-2 flex items-center gap-3">
        {preview ? (
          video ? <video src={preview} className="h-20 w-32 rounded-lg bg-black object-contain" muted controls /> : <img src={preview} alt={label} className="h-20 max-w-48 rounded-lg border bg-white object-contain" />
        ) : (
          <div className="grid h-20 w-32 place-items-center rounded-lg border border-dashed text-subtle">{video ? <FileVideo size={26} /> : <ImageSquare size={26} />}</div>
        )}
        <div className="flex flex-col gap-2">
          <Button type="button" variant="outline" size="sm" disabled={busy} onClick={() => input.current?.click()}>
            {busy ? <SpinnerGap size={16} className="animate-spin" /> : null} {value ? "Replace" : "Upload"}
          </Button>
          {value ? <Button type="button" variant="ghost" size="sm" onClick={() => { setLocal(""); onChange(null); }}><Trash size={16} /> Remove</Button> : null}
        </div>
      </div>
    </div>
  );
}

function Editor({ start, onClose }: { start: Campaign; onClose: () => void }) {
  const [c, setC] = useState<Campaign>(start);
  const [pending, run] = useTransition();
  const router = useRouter();
  const set = (p: Partial<Campaign>) => setC((x) => ({ ...x, ...p }));
  const has = (id: string) => c.placements.includes(id);
  const video = has("video_pre") || has("video_mid") || has("video_post");
  const save = () => run(async () => {
    const r = await saveCampaign(c);
    if (r.ok) { toast.success(r.message ?? "Saved"); router.refresh(); onClose(); } else toast.error(r.error);
  });
  return (
    <section className="space-y-5 rounded-2xl border border-primary bg-card p-5">
      <h2 className="font-bold">{c.id ? "Edit campaign" : "New brand campaign"}</h2>
      <div className="grid gap-4 sm:grid-cols-2">
        <label className="text-sm">Brand<input className={`${inputCls} mt-1`} value={c.brand} maxLength={80} onChange={(e) => set({ brand: e.target.value })} /></label>
        <label className="text-sm">Campaign name<input className={`${inputCls} mt-1`} value={c.name} maxLength={120} onChange={(e) => set({ name: e.target.value })} /></label>
        <label className="text-sm">Starts on<input type="date" className={`${inputCls} mt-1`} value={c.starts_on ?? ""} onChange={(e) => set({ starts_on: e.target.value || null })} /></label>
        <label className="text-sm">Ends on<input type="date" className={`${inputCls} mt-1`} value={c.ends_on ?? ""} onChange={(e) => set({ ends_on: e.target.value || null })} /></label>
        <label className="text-sm">Link when tapped (https://)<input className={`${inputCls} mt-1`} value={c.link ?? ""} placeholder="https://brand.com/offer" onChange={(e) => set({ link: e.target.value })} /></label>
        <label className="text-sm">Button text<input className={`${inputCls} mt-1`} value={c.cta} maxLength={24} onChange={(e) => set({ cta: e.target.value })} /></label>
      </div>

      <div>
        <h3 className="text-sm font-bold">Where it shows</h3>
        <div className="mt-2 grid gap-2 sm:grid-cols-2 lg:grid-cols-3">
          {PLACEMENTS.map((p) => (
            <label key={p.id} className="flex items-start gap-2 rounded-lg bg-sunken px-3 py-2 text-sm">
              <input type="checkbox" className="mt-0.5 size-4" checked={has(p.id)}
                onChange={(e) => set({ placements: e.target.checked ? [...c.placements, p.id] : c.placements.filter((x) => x !== p.id) })} />
              <span>{p.label}<span className="block text-xs text-muted-foreground">{p.needs}</span></span>
            </label>
          ))}
        </div>
        <p className="mt-2 text-xs text-muted-foreground">
          Banners, cards and breaks use the ad slots the ads level already has. Video-lesson ads show where the level has a break before / after videos (High and up, or Custom).
        </p>
      </div>

      <div className="flex flex-wrap gap-4">
        <label className="text-sm">Share of those slots (%)<input type="number" min={1} max={100} className={`${inputCls} mt-1 w-28`} value={c.share_pct} onChange={(e) => set({ share_pct: Number(e.target.value) })} /><span className="block text-xs text-muted-foreground">the rest stays AdMob</span></label>
        <label className="text-sm">Views per student per day<input type="number" min={1} max={50} className={`${inputCls} mt-1 w-28`} value={c.cap_per_day} onChange={(e) => set({ cap_per_day: Number(e.target.value) })} /></label>
        <label className="text-sm">Weight (1–10)<input type="number" min={1} max={10} className={`${inputCls} mt-1 w-28`} value={c.weight} onChange={(e) => set({ weight: Number(e.target.value) })} /><span className="block text-xs text-muted-foreground">when brands overlap</span></label>
        {video || (has("break") && c.break_kind === "video") ? (
          <label className="text-sm">Skip after seconds<input type="number" min={0} max={30} className={`${inputCls} mt-1 w-28`} value={c.skip_after_s} onChange={(e) => set({ skip_after_s: Number(e.target.value) })} /></label>
        ) : null}
      </div>

      <div className="grid gap-3 lg:grid-cols-2">
        {has("banner") ? <AdFile label="Banner picture" value={c.banner_key} onChange={(k) => set({ banner_key: k })} /> : null}
        {has("card") ? (
          <div className="space-y-2">
            <AdFile label="Card picture (square or 4:3)" value={c.card_key} onChange={(k) => set({ card_key: k })} />
            <input className={inputCls} placeholder="Card title (max 60)" maxLength={60} value={c.card_title ?? ""} onChange={(e) => set({ card_title: e.target.value })} />
            <input className={inputCls} placeholder="Card text (max 140)" maxLength={140} value={c.card_body ?? ""} onChange={(e) => set({ card_body: e.target.value })} />
          </div>
        ) : null}
        {has("break") ? (
          <div className="space-y-2">
            <select className={inputCls} value={c.break_kind} onChange={(e) => set({ break_kind: e.target.value as "image" | "video", break_key: null })}>
              <option value="image">Break: a full-screen picture (portrait, e.g. 1080 × 1920)</option>
              <option value="video">Break: a short video (MP4, 15–30 s)</option>
            </select>
            <AdFile key={c.break_kind} label="Full-screen break" video={c.break_kind === "video"} value={c.break_key} onChange={(k) => set({ break_key: k })} />
          </div>
        ) : null}
        {video ? <AdFile label="Video-lesson ad (MP4, 15–30 s)" video value={c.video_key} onChange={(k) => set({ video_key: k })} /> : null}
      </div>

      <div className="flex flex-wrap items-center gap-3">
        <label className="text-sm">Status
          <select className={`${inputCls} ml-2 inline-block w-40`} value={c.status} onChange={(e) => set({ status: e.target.value as Campaign["status"] })}>
            <option value="draft">Draft</option><option value="active">On</option><option value="paused">Paused</option><option value="ended">Ended</option>
          </select>
        </label>
        <Button onClick={save} disabled={pending}>{pending ? "Saving…" : "Save campaign"}</Button>
        <Button variant="ghost" onClick={onClose}>Cancel</Button>
      </div>
    </section>
  );
}

function Report({ id, onClose }: { id: string; onClose: () => void }) {
  const [r, setR] = useState<CampaignReport | null | undefined>(undefined);
  useEffect(() => { campaignReport(id).then(setR); }, [id]);
  if (r === undefined) return <p className="text-sm text-muted-foreground">Loading the report…</p>;
  if (r === null) return <p className="text-sm text-error">Could not load the report.</p>;
  const views = r.rows.reduce((a, x) => a + x.views, 0), clicks = r.rows.reduce((a, x) => a + x.clicks, 0);
  const csv = () => {
    const lines = ["day,placement,views,clicks", ...r.rows.map((x) => `${x.day},${x.placement},${x.views},${x.clicks}`)];
    const a = document.createElement("a");
    a.href = URL.createObjectURL(new Blob([lines.join("\n")], { type: "text/csv" }));
    a.download = `${r.campaign.brand}-${r.campaign.name}-report.csv`.replace(/[^\w.-]+/g, "_");
    a.click();
  };
  return (
    <section className="rounded-2xl border border-border bg-card p-5">
      <div className="flex flex-wrap items-center gap-3">
        <h2 className="font-bold">Report: {r.campaign.brand} · {r.campaign.name}</h2>
        <span className="text-sm text-muted-foreground">{views.toLocaleString()} views · {clicks.toLocaleString()} clicks · {pct(clicks, views)} click rate · {r.students.toLocaleString()} students reached</span>
        <Button size="sm" variant="outline" onClick={csv} disabled={!r.rows.length}>Download CSV for the brand</Button>
        <Button size="sm" variant="ghost" onClick={onClose}>Close</Button>
      </div>
      {r.rows.length ? (
        <div className="mt-3 overflow-x-auto">
          <table className="w-full text-sm">
            <thead><tr className="text-left text-muted-foreground"><th className="py-1">Day</th><th>Place</th><th className="text-right">Views</th><th className="text-right">Clicks</th><th className="text-right">Click rate</th></tr></thead>
            <tbody>
              {r.rows.map((x) => (
                <tr key={`${x.day}-${x.placement}`} className="border-t border-border">
                  <td className="py-1">{x.day}</td><td>{PLACEMENTS.find((p) => p.id === x.placement)?.label ?? x.placement}</td>
                  <td className="text-right tabular-nums">{x.views}</td><td className="text-right tabular-nums">{x.clicks}</td><td className="text-right tabular-nums">{pct(x.clicks, x.views)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      ) : <p className="mt-3 text-sm text-muted-foreground">No views yet.</p>}
    </section>
  );
}

export function CampaignsBoard({ list }: { list: Campaign[] }) {
  const [edit, setEdit] = useState<Campaign | null>(null);
  const [report, setReport] = useState<string | null>(null);
  const [pending, run] = useTransition();
  const router = useRouter();
  const del = (c: Campaign) => {
    if (!c.id || !confirm(`Delete "${c.name}" and its report? This cannot be undone.`)) return;
    run(async () => {
      const r = await deleteCampaign(c.id!);
      if (r.ok) { toast.success(r.message ?? "Deleted"); router.refresh(); } else toast.error(r.error);
    });
  };
  return (
    <div className="space-y-6">
      {edit ? <Editor key={edit.id ?? "new"} start={edit} onClose={() => setEdit(null)} /> : <Button onClick={() => setEdit(blank)}>New brand campaign</Button>}
      {report ? <Report key={report} id={report} onClose={() => setReport(null)} /> : null}
      {list.length === 0 ? (
        <EmptyState title="No brand campaigns yet">Add a brand&apos;s banner, card, break or video ad. It shares the ad slots with AdMob.</EmptyState>
      ) : (
        <div className="space-y-3">
          {list.map((c) => (
            <div key={c.id} className="flex flex-wrap items-center gap-3 rounded-2xl border border-border bg-card p-4">
              <div className="min-w-60 flex-1">
                <p className="font-bold">{c.brand} · {c.name} <Pill tone={tone(c)}>{c.live ? "Running" : c.status === "active" ? "On (outside its dates)" : c.status}</Pill></p>
                <p className="text-xs text-muted-foreground">
                  {c.placements.map((p) => PLACEMENTS.find((x) => x.id === p)?.label ?? p).join(", ") || "No places"} · {c.share_pct}% share · {c.cap_per_day}/student/day
                  {c.starts_on || c.ends_on ? ` · ${c.starts_on ?? "…"} to ${c.ends_on ?? "…"}` : ""}
                </p>
              </div>
              <span className="text-sm tabular-nums">{(c.views ?? 0).toLocaleString()} views · {(c.clicks ?? 0).toLocaleString()} clicks · {pct(c.clicks ?? 0, c.views ?? 0)}</span>
              <Button size="sm" variant="outline" onClick={() => setReport(c.id!)}>Report</Button>
              <Button size="sm" variant="outline" onClick={() => setEdit(c)}>Edit</Button>
              <Button size="sm" variant="ghost" disabled={pending} onClick={() => del(c)}><Trash size={16} /></Button>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
