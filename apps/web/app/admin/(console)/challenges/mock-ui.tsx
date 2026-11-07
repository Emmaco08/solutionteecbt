"use client";
import { useEffect, useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { ArrowClockwise, DownloadSimple, SpinnerGap, Trash } from "@phosphor-icons/react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { Label } from "@/components/ui/label";
import { inputCls } from "@/components/admin/row-form";
import { Pill, when } from "@/components/admin/ui";
import { deleteInvite, makeInvites, mockAnalytics, mockTimeline, setSharedCode, type MockAnalytics } from "./actions";

// JAMB mock challenges (D-099): access codes and the teacher's analysis.

export type InviteRow = { id: string; label: string; code_hint: string | null; claimed_at: string | null; user_id: string | null };

const csvCell = (v: unknown) => {
  const t = String(v ?? "");
  return /[",\n]/.test(t) ? `"${t.replace(/"/g, '""')}"` : t;
};
function download(name: string, rows: unknown[][]) {
  const blob = new Blob([rows.map((r) => r.map(csvCell).join(",")).join("\n")], { type: "text/csv" });
  const a = document.createElement("a");
  a.href = URL.createObjectURL(blob);
  a.download = name;
  a.click();
  URL.revokeObjectURL(a.href);
}
const mins = (ms: number | null | undefined) => (ms ? `${Math.floor(ms / 60000)}m ${Math.round((ms % 60000) / 1000)}s` : "0s");

export function AccessPanel({ challengeId, title, access, hasCode, invites }: { challengeId: string; title: string; access: string; hasCode: boolean; invites: InviteRow[] }) {
  const router = useRouter();
  const [pending, start] = useTransition();
  const [names, setNames] = useState("");
  const [code, setCode] = useState("");
  const [made, setMade] = useState<{ label: string; code: string }[]>([]);
  const used = invites.filter((i) => i.claimed_at).length;
  return (
    <div className="space-y-4">
      <p className="text-sm text-muted-foreground">
        {access === "open" ? "Every student can enter. " : access === "premium" ? "Only Premium students can enter. " : access === "code" ? "Students enter with the shared code or a personal code. " : "Only students with a personal code can enter. "}
        Change this in the challenge settings.
      </p>
      {access === "code" ? (
        <div className="space-y-1.5">
          <Label htmlFor="sc">Shared code {hasCode ? <Pill tone="ok">set</Pill> : <Pill tone="warn">not set</Pill>}</Label>
          <div className="flex gap-2">
            <input id="sc" value={code} onChange={(e) => setCode(e.target.value)} placeholder="Type a new shared code" className={inputCls} />
            <Button type="button" disabled={pending || code.trim().length < 4} onClick={() => start(async () => {
              const r = await setSharedCode(challengeId, code);
              if (r.ok) { toast.success(r.message ?? "Saved"); setCode(""); router.refresh(); } else toast.error(r.error);
            })}>Save</Button>
          </div>
        </div>
      ) : null}
      {access === "code" || access === "invite" ? (
        <>
          <div className="space-y-1.5">
            <Label htmlFor="names">Personal codes: one student per line (name, class or phone)</Label>
            <textarea id="names" rows={5} value={names} onChange={(e) => setNames(e.target.value)} placeholder={"Ada Obi · SS3A\nTunde Bello · SS3B"} className={inputCls} />
            <div className="flex flex-wrap items-center gap-2">
              <Button type="button" disabled={pending || !names.trim()} onClick={() => start(async () => {
                const r = await makeInvites(challengeId, names);
                if (r.ok && r.data) { setMade(r.data); setNames(""); toast.success(r.message ?? "Made"); router.refresh(); } else if (!r.ok) toast.error(r.error);
              })}>{pending ? <SpinnerGap size={16} className="animate-spin" /> : null} Make codes</Button>
              <span className="text-xs text-muted-foreground">Each code works for one student only: the first student who uses it.</span>
            </div>
          </div>
          {made.length ? (
            <div className="rounded-xl border border-amber-300 bg-amber-50 p-3 text-sm dark:bg-amber-950/30">
              <div className="mb-2 flex flex-wrap items-center justify-between gap-2">
                <b>New codes (shown only now)</b>
                <Button type="button" size="sm" variant="outline" onClick={() => download(`${title} codes.csv`, [["Student", "Code"], ...made.map((m) => [m.label, m.code])])}><DownloadSimple size={16} /> Download CSV</Button>
              </div>
              <div className="grid gap-1 sm:grid-cols-2">{made.map((m) => <div key={m.code} className="flex justify-between gap-2"><span>{m.label}</span><code className="font-bold">{m.code}</code></div>)}</div>
            </div>
          ) : null}
          {invites.length ? (
            <div>
              <b className="text-sm">Personal codes ({used} of {invites.length} used)</b>
              <div className="mt-2 max-h-72 overflow-auto rounded-lg border">
                <table className="w-full text-sm">
                  <thead className="bg-muted/50 text-left text-xs"><tr><th className="p-2">Student</th><th className="p-2">Code ends</th><th className="p-2">Used</th><th className="p-2" /></tr></thead>
                  <tbody>{invites.map((i) => (
                    <tr key={i.id} className="border-t">
                      <td className="p-2">{i.label}</td><td className="p-2 font-mono">…{i.code_hint}</td>
                      <td className="p-2">{i.claimed_at ? when(i.claimed_at) : <span className="text-muted-foreground">not yet</span>}</td>
                      <td className="p-2 text-right">
                        <Button type="button" size="sm" variant="ghost" aria-label={`Remove ${i.label}`} disabled={pending || !!i.claimed_at} onClick={() => start(async () => {
                          const r = await deleteInvite(challengeId, i.id);
                          if (r.ok) router.refresh(); else toast.error(r.error);
                        })}><Trash size={16} /></Button>
                      </td>
                    </tr>
                  ))}</tbody>
                </table>
              </div>
            </div>
          ) : null}
        </>
      ) : null}
    </div>
  );
}

/** The teacher's view: leaderboard with subject scores and behaviour, most-missed questions, weak topics, slow questions. */
export function MockAnalysis({ challengeId, title }: { challengeId: string; title: string }) {
  const [a, setA] = useState<MockAnalytics | null>(null);
  const [err, setErr] = useState<string | null>(null);
  const [pending, start] = useTransition();
  const [open, setOpen] = useState<string | null>(null);
  const [timeline, setTimeline] = useState<{ kind: string; ms: number | null; at: string }[]>([]);
  const load = () => start(async () => {
    const r = await mockAnalytics(challengeId);
    if (r.ok && r.data) { setA(r.data); setErr(null); } else if (!r.ok) setErr(r.error);
  });
  useEffect(load, [challengeId]);
  if (err) return <p className="text-sm text-destructive">{err}</p>;
  if (!a) return <p className="text-sm text-muted-foreground">Loading the analysis…</p>;
  const b = a.behaviour ?? ({} as MockAnalytics["behaviour"]);
  const subjects = Array.from(new Set(a.leaderboard.flatMap((r) => (r.subject_scores ?? []).map((s) => s.name))));
  const exportBoard = () => download(`${title} results.csv`, [
    ["Position", "Student", "Code", "Status", "Total", ...subjects, "Answered", "Minutes", "Times left", "Time away", "Flags"],
    ...a.leaderboard.map((r, i) => [i + 1, r.name ?? "", r.via?.replace(/^invite:/, "") ?? "", r.status, r.score ?? "",
      ...subjects.map((n) => r.subject_scores?.find((s) => s.name === n)?.score ?? ""), r.answered, Math.round((r.time_ms ?? 0) / 60000), r.leaves, mins(r.away_ms), (r.flags ?? []).join(" ")]),
  ]);
  return (
    <div className="space-y-6">
      <div className="flex flex-wrap items-center gap-2">
        {[["Took part", a.players], ["Submitted", a.finished], ["Average", a.average != null ? `${a.average}` : "–"], ["Left the screen", b.left_screen ?? 0],
          ["Average time away", `${b.avg_away_seconds ?? 0}s`], ["Flagged", b.flagged ?? 0], ["Average minutes", b.avg_minutes ?? "–"]].map(([l, v]) => (
          <div key={String(l)} className="min-w-28 rounded-xl border px-3 py-2"><div className="text-lg font-bold">{String(v)}</div><div className="text-xs text-muted-foreground">{String(l)}</div></div>
        ))}
        <div className="ml-auto flex gap-2">
          <Button type="button" size="sm" variant="outline" disabled={pending} onClick={load}><ArrowClockwise size={16} /> Refresh</Button>
          <Button type="button" size="sm" variant="outline" onClick={exportBoard}><DownloadSimple size={16} /> Results CSV</Button>
        </div>
      </div>

      <section>
        <b className="text-sm">Leaderboard</b>
        <div className="mt-2 overflow-auto rounded-lg border">
          <table className="w-full text-sm">
            <thead className="bg-muted/50 text-left text-xs"><tr>
              <th className="p-2">#</th><th className="p-2">Student</th><th className="p-2">Total</th>{subjects.map((n) => <th key={n} className="p-2">{n}</th>)}
              <th className="p-2">Answered</th><th className="p-2">Minutes</th><th className="p-2">Left</th><th className="p-2">Away</th><th className="p-2">Flags</th>
            </tr></thead>
            <tbody>{a.leaderboard.map((r, i) => (
              <tr key={r.entry_id} className="cursor-pointer border-t hover:bg-muted/30" onClick={() => start(async () => {
                if (open === r.entry_id) { setOpen(null); return; }
                const t = await mockTimeline(r.entry_id);
                setTimeline(t.ok && t.data ? t.data : []); setOpen(r.entry_id);
              })}>
                <td className="p-2">{r.status === "finished" ? i + 1 : "–"}</td>
                <td className="p-2"><div className="font-medium">{r.name ?? "Student"}</div>{r.via?.startsWith("invite:") ? <div className="text-xs text-muted-foreground">{r.via.slice(7)}</div> : null}{r.status === "playing" ? <Pill tone="warn">writing</Pill> : null}</td>
                <td className="p-2 font-bold">{r.score ?? "–"}</td>
                {subjects.map((n) => <td key={n} className="p-2">{r.subject_scores?.find((s) => s.name === n)?.score ?? "–"}</td>)}
                <td className="p-2">{r.answered}</td><td className="p-2">{Math.round((r.time_ms ?? 0) / 60000)}</td>
                <td className={`p-2 ${r.leaves > 0 ? "font-bold text-amber-600" : ""}`}>{r.leaves}</td><td className="p-2">{mins(r.away_ms)}</td>
                <td className="p-2">{(r.flags ?? []).map((f) => <Pill key={f} tone="error">{f.replace(/_/g, " ")}</Pill>)}</td>
              </tr>
            ))}</tbody>
          </table>
        </div>
        {open ? (
          <div className="mt-2 rounded-lg border p-3 text-sm">
            <b>Timeline</b>
            {timeline.length ? <ul className="mt-1 space-y-0.5">{timeline.map((t, i) => <li key={i}>{when(t.at)} · {t.kind}{t.kind === "return" && t.ms ? ` after ${mins(t.ms)}` : ""}</li>)}</ul> : <p className="text-muted-foreground">Nothing unusual: the student stayed on the exam screen.</p>}
          </div>
        ) : null}
      </section>

      <section>
        <b className="text-sm">Questions most students missed</b>
        <div className="mt-2 overflow-auto rounded-lg border">
          <table className="w-full text-sm">
            <thead className="bg-muted/50 text-left text-xs"><tr><th className="p-2">Subject</th><th className="p-2">No.</th><th className="p-2">Question</th><th className="p-2">Missed</th><th className="p-2">Answer</th><th className="p-2">Students picked</th><th className="p-2">Avg time</th></tr></thead>
            <tbody>{a.most_missed.slice(0, 25).map((q) => (
              <tr key={q.id} className="border-t">
                <td className="p-2">{q.subject}{q.section ? <div className="text-xs text-muted-foreground">{q.section}</div> : null}</td>
                <td className="p-2">{q.number ?? "–"}</td><td className="max-w-md p-2">{q.body}</td>
                <td className="p-2 font-bold">{q.missed_pct}%</td><td className="p-2">{q.answer}</td>
                <td className="p-2 text-xs">{Object.entries(q.picks ?? {}).sort().map(([k, v]) => `${k}: ${v}`).join(" · ")}</td>
                <td className="p-2">{q.avg_seconds ?? "–"}s</td>
              </tr>
            ))}</tbody>
          </table>
        </div>
      </section>

      <div className="grid gap-4 lg:grid-cols-2">
        <section>
          <b className="text-sm">Topics to teach again</b>
          <ul className="mt-2 space-y-2">{a.by_topic.slice(0, 15).map((t) => (
            <li key={`${t.subject}-${t.topic}`} className="text-sm">
              <div className="flex justify-between"><span>{t.subject} · {t.topic}</span><b>{t.missed_pct}% missed</b></div>
              <div className="mt-1 h-2 overflow-hidden rounded bg-muted"><div className={`h-full ${t.missed_pct >= 60 ? "bg-red-500" : t.missed_pct >= 40 ? "bg-amber-500" : "bg-green-600"}`} style={{ width: `${t.missed_pct}%` }} /></div>
            </li>
          ))}</ul>
        </section>
        <section>
          <b className="text-sm">Questions students spent the most time on</b>
          <ul className="mt-2 space-y-1 text-sm">{a.slowest.map((q) => <li key={q.id} className="flex justify-between gap-3"><span className="truncate">{q.subject} {q.number ? `#${q.number}` : ""} · {q.body}</span><b>{q.avg_seconds}s</b></li>)}</ul>
        </section>
      </div>
    </div>
  );
}

/** Upload pictures for mock questions and copy their keys into the CSV `image` column. */
export function PictureKeys() {
  const [keys, setKeys] = useState<{ name: string; key: string }[]>([]);
  const [busy, setBusy] = useState(false);
  return (
    <div className="space-y-2 text-sm">
      <p className="text-muted-foreground">Upload diagrams or pictures here, then paste each key into the <code>image</code> column of your CSV (WebP, PNG or JPG, under 2 MB).</p>
      <input type="file" multiple accept="image/webp,image/png,image/jpeg" aria-label="Question pictures" className="block" disabled={busy} onChange={async (e) => {
        const files = Array.from(e.target.files ?? []);
        setBusy(true);
        for (const file of files) {
          try {
            const r = await fetch("/admin/api/upload", { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify({ kind: "challenge", contentType: file.type, size: file.size }) });
            const j = await r.json();
            if (!r.ok) throw new Error(j.error ?? "Upload failed");
            const put = await fetch(j.url, { method: "PUT", headers: { "content-type": file.type }, body: file });
            if (!put.ok) throw new Error("Upload failed");
            setKeys((k) => [...k, { name: file.name, key: j.key as string }]);
          } catch (err) {
            toast.error(`${file.name}: ${(err as Error).message}`);
          }
        }
        setBusy(false);
        e.target.value = "";
      }} />
      {busy ? <p className="text-muted-foreground">Uploading…</p> : null}
      {keys.length ? (
        <div className="space-y-1">{keys.map((k) => (
          <div key={k.key} className="flex items-center justify-between gap-2 rounded border px-2 py-1">
            <span className="truncate">{k.name}</span>
            <button type="button" className="font-mono text-xs text-primary hover:underline" onClick={() => { navigator.clipboard.writeText(k.key); toast.success("Key copied"); }}>{k.key}</button>
          </div>
        ))}</div>
      ) : null}
    </div>
  );
}
