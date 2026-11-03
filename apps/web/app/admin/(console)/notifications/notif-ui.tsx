"use client";
import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { SpinnerGap, X } from "@phosphor-icons/react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { Label } from "@/components/ui/label";
import { inputCls } from "@/components/admin/row-form";
import { Pill, when, type Tone } from "@/components/admin/ui";
import { cancelNotification, createNotification } from "./actions";

export type NotifRow = {
  id: string; topic: string; title: string; body: string; link: { type?: string; target?: string }; audience: string; status: string;
  scheduled_at: string; sent_at: string | null; sent_count: number; error: string | null; source: string; created_at: string; reads: number; created_by: string | null;
};

const TOPICS: [string, string][] = [["announcements", "Announcements"], ["new_questions", "New questions added"], ["streak", "Streak reminders"], ["classes", "Class reminders"], ["challenges", "Challenges"]];
const AUDIENCE: [string, string][] = [["staff", "Only my test phones"], ["all", "Everyone"], ["free", "Free students"], ["premium", "Premium students"]];
const SCREENS: [string, string][] = [["/home", "Home"], ["/study", "Study"], ["/test", "Test"], ["/test/setup?exam=JAMB&mode=quick", "Quick JAMB test"], ["/ai", "AI tutor"], ["/me", "Me"], ["/notifications", "Notifications"]];
const STATUS: Record<string, [string, Tone]> = { sent: ["Sent", "ok"], scheduled: ["Scheduled", "info"], sending: ["Sending", "warn"], cancelled: ["Cancelled", "neutral"], failed: ["Failed", "error"], draft: ["Draft", "neutral"] };
const SOURCE: Record<string, string> = { admin: "", news: "News post", year: "New exam year", streak: "Streak", premium: "Premium" };

export function Compose({ news }: { news: { id: string; title: string }[] }) {
  const router = useRouter();
  const [linkType, setLinkType] = useState("screen");
  const [whenSend, setWhen] = useState<"now" | "later">("now");
  const [title, setTitle] = useState("");
  const [body, setBody] = useState("");
  const [pending, start] = useTransition();
  return (
    <form className="space-y-4" action={(f) => start(async () => {
      const r = await createNotification(f);
      if (r.ok) { toast.success(r.message ?? "Done"); setTitle(""); setBody(""); router.refresh(); } else toast.error(r.error);
    })}>
      <div className="space-y-1.5"><Label htmlFor="nTitle">Title</Label>
        <input id="nTitle" name="title" value={title} onChange={(e) => setTitle(e.target.value)} maxLength={80} required placeholder="e.g. New JAMB 2026 Physics questions" className={inputCls} />
        <span className="text-xs text-muted-foreground">{title.length}/80</span></div>
      <div className="space-y-1.5"><Label htmlFor="nBody">Message</Label>
        <textarea id="nBody" name="body" value={body} onChange={(e) => setBody(e.target.value)} maxLength={240} required rows={3} placeholder="Short and clear. One idea per message." className="w-full rounded-xl border border-input bg-card px-3 py-2.5 text-sm" />
        <span className="text-xs text-muted-foreground">{body.length}/240</span></div>
      <div className="grid gap-3 sm:grid-cols-2">
        <div className="space-y-1.5"><Label htmlFor="nTopic">Topic</Label>
          <select id="nTopic" name="topic" defaultValue="announcements" className={inputCls}>{TOPICS.map(([v, l]) => <option key={v} value={v}>{l}</option>)}</select>
          <span className="text-xs text-muted-foreground">Students who switched this topic off do not get it.</span></div>
        <div className="space-y-1.5"><Label htmlFor="nAud">Who gets it</Label>
          <select id="nAud" name="audience" defaultValue="staff" className={inputCls}>{AUDIENCE.map(([v, l]) => <option key={v} value={v}>{l}</option>)}</select></div>
      </div>
      <div className="grid gap-3 sm:grid-cols-2">
        <div className="space-y-1.5"><Label htmlFor="nLink">When tapped, open</Label>
          <select id="nLink" name="link_type" value={linkType} onChange={(e) => setLinkType(e.target.value)} className={inputCls}>
            <option value="screen">A screen in the app</option><option value="news">A news post</option><option value="url">A web page</option><option value="none">Notifications screen</option>
          </select></div>
        <div className="space-y-1.5"><Label htmlFor="nTarget">{linkType === "screen" ? "Screen" : linkType === "news" ? "News post" : linkType === "url" ? "Web address" : " "}</Label>
          {linkType === "screen" ? (
            <select id="nTarget" name="link_target" defaultValue="/home" className={inputCls}>{SCREENS.map(([v, l]) => <option key={v} value={v}>{l}</option>)}</select>
          ) : linkType === "news" ? (
            <select id="nTarget" name="link_target" className={inputCls}>{news.map((n) => <option key={n.id} value={n.id}>{n.title}</option>)}</select>
          ) : linkType === "url" ? (
            <input id="nTarget" name="link_target" placeholder="https://solutiontee.com/…" className={inputCls} />
          ) : <input type="hidden" name="link_target" value="" />}
        </div>
      </div>
      <div className="space-y-1.5"><Label>Send</Label>
        <div className="flex flex-wrap items-center gap-3">
          <label className="flex items-center gap-2 text-sm"><input type="radio" name="when" value="now" checked={whenSend === "now"} onChange={() => setWhen("now")} /> Now</label>
          <label className="flex items-center gap-2 text-sm"><input type="radio" name="when" value="later" checked={whenSend === "later"} onChange={() => setWhen("later")} /> Later (Lagos time)</label>
          {whenSend === "later" ? <input name="at" type="datetime-local" required className={`${inputCls} w-auto`} /> : null}
        </div></div>
      <div className="rounded-xl bg-surface-alt p-3 text-sm">
        <span className="text-xs font-bold text-muted-foreground">Preview</span>
        <b className="mt-1 block">{title || "Title"}</b><span className="text-muted-foreground">{body || "Your message"}</span>
      </div>
      <div className="flex justify-end"><Button type="submit" disabled={pending}>{pending ? <SpinnerGap size={16} className="animate-spin" /> : null} {whenSend === "now" ? "Send" : "Schedule"}</Button></div>
    </form>
  );
}

