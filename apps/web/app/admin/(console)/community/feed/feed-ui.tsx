"use client";
import { useCallback, useEffect, useMemo, useState, useTransition } from "react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { Textarea } from "@/components/ui/textarea";
import { inputCls } from "@/components/admin/row-form";
import { EmptyState, Panel } from "@/components/admin/ui";
import { createClient } from "@/lib/supabase/client";
import { renderMarkdown } from "@/lib/markdown";
import { useAvatar } from "@/components/tutor-chat/lib";
import { cn } from "@/lib/utils";

// The Community for staff (D-156): same feed and functions as the app, with SolutionTee powers.
type J = Record<string, unknown>;
type Page = { id: string; handle: string; name: string; official: boolean; avatar_path: string | null };
const s = (v: unknown) => (v == null ? "" : String(v));
const n = (v: unknown) => (typeof v === "number" ? v : Number(v ?? 0));

function ago(iso: unknown) {
  const d = new Date(s(iso));
  const m = Math.max(0, Math.round((Date.now() - d.getTime()) / 60000));
  if (m < 1) return "now";
  if (m < 60) return `${m}m`;
  if (m < 1440) return `${Math.floor(m / 60)}h`;
  if (m < 10080) return `${Math.floor(m / 1440)}d`;
  return d.toLocaleDateString("en-GB", { day: "numeric", month: "short" });
}

function Badge({ kind }: { kind: unknown }) {
  if (!kind) return null;
  const label = kind === "ai" ? "SolutionTee AI" : kind === "official" ? "Official SolutionTee page" : kind === "page" ? "SolutionTee page" : kind === "mod" ? "Community moderator" : "SolutionTee team";
  return (
    <span title={label} aria-label={label} className={cn("inline-grid size-4 place-items-center rounded-[5px] border bg-white", kind === "official" || kind === "ai" ? "border-amber-400" : "border-blue-600")}>
      {/* eslint-disable-next-line @next/next/no-img-element -- our own brand file */}
      <img src="/brand/favicon.svg" alt="" className="size-3 rounded-[3px]" />
    </span>
  );
}

function Face({ name, path, ai }: { name: string; path?: unknown; ai?: boolean }) {
  const sb = useMemo(() => createClient(), []);
  const url = useAvatar(sb, ai ? null : (s(path) || null));
  const initials = name.split(/\s+/).filter(Boolean).map((p) => p[0]).slice(0, 2).join("").toUpperCase() || "?";
  if (ai) {
    // eslint-disable-next-line @next/next/no-img-element -- our own brand file
    return <img src="/brand/favicon.svg" alt="" className="size-10 shrink-0 rounded-xl" />;
  }
  return (
    <span className="relative grid size-10 shrink-0 place-items-center overflow-hidden rounded-full bg-amber-400 text-sm font-bold text-[#0B1F44]">
      {initials}
      {/* eslint-disable-next-line @next/next/no-img-element -- short signed R2 link */}
      {url ? <img src={url} alt="" className="absolute inset-0 size-full object-cover" /> : null}
    </span>
  );
}

function Pictures({ keys }: { keys: string[] }) {
  const sb = useMemo(() => createClient(), []);
  const [urls, setUrls] = useState<string[]>([]);
  useEffect(() => {
    let live = true;
    Promise.all(keys.slice(0, 4).map(async (k) => {
      const { data } = await sb.auth.getSession();
      const r = await fetch("/api/images/sign", { method: "POST", headers: { "content-type": "application/json", authorization: `Bearer ${data.session?.access_token ?? ""}` }, body: JSON.stringify({ key: k }) });
      return r.ok ? s((await r.json()).url) : "";
    })).then((u) => live && setUrls(u.filter(Boolean)));
    return () => { live = false; };
  }, [sb, keys]);
  if (!urls.length) return null;
  return (
    <div className={cn("mt-2 grid gap-1 overflow-hidden rounded-2xl border", urls.length > 1 && "grid-cols-2")}>
      {/* eslint-disable-next-line @next/next/no-img-element -- short signed R2 links */}
      {urls.map((u, i) => <img key={u} src={u} alt={`Picture ${i + 1}`} className="max-h-72 w-full object-cover" />)}
    </div>
  );
}