export function History({ rows }: { rows: NotifRow[] }) {
  const router = useRouter();
  const [pending, start] = useTransition();
  return (
    <ul className="divide-y">
      {rows.map((r) => {
        const [label, tone] = STATUS[r.status] ?? [r.status, "neutral" as Tone];
        return (
          <li key={r.id} className="flex gap-3 px-5 py-3 text-sm">
            <div className="min-w-0 flex-1">
              <div className="flex flex-wrap items-center gap-2"><b>{r.title}</b><Pill tone={tone}>{label}</Pill>{SOURCE[r.source] ? <Pill>{SOURCE[r.source]}</Pill> : null}</div>
              <p className="text-muted-foreground">{r.body}</p>
              <span className="block text-xs text-muted-foreground">
                {AUDIENCE.find(([v]) => v === r.audience)?.[1] ?? r.audience} · {TOPICS.find(([v]) => v === r.topic)?.[1] ?? r.topic} ·{" "}
                {r.sent_at ? `sent ${when(r.sent_at)} · ${r.audience === "staff" || r.audience === "user" ? `${r.sent_count} phone${r.sent_count === 1 ? "" : "s"}` : "to the topic"} · ${r.reads} read` : `for ${when(r.scheduled_at)}`}
              </span>
              {r.error ? <span className="block text-xs text-warning">{r.error}</span> : null}
            </div>
            {r.status === "scheduled" && r.source === "admin" ? (
              <Button variant="ghost" size="icon" aria-label="Cancel" disabled={pending} onClick={() => start(async () => {
                const res = await cancelNotification(r.id);
                if (res.ok) { toast.success(res.message ?? "Cancelled"); router.refresh(); } else toast.error(res.error);
              })}><X size={18} /></Button>
            ) : null}
          </li>
        );
      })}
    </ul>
  );
}