function Thread({ post, mod, onChanged }: { post: J; mod: boolean; onChanged: () => void }) {
  const sb = useMemo(() => createClient(), []);
  const [t, setT] = useState<J | null>(null);
  const [text, setText] = useState("");
  const [to, setTo] = useState<J | null>(null);
  const [pending, start] = useTransition();
  const load = useCallback(async () => {
    const { data } = await sb.rpc("community_thread", { p_id: s(post.id) });
    setT((data ?? {}) as J);
  }, [sb, post.id]);
  useEffect(() => {
    const t = setTimeout(load, 0);
    return () => clearTimeout(t);
  }, [load]);
  const send = () => start(async () => {
    const { data, error } = await sb.rpc("community_reply", { p_post: s(post.id), p_body: text.trim(), p_parent: to ? n(to.id) : undefined });
    const r = (data ?? {}) as J;
    if (error || r.ok !== true) return void toast.error(error?.message ?? "Could not reply. Try again.");
    setText(""); setTo(null);
    // The check runs right after (the 2-minute sweep is the backup).
    sb.functions.invoke("community", { body: { action: "check", kind: "comment", id: s(r.id) } }).finally(() => { load(); onChanged(); });
    load();
  });
  const remove = (c: J) => start(async () => {
    const reason = prompt("Why remove this reply? The student is told and gets a strike.", "It breaks the community guidelines.");
    if (reason === null) return;
    const { error } = await sb.rpc("community_mod_remove", { p_kind: "comment", p_id: s(c.id), p_reason: reason });
    if (error) return void toast.error(error.message);
    toast.success("Removed. The student is told why.");
    load();
  });
  const row = (c: J, nested = false) => (
    <li key={s(c.id)} className={cn("flex gap-3 py-3", nested && "pl-12")}>
      <Face name={s(c.name)} path={c.avatar_path} ai={c.from_ai === true} />
      <div className="min-w-0 flex-1">
        <div className="flex flex-wrap items-center gap-1 text-sm"><b>{s(c.name)}</b><Badge kind={c.badge} /><span className="text-muted-foreground">@{s(c.handle)} · {ago(c.created_at)}</span>
          {c.status !== "shown" ? <span className="rounded bg-muted px-1.5 text-xs">{s(c.status)}</span> : null}</div>
        {c.reply_to_handle && nested ? <p className="text-xs text-blue-600">Replying to @{s(c.reply_to_handle)}</p> : null}
        {c.from_ai === true
          ? <div className="prose prose-sm max-w-none dark:prose-invert" dangerouslySetInnerHTML={{ __html: renderMarkdown(s(c.body), () => "") }} />
          : <p className="whitespace-pre-wrap text-sm">{s(c.body)}</p>}
        <div className="mt-1 flex gap-3 text-xs text-muted-foreground">
          <button type="button" className="hover:text-foreground" onClick={() => setTo(c)}>Reply</button>
          <span>♥ {n(c.likes)}</span>
          {mod && c.mine !== true && c.from_ai !== true && c.status === "shown" ? <button type="button" className="text-red-600 hover:underline" onClick={() => remove(c)}>Remove</button> : null}
        </div>
      </div>
    </li>
  );
  const replies = (t?.replies as J[] | undefined) ?? [];
  return (
    <div className="mt-3 rounded-xl border bg-muted/30 p-3">
      <ul className="divide-y">{replies.map((c) => [row(c), ...((c.reply_list as J[] | undefined) ?? []).map((x) => row(x, true))])}</ul>
      {!replies.length ? <p className="py-2 text-sm text-muted-foreground">No replies yet.</p> : null}
      <div className="mt-2 grid gap-2">
        {to ? <p className="text-xs text-blue-600">Replying to @{s(to.handle)} <button type="button" className="ml-2 text-muted-foreground" onClick={() => setTo(null)}>✕</button></p> : null}
        <Textarea value={text} maxLength={500} onChange={(e) => setText(e.target.value)} placeholder="Post your reply (tag @solutiontee to ask the AI)" rows={2} />
        <div className="flex justify-end"><Button size="sm" disabled={pending || !text.trim()} onClick={send}>Reply</Button></div>
      </div>
    </div>
  );
}

function PostCard({ p, mod, onChanged }: { p: J; mod: boolean; onChanged: () => void }) {
  const sb = useMemo(() => createClient(), []);
  const [open, setOpen] = useState(false);
  const [liked, setLiked] = useState(p.liked === true);
  const [likes, setLikes] = useState(n(p.likes));
  const [reposted, setReposted] = useState(p.reposted === true);
  const [pending, start] = useTransition();
  const [gone, setGone] = useState(false);
  if (gone) return null;
  const like = () => start(async () => {
    const { data } = await sb.rpc("community_like", { p_id: s(p.id) });
    const r = (data ?? {}) as J;
    if (r.ok === true) { setLiked(r.liked === true); setLikes(n(r.likes)); }
  });
  const repost = () => start(async () => {
    const { data } = await sb.rpc("community_repost", { p_id: s(p.id) });
    const r = (data ?? {}) as J;
    if (r.ok === true) { setReposted(r.reposted === true); toast.success(r.reposted ? "Reposted" : "Repost removed"); }
  });
  const remove = () => start(async () => {
    if (p.mine === true) {
      if (!confirm("Delete this post?")) return;
      const { error } = await sb.rpc("community_post_delete", { p_id: s(p.id) });
      if (error) return void toast.error(error.message);
    } else {
      const reason = prompt("Why remove this post? The student is told and gets a strike.", "It breaks the community guidelines.");
      if (reason === null) return;
      const { error } = await sb.rpc("community_mod_remove", { p_kind: "post", p_id: s(p.id), p_reason: reason });
      if (error) return void toast.error(error.message);
    }
    toast.success("Removed.");
    setGone(true);
    onChanged();
  });
  const by = p.reposted_by as J | undefined;
  const q = p.quote as J | undefined;
  return (
    <li className="p-4">
      {by ? <p className="mb-1 pl-12 text-xs font-bold text-muted-foreground">↻ {s(by.name)} reposted</p> : null}
      <div className="flex gap-3">
        <Face name={s(p.name)} path={p.avatar_path} ai={p.badge === "official" && !p.avatar_path} />
        <div className="min-w-0 flex-1">
          <div className="flex flex-wrap items-center gap-1 text-sm"><b>{s(p.name)}</b><Badge kind={p.badge} /><span className="text-muted-foreground">@{s(p.handle)} · {ago(p.created_at)}</span>
            {p.status !== "shown" ? <span className="rounded bg-muted px-1.5 text-xs">{s(p.status)}{p.reason ? `: ${s(p.reason)}` : ""}</span> : null}</div>
          <p className="mt-1 whitespace-pre-wrap text-[15px]">{s(p.body)}</p>
          {Array.isArray(p.images) && p.images.length ? <Pictures keys={(p.images as unknown[]).map(s)} /> : null}
          {q ? <div className="mt-2 rounded-xl border p-3 text-sm"><b>{s(q.name)}</b> <span className="text-muted-foreground">@{s(q.handle)}</span><p className="mt-1 line-clamp-3 text-muted-foreground">{s(q.body) || "This post is no longer available."}</p></div> : null}
          <div className="mt-2 flex flex-wrap gap-4 text-sm text-muted-foreground">
            <button type="button" className="hover:text-foreground" onClick={() => setOpen((o) => !o)}>💬 {n(p.comments)}</button>
            <button type="button" disabled={pending} className={cn("hover:text-foreground", reposted && "text-green-600")} onClick={repost}>↻ {n(p.reposts) + (reposted && p.reposted !== true ? 1 : 0)}</button>
            <button type="button" disabled={pending} className={cn("hover:text-foreground", liked && "text-rose-500")} onClick={like}>{liked ? "♥" : "♡"} {likes}</button>
            {p.mine === true || mod ? <button type="button" disabled={pending} className="text-red-600 hover:underline" onClick={remove}>{p.mine === true ? "Delete" : "Remove"}</button> : null}
          </div>
          {open ? <Thread post={p} mod={mod} onChanged={onChanged} /> : null}
        </div>
      </div>
    </li>
  );
}

export function StaffCommunity({ role }: { role: string }) {
  const sb = useMemo(() => createClient(), []);
  const [tab, setTab] = useState<"for_you" | "following">("for_you");
  const [items, setItems] = useState<J[] | null>(null);
  const [me, setMe] = useState<J>({});
  const [as, setAs] = useState("");
  const [text, setText] = useState("");
  const [pending, start] = useTransition();
  const [newPage, setNewPage] = useState({ handle: "", name: "", bio: "" });
  const [modHandle, setModHandle] = useState("");
  const pages = ((me.pages as Page[] | undefined) ?? []);
  const mod = me.mod === true;
  const admin = role === "super_admin" || role === "admin";

  const load = useCallback(async () => {
    const [{ data: feed }, { data: u }] = await Promise.all([sb.rpc("community_home", { p_tab: tab, p_offset: 0 }), sb.rpc("community_user")]);
    setItems(((feed ?? []) as J[]));
    setMe((u ?? {}) as J);
  }, [sb, tab]);
  useEffect(() => {
    const t = setTimeout(load, 0);
    return () => clearTimeout(t);
  }, [load]);

  const max = as ? 1000 : 500;
  const post = () => start(async () => {
    const body = text.trim();
    const { data, error } = as
      ? await sb.rpc("community_page_post", { p_page: as, p_body: body })
      : await sb.rpc("community_post_send", { p_body: body });
    const r = (data ?? {}) as J;
    if (error || r.ok !== true) return void toast.error(error?.message ?? (r.error === "banned" ? "Posting is paused for this account." : "Could not post. Try again."));
    setText("");
    toast.success("Posted!");
    if (!as) sb.functions.invoke("community", { body: { action: "check", kind: "post", id: s(r.id) } }).finally(load);
    load();
  });
  const savePage = () => start(async () => {
    const { data, error } = await sb.rpc("community_page_save", { p_id: null, p_handle: newPage.handle, p_name: newPage.name, p_bio: newPage.bio });
    const r = (data ?? {}) as J;
    if (error || r.ok !== true) return void toast.error(error?.message ?? (r.error === "taken" ? "That @handle is taken." : r.error === "format" ? "Use 3-20 small letters, numbers, _ or ." : "Check the name and handle."));
    toast.success("Page created. You can post as it now.");
    setNewPage({ handle: "", name: "", bio: "" });
    load();
  });
  const setModerator = (on: boolean) => start(async () => {
    const { data, error } = await sb.rpc("community_set_moderator", { p_handle: modHandle, p_on: on });
    if (error || (data as J | null)?.ok !== true) return void toast.error(error?.message ?? "No student has that @handle.");
    toast.success(on ? `@${modHandle.replace("@", "")} is now a Community moderator.` : "Moderator removed.");
    setModHandle("");
  });

  return (
    <div className="grid gap-4 lg:grid-cols-[minmax(0,1fr)_320px]">
      <div className="grid content-start gap-4">
        <Panel title="New post">
          <div className="grid gap-3">
            <label className="flex flex-wrap items-center gap-2 text-sm">Post as
              <select aria-label="Post as" className={`${inputCls} max-w-xs`} value={as} onChange={(e) => setAs(e.target.value)}>
                <option value="">Me (@{s(me.handle)})</option>
                {pages.map((pg) => <option key={pg.id} value={pg.id}>{pg.name} (@{pg.handle}){pg.official ? " · official" : ""}</option>)}
              </select>
            </label>
            <Textarea value={text} maxLength={max} rows={4} onChange={(e) => setText(e.target.value)} placeholder="Share an update, a tip or a question. Use #topics and @handles. Tag @solutiontee for the AI." />
            <div className="flex items-center justify-between text-xs text-muted-foreground"><span>{max - text.length} left</span>
              <Button disabled={pending || !text.trim()} onClick={post}>Post</Button></div>
          </div>
        </Panel>
        <nav className="flex gap-2" aria-label="Feed">
          {(["for_you", "following"] as const).map((k) => (
            <button key={k} type="button" onClick={() => setTab(k)} className={cn("rounded-full border px-3 py-1.5 text-sm font-bold", tab === k ? "border-primary bg-primary text-primary-foreground" : "hover:bg-muted")}>
              {k === "for_you" ? "For you" : "Following"}</button>
          ))}
          <Button variant="ghost" size="sm" onClick={load}>Refresh</Button>
        </nav>
        <Panel title="Feed" bodyClassName="p-0">
          {items === null ? <p className="p-4 text-sm text-muted-foreground">Loading…</p> : items.length ? (
            <ul className="divide-y">{items.map((p) => <PostCard key={`${s(p.id)}:${s((p.reposted_by as J | undefined)?.id)}`} p={p} mod={mod} onChanged={load} />)}</ul>
          ) : <EmptyState title="No posts yet">Be the first to say hello to the students.</EmptyState>}
        </Panel>
      </div>
      <div className="grid content-start gap-4">
        <Panel title="Your pages">
          {pages.length ? <ul className="grid gap-1 text-sm">{pages.map((pg) => <li key={pg.id}><b>{pg.name}</b> <span className="text-muted-foreground">@{pg.handle}{pg.official ? " · official" : ""}</span></li>)}</ul>
            : <p className="text-sm text-muted-foreground">You do not manage a page yet.</p>}
          <p className="mt-2 text-xs text-muted-foreground">Only super admins post as the official @solutiontee page.</p>
        </Panel>
        <Panel title="Create a page">
          <div className="grid gap-2">
            <input aria-label="Page name" className={inputCls} placeholder="Name, e.g. SolutionTee Physics" value={newPage.name} onChange={(e) => setNewPage({ ...newPage, name: e.target.value })} />
            <input aria-label="Page handle" className={inputCls} placeholder="@handle, e.g. st_physics" value={newPage.handle} onChange={(e) => setNewPage({ ...newPage, handle: e.target.value })} />
            <input aria-label="Page bio" className={inputCls} placeholder="Short bio (optional)" maxLength={160} value={newPage.bio} onChange={(e) => setNewPage({ ...newPage, bio: e.target.value })} />
            <Button size="sm" disabled={pending || !newPage.name.trim() || !newPage.handle.trim()} onClick={savePage}>Create page</Button>
          </div>
        </Panel>
        {admin ? (
          <Panel title="Moderators">
            <p className="mb-2 text-xs text-muted-foreground">Moderators get the SolutionTee mark and can take down posts and replies. Super admins and admins can too.</p>
            <input aria-label="Student handle" className={inputCls} placeholder="@handle" value={modHandle} onChange={(e) => setModHandle(e.target.value)} />
            <div className="mt-2 flex gap-2"><Button size="sm" disabled={pending || !modHandle.trim()} onClick={() => setModerator(true)}>Make moderator</Button>
              <Button size="sm" variant="outline" disabled={pending || !modHandle.trim()} onClick={() => setModerator(false)}>Remove</Button></div>
          </Panel>
        ) : null}
      </div>
    </div>
  );
}
