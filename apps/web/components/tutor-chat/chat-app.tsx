"use client";
import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { AnimatePresence, motion, useReducedMotion } from "motion/react";
import { toast } from "sonner";
import { ArrowLeft, CaretDown, ChatsCircle, IdentificationCard, MagnifyingGlass, Star, X } from "@phosphor-icons/react";
import { Dialog, DialogContent, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { createClient } from "@/lib/supabase/client";
import { cn } from "@/lib/utils";
import { Bubble, Typing, type MsgAction } from "./bubbles";
import { Composer, type SendFn } from "./composer";
import { Details } from "./details";
import { dayLabel, fromRow, initials, listTime, liveChannel, mergeAll, naira, ping, planInfo, preview, quoteText, upload, type Chat, type Msg, type TutorOpt } from "./lib";

const STATUS: Record<string, { label: string; tone: string }> = {
  new: { label: "Choosing a plan", tone: "bg-slate-100 text-slate-700 dark:bg-slate-800 dark:text-slate-200" },
  quoted: { label: "Price sent", tone: "bg-violet-100 text-violet-700 dark:bg-violet-950 dark:text-violet-200" },
  paid: { label: "Needs a tutor", tone: "bg-amber-100 text-amber-800 dark:bg-[#2B2210] dark:text-[#F9D99A]" },
  matched: { label: "Active", tone: "bg-emerald-100 text-emerald-700 dark:bg-[#0F3B26] dark:text-[#7FD8A6]" },
  ended: { label: "Plan ended", tone: "bg-slate-100 text-slate-500 dark:bg-slate-800" },
  closed: { label: "Closed", tone: "bg-slate-100 text-slate-500 dark:bg-slate-800" },
};
const ADMIN_FILTERS = [["open", "Needs action"], ["paid", "Needs a tutor"], ["new", "Choosing"], ["matched", "Active"], ["ended", "Ended"], ["all", "All"]] as const;
const TUTOR_FILTERS = [["all", "All"], ["unread", "Unread"], ["ending", "Ending soon"]] as const;

/**
 * WhatsApp-style tutor chat, v3 (D-152, D-153), for tutors (/admin/tutor: their students) and admins (/admin/tutors:
 * every request, assignments and custom prices). Live and self-healing: rows come on public "postgres_changes"
 * channels (row security decides who receives them), typing and online on the private "tutor:<id>" room; every
 * channel joins again by itself, what was missed is fetched on each re-join and when the tab comes back, and a slow
 * poll is the last safety net.
 */
export function ChatApp({ mode, initialChats, tutors, initialOpen, className }: {
  mode: "tutor" | "admin"; initialChats: Chat[]; tutors?: TutorOpt[]; initialOpen?: string | null; className?: string;
}) {
  const sb = useMemo(() => createClient(), []);
  const rm = useReducedMotion();
  const [chats, setChats] = useState<Chat[]>(initialChats);
  const [filter, setFilter] = useState<string>(mode === "admin" ? "open" : "all");
  const [q, setQ] = useState("");
  const [active, setActive] = useState<string | null>(initialOpen ?? null);
  const [msgs, setMsgs] = useState<Msg[]>([]);
  const [loading, setLoading] = useState(false);
  const [older, setOlder] = useState(true);
  const [typing, setTyping] = useState<string | null>(null);
  const [online, setOnline] = useState(false);
  const [live, setLive] = useState(false);
  const [details, setDetails] = useState(mode === "tutor");
  const [photo, setPhoto] = useState<string | null>(null);
  const [reply, setReply] = useState<Msg | null>(null);
  const [away, setAway] = useState(false);
  const [newBelow, setNewBelow] = useState(0);
  const [starred, setStarred] = useState<Msg[] | null>(null);
  const [report, setReport] = useState<Msg | null>(null);
  const scroller = useRef<HTMLDivElement>(null);
  const room = useRef<ReturnType<typeof liveChannel> | null>(null);
  const lastTyping = useRef(0);
  const typingTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const tempId = useRef(-1);
  const activeRef = useRef(active);
  const myRole = mode === "tutor" ? "tutor" : "admin";
  useEffect(() => { activeRef.current = active; }, [active]);

  const chat = chats.find((c) => c.id === active) ?? null;
  const reload = useCallback(async () => {
    const { data } = await sb.rpc("tutor_chats", { p_scope: mode === "tutor" ? "mine" : "all" });
    if (data) setChats(data as unknown as Chat[]);
  }, [sb, mode]);

  const atBottom = () => { const el = scroller.current; return !el || el.scrollHeight - el.scrollTop - el.clientHeight < 140; };
  const toBottom = useCallback((smooth = true) => requestAnimationFrame(() => scroller.current?.scrollTo({ top: scroller.current.scrollHeight, behavior: smooth && !rm ? "smooth" : "auto" })), [rm]);

  // The list: any message or request change I may see refreshes it, with a soft ping for a new student message.
  useEffect(() => {
    let t: ReturnType<typeof setTimeout> | null = null;
    const soon = () => { if (t) clearTimeout(t); t = setTimeout(() => void reload(), 300); };
    const ch = liveChannel(sb, `tutor-list-${mode}`, {}, (c) => c
      .on("postgres_changes", { event: "INSERT", schema: "public", table: "tutor_messages" }, (p) => {
        const row = p.new as { sender_role?: string; request_id?: string };
        if (row.sender_role === "student" && (document.visibilityState !== "visible" || row.request_id !== activeRef.current)) ping();
        soon();
      })
      .on("postgres_changes", { event: "UPDATE", schema: "public", table: "tutor_messages" }, soon)
      .on("postgres_changes", { event: "*", schema: "public", table: "tutor_requests" }, (p) => {
        if (mode === "admin" && (p.new as { status?: string })?.status === "paid" && (p.old as { status?: string })?.status !== "paid") { ping(); toast("A student paid for a tutor. Assign one within 24 hours."); }
        soon();
      }), () => soon());
    const poll = setInterval(() => void reload(), 45_000);
    const vis = () => { if (document.visibilityState === "visible") void reload(); };
    document.addEventListener("visibilitychange", vis);
    return () => { ch.close(); clearInterval(poll); document.removeEventListener("visibilitychange", vis); if (t) clearTimeout(t); };
  }, [sb, mode, reload]);

  const markRead = useCallback(async (id: string) => {
    if (document.visibilityState !== "visible") return;
    const { data } = await sb.rpc("tutor_mark_read", { p_request: id });
    if (data) setChats((cs) => cs.map((c) => (c.id === id ? { ...c, unread: 0 } : c)));
  }, [sb]);

  /** The latest messages (missed while joining, asleep or offline). */
  const sync = useCallback(async (id: string) => {
    const { data } = await sb.rpc("tutor_messages_before", { p_request: id, p_before: Number.MAX_SAFE_INTEGER, p_limit: 60 });
    if (activeRef.current !== id || !data) return;
    const rows = (data as unknown as Record<string, unknown>[]).map(fromRow);
    setMsgs((ms) => mergeAll(ms, rows, myRole));
  }, [sb, myRole]);

  // The open chat: history, live rows, typing and online.
  useEffect(() => {
    if (!active) return;
    let alive = true;
    queueMicrotask(() => { setLoading(true); setMsgs([]); setTyping(null); setOnline(false); setOlder(true); setReply(null); setNewBelow(0); });
    void (async () => {
      const { data } = await sb.rpc("tutor_messages_before", { p_request: active, p_before: Number.MAX_SAFE_INTEGER, p_limit: 80 });
      if (!alive) return;
      const rows = ((data ?? []) as unknown as Record<string, unknown>[]).map(fromRow);
      setMsgs(mergeAll([], rows, myRole)); setOlder(rows.length >= 80); setLoading(false); toBottom(false);
      void markRead(active);
    })();
    const filter = `request_id=eq.${active}`;
    const db = liveChannel(sb, `tutor-db:${active}`, {}, (c) => c
      .on("postgres_changes", { event: "INSERT", schema: "public", table: "tutor_messages", filter }, (p) => {
        const m = fromRow(p.new as Record<string, unknown>);
        const stick = atBottom();
        setMsgs((ms) => mergeAll(ms, [m], myRole));
        if (m.role === "student") { setTyping(null); void markRead(active); }
        if (stick || m.role === myRole) toBottom(); else setNewBelow((n) => n + 1);
      })
      .on("postgres_changes", { event: "UPDATE", schema: "public", table: "tutor_messages", filter }, (p) => {
        setMsgs((ms) => mergeAll(ms, [fromRow(p.new as Record<string, unknown>)], myRole));
      }), () => { setLive(true); void sync(active); }, () => setLive(false));
    const r = liveChannel(sb, `tutor:${active}`, { private: true, presenceKey: myRole }, (c) => c
      .on("broadcast", { event: "typing" }, (p) => {
        const pl = p.payload as { role?: string; what?: string };
        if (pl?.role !== "student") return;
        setTyping(pl.what === "voice" ? "recording audio" : "typing");
        if (typingTimer.current) clearTimeout(typingTimer.current);
        typingTimer.current = setTimeout(() => setTyping(null), 4000);
      })
      .on("presence", { event: "sync" }, () => setOnline(Object.keys(c.presenceState()).includes("student"))),
    (c) => void c.track({ role: myRole, at: Date.now() }), () => setOnline(false));
    room.current = r;
    const poll = setInterval(() => void sync(active), 15_000);
    const vis = () => { if (document.visibilityState === "visible") { void sync(active); void markRead(active); } };
    document.addEventListener("visibilitychange", vis);
    return () => { alive = false; document.removeEventListener("visibilitychange", vis); clearInterval(poll); db.close(); r.close(); room.current = null; };
  }, [sb, active, myRole, markRead, sync, toBottom]);

  async function loadOlder() {
    if (!active || !msgs.length) return;
    const el = scroller.current, h = el?.scrollHeight ?? 0;
    const first = msgs.find((m) => !m.pending);
    if (!first) return;
    const { data } = await sb.rpc("tutor_messages_before", { p_request: active, p_before: first.id, p_limit: 60 });
    const rows = ((data ?? []) as unknown as Record<string, unknown>[]).map(fromRow);
    setOlder(rows.length >= 60);
    setMsgs((ms) => mergeAll(ms, rows, myRole));
    requestAnimationFrame(() => { if (el) el.scrollTop = el.scrollHeight - h; });
  }

  const onTyping = (voice?: boolean) => {
    if (Date.now() - lastTyping.current < 2500) return;
    lastTyping.current = Date.now();
    void room.current?.channel?.send({ type: "broadcast", event: "typing", payload: { role: myRole, ...(voice ? { what: "voice" } : {}) } });
  };

  const send: SendFn = async (kind, body, extra) => {
    if (!active) return;
    const id = tempId.current--;
    const r = reply;
    setReply(null);
    const temp: Msg = {
      id, role: myRole, kind, body, attachment: null, at: new Date().toISOString(), read_at: null, meta: extra?.meta ?? null, ref: extra?.ref ?? null, pending: true,
      reply_to: r?.id ?? null, reply: r ? { id: r.id, role: r.role, kind: r.kind, body: r.body, deleted: r.deleted, meta: r.meta } : null,
    };
    setMsgs((ms) => [...ms, temp]);
    toBottom();
    try {
      let key: string | undefined;
      if (extra?.file) key = await upload(sb, active, extra.file, extra.contentType ?? extra.file.type);
      const { data, error } = await sb.rpc("tutor_message_send", {
        p_request: active, p_body: body, p_kind: kind, p_attachment: key, p_meta: extra?.meta ?? undefined, p_ref: extra?.ref ?? undefined, p_reply_to: r?.id ?? undefined,
      });
      const d = (data ?? {}) as { ok?: boolean; error?: string; message?: Record<string, unknown> };
      if (error || !d.ok || !d.message) throw new Error(d.error === "too_many" ? "Slow down a little." : "Not sent. Try again.");
      const m = fromRow(d.message);
      setMsgs((ms) => mergeAll(ms.filter((x) => x.id !== id), [m], myRole));
    } catch (e) {
      setMsgs((ms) => ms.map((x) => (x.id === id ? { ...x, pending: false, failed: true } : x)));
      toast.error(e instanceof Error ? e.message : "Not sent.");
    }
  };

  async function onAction(m: Msg, a: MsgAction) {
    const patch = (p: Partial<Msg>) => setMsgs((ms) => ms.map((x) => (x.id === m.id ? { ...x, ...p } : x)));
    switch (a.type) {
      case "reply": setReply(m); return;
      case "copy": await navigator.clipboard.writeText(m.kind === "link" ? (m.meta?.url ?? m.body) : m.body).catch(() => {}); toast.success("Copied"); return;
      case "react": {
        const before = m.reactions ?? {};
        const next = { ...before } as Record<string, string>;
        if (next[myRole] === a.emoji) delete next[myRole]; else next[myRole] = a.emoji;
        patch({ reactions: next });
        const { data } = await sb.rpc("tutor_message_react", { p_message: m.id, p_emoji: a.emoji });
        if (!(data as { ok?: boolean })?.ok) patch({ reactions: before });
        return;
      }
      case "star": {
        const on = !m.starred;
        patch({ starred: on });
        const { error } = await sb.rpc("tutor_message_star", { p_message: m.id, p_on: on });
        if (error) patch({ starred: !on }); else toast.success(on ? "Starred" : "Removed from starred");
        return;
      }
      case "delete": {
        if (!confirm("Delete this message for everyone?")) return;
        const { data } = await sb.rpc("tutor_message_delete", { p_message: m.id });
        if ((data as { ok?: boolean })?.ok) patch({ deleted: true, body: "", kind: "text", attachment: null, reactions: {} });
        else toast.error("You can delete your own messages for 48 hours.");
        return;
      }
      case "report": setReport(m); return;
    }
  }

  async function openStarred() {
    if (!active) return;
    const { data } = await sb.rpc("tutor_starred", { p_request: active });
    setStarred(((data ?? []) as unknown as Record<string, unknown>[]).map(fromRow));
  }

  const soon = (c: Chat) => { const p = planInfo(c.plan); return p !== null && p.left <= 5; };
  const shown = chats.filter((c) => {
    const f = mode === "admin"
      ? filter === "all" || (filter === "open" ? ["new", "quoted", "paid"].includes(c.status) || c.unread > 0 : c.status === filter)
      : filter === "all" || (filter === "unread" ? c.unread > 0 : soon(c));
    return f && (!q || c.name.toLowerCase().includes(q.toLowerCase()) || (c.subject ?? "").toLowerCase().includes(q.toLowerCase()));
  });
  const unreadTotal = chats.reduce((n, c) => n + (c.unread || 0), 0);
  const needTutor = chats.filter((c) => c.status === "paid").length;
  const readOnly = chat && mode === "tutor" && chat.status !== "matched" ? "This student's plan has ended. You can read the chat." : undefined;
  const status = typing ? `${typing}…` : online ? "online" : chat ? [chat.subject, planInfo(chat.plan) ? `${planInfo(chat.plan)!.left} days left` : STATUS[chat.status]?.label].filter(Boolean).join(" · ") : "";
  const tutorName = chat?.tutor ?? "Tutor";
  const filters = mode === "admin" ? ADMIN_FILTERS : TUTOR_FILTERS;

  return (
    <div className={cn("flex min-h-0 overflow-hidden bg-background", className)}>
      {/* Chat list */}
      <section className={cn("flex min-h-0 w-full flex-col border-r bg-card dark:bg-[#081224] lg:w-[360px] lg:shrink-0", active && "hidden lg:flex")} aria-label="Chats">
        <div className="space-y-3 border-b p-3">
          <div className="flex items-center gap-2">
            <h2 className="flex-1 text-xl font-bold">{mode === "tutor" ? "My students" : "Tutor requests"}</h2>
            <span className={cn("flex items-center gap-1.5 text-xs font-bold", live ? "text-emerald-600 dark:text-[#7FD8A6]" : "text-muted-foreground")} title={live ? "Live updates are on" : "Connecting…"}>
              <span className={cn("size-2 rounded-full", live ? "bg-emerald-500" : "bg-muted-foreground/50", live && !rm && "animate-pulse")} />{live ? "Live" : ""}
            </span>
            {unreadTotal ? <span className="rounded-full bg-[#F2B233] px-2 py-0.5 text-xs font-bold text-[#0B1F44]">{unreadTotal} new</span> : null}
          </div>
          <label className="flex items-center gap-2 rounded-xl bg-muted px-3 dark:bg-[#0D1A30]">
            <MagnifyingGlass size={18} className="text-muted-foreground" />
            <input value={q} onChange={(e) => setQ(e.target.value)} placeholder="Search students" aria-label="Search students" className="h-10 flex-1 bg-transparent text-sm outline-none" />
          </label>
          <div className="-mx-1 flex gap-1.5 overflow-x-auto px-1 pb-0.5">
            {filters.map(([k, l]) => (
              <button key={k} type="button" onClick={() => setFilter(k)}
                className={cn("shrink-0 rounded-full px-3 py-1.5 text-xs font-bold transition-colors", filter === k ? "bg-[#0B1F44] text-white dark:bg-[#EAF0FA] dark:text-[#0B1F44]" : "bg-muted text-muted-foreground hover:text-foreground dark:bg-[#13233F]")}>
                {l}{k === "paid" && needTutor ? ` · ${needTutor}` : k === "unread" && unreadTotal ? ` ${unreadTotal}` : ""}
              </button>
            ))}
          </div>
        </div>
        <ul className="min-h-0 flex-1 overflow-y-auto">
          {shown.length === 0 ? (
            <li className="grid place-items-center gap-2 p-10 text-center text-sm text-muted-foreground">
              <ChatsCircle size={40} />{mode === "tutor" ? (filter === "all" ? "No students yet. When an admin assigns a student to you, they show here at once, with a sound, and you get an email." : "Nothing here.") : "No requests here."}
            </li>
          ) : (
            <AnimatePresence initial={false}>
              {shown.map((c) => (
                <motion.li key={c.id} layout={!rm} initial={rm ? false : { opacity: 0, x: -8 }} animate={{ opacity: 1, x: 0 }}>
                  <button type="button" onClick={() => { setActive(c.id); if (mode === "admin") setDetails(c.status === "paid" || c.status === "quoted" || Boolean(c.custom_note && !c.custom_price_kobo)); }}
                    className={cn("flex w-full items-center gap-3 px-3 py-3 text-left transition-colors hover:bg-muted/70 dark:hover:bg-[#0D1A30]", active === c.id && "bg-muted shadow-[inset_3px_0_0_#F2B233] dark:bg-[#13233F]")}>
                    <span className={cn("grid size-12 shrink-0 place-items-center rounded-full font-bold", active === c.id ? "bg-[#2563B3] text-white" : "bg-[#D9E1EF] text-[#0B1F44] dark:bg-[#1C2D4A] dark:text-[#A7B4CA]")}>{initials(c.name)}</span>
                    <span className="min-w-0 flex-1">
                      <span className="flex items-baseline gap-2">
                        <b className="min-w-0 flex-1 truncate">{c.name}</b>
                        <span className={cn("shrink-0 text-xs", c.unread ? "font-bold text-[#8C600F] dark:text-[#F2B233]" : "text-muted-foreground")}>{listTime(c.last?.at ?? c.created_at)}</span>
                      </span>
                      <span className="flex items-center gap-2">
                        <span className="min-w-0 flex-1 truncate text-sm text-muted-foreground">{c.last?.role === myRole ? "You: " : ""}{preview(c.last)}</span>
                        {c.unread ? <span className="grid h-5 min-w-5 place-items-center rounded-full bg-[#F2B233] px-1.5 text-[11px] font-bold text-[#0B1F44]">{c.unread}</span> : null}
                      </span>
                      <span className="mt-1 flex flex-wrap items-center gap-1.5 text-[11px]">
                        {mode === "admin" ? <span className={cn("rounded-full px-2 py-0.5 font-bold", STATUS[c.status]?.tone)}>{STATUS[c.status]?.label ?? c.status}</span> : null}
                        {mode === "admin" && c.tutor ? <span className="text-muted-foreground">Tutor: {c.tutor}</span> : null}
                        {mode === "admin" && c.status === "paid" && c.paid_at ? <span className="font-bold text-amber-700 dark:text-[#F2B233]">paid {listTime(c.paid_at)}</span> : null}
                        {mode === "admin" && c.custom_note && !c.custom_price_kobo ? <span className="font-bold text-violet-700 dark:text-violet-300">needs a price</span> : null}
                        {mode === "tutor" && c.subject ? <span className="text-muted-foreground">{c.subject}</span> : null}
                        {soon(c) ? <span className="rounded-md bg-[#FDF3E0] px-1.5 py-0.5 font-bold text-[#66450C] dark:bg-[#2B2210] dark:text-[#F9D99A]">ends in {planInfo(c.plan)!.left} days</span> : null}
                      </span>
                    </span>
                  </button>
                </motion.li>
              ))}
            </AnimatePresence>
          )}
        </ul>
      </section>

      {/* Conversation */}
      <section className={cn("relative flex min-h-0 min-w-0 flex-1 flex-col", !active && "hidden lg:flex")} aria-label="Conversation">
        {!chat ? (
          <div className="grid flex-1 place-items-center bg-[#EEF2F8] p-8 text-center dark:bg-[#081224]">
            <div><ChatsCircle size={72} weight="duotone" className="mx-auto text-[#2563B3]" /><p className="mt-3 text-lg font-bold">Pick a chat</p><p className="text-sm text-muted-foreground">Messages arrive here live. Students see when you have read them.</p></div>
          </div>
        ) : (
          <>
            <header className="flex h-16 shrink-0 items-center gap-2 border-b bg-card px-2 dark:bg-[#0B1730] sm:px-3">
              <button type="button" onClick={() => setActive(null)} className="rounded-full p-2 hover:bg-muted lg:hidden" aria-label="Back to chats"><ArrowLeft size={22} /></button>
              <button type="button" onClick={() => setDetails((d) => !d)} className="flex min-w-0 flex-1 items-center gap-3 rounded-xl p-1 text-left hover:bg-muted/60">
                <span className="relative grid size-10 shrink-0 place-items-center rounded-full bg-[#2563B3] text-sm font-bold text-white">
                  {initials(chat.name)}{online ? <span className="absolute bottom-0 right-0 size-3 rounded-full border-2 border-card bg-emerald-500 dark:border-[#0B1730]" /> : null}
                </span>
                <span className="min-w-0">
                  <b className="block truncate">{chat.name}</b>
                  <AnimatePresence mode="wait" initial={false}>
                    <motion.span key={status} initial={rm ? false : { opacity: 0, y: 4 }} animate={{ opacity: 1, y: 0 }} exit={rm ? undefined : { opacity: 0, y: -4 }}
                      className={cn("block truncate text-xs", typing || online ? "font-bold text-emerald-600 dark:text-[#7FD8A6]" : "text-muted-foreground")}>{status}</motion.span>
                  </AnimatePresence>
                </span>
              </button>
              <button type="button" onClick={openStarred} className="rounded-full p-2 hover:bg-muted" aria-label="Starred messages" title="Starred messages"><Star size={21} /></button>
              <button type="button" onClick={() => setDetails((d) => !d)} className={cn("rounded-full p-2 hover:bg-muted", details && "bg-muted")} aria-label="Student details" title="Student details"><IdentificationCard size={22} /></button>
            </header>
            <div ref={scroller} onScroll={() => { const a = !atBottom(); setAway(a); if (!a) setNewBelow(0); if (scroller.current && scroller.current.scrollTop < 200 && older && !loading) void loadOlder(); }}
              className="min-h-0 flex-1 overflow-y-auto bg-[#EEF2F8] px-3 py-3 dark:bg-[#081224] sm:px-6">
              {loading ? <div className="space-y-2">{[60, 40, 70, 30].map((w, i) => <div key={i} className={cn("h-10 animate-pulse rounded-2xl bg-black/5 dark:bg-white/5", i % 2 ? "ml-auto" : "")} style={{ width: `${w}%` }} />)}</div> : null}
              {!loading && !msgs.length ? <p className="py-16 text-center text-sm text-muted-foreground">No messages yet. Say hello to {chat.name.split(" ")[0]}.</p> : null}
              {msgs.map((m, i) => {
                const prev = msgs[i - 1];
                const newDay = !prev || dayLabel(prev.at) !== dayLabel(m.at);
                return (
                  <div key={m.id}>
                    {newDay ? <div className="sticky top-0 z-10 my-3 flex justify-center"><span className="rounded-lg bg-white/95 px-3 py-1 text-xs font-bold text-[#4A5A74] shadow-sm dark:bg-[#13233F] dark:text-[#A7B4CA]">{dayLabel(m.at)}</span></div> : null}
                    <Bubble sb={sb} m={m} me={myRole} first={newDay || !prev || prev.role !== m.role || prev.role === "system"} peer={chat.name} tutor={tutorName}
                      showName={mode === "admin" || m.role === "admin"} onPhoto={setPhoto} onAction={onAction} />
                  </div>
                );
              })}
              {typing ? <Typing name={chat.name} what={typing} /> : null}
            </div>
            <AnimatePresence>
              {away ? (
                <motion.button type="button" initial={rm ? false : { scale: 0 }} animate={{ scale: 1 }} exit={rm ? undefined : { scale: 0 }} onClick={() => { toBottom(); setNewBelow(0); }}
                  className="absolute bottom-24 right-5 grid size-11 place-items-center rounded-full bg-card shadow-lg" aria-label="Go to the newest message">
                  <CaretDown size={20} weight="bold" />
                  {newBelow ? <span className="absolute -right-1 -top-1 rounded-full bg-[#F2B233] px-1.5 text-[11px] font-bold text-[#0B1F44]">{newBelow}</span> : null}
                </motion.button>
              ) : null}
            </AnimatePresence>
            <Composer sb={sb} onSend={send} onTyping={onTyping} staff disabled={readOnly} subjectId={null}
              reply={reply} replyName={reply ? (reply.role === myRole ? "yourself" : reply.role === "student" ? chat.name : reply.role === "tutor" ? tutorName : "SolutionTee") : undefined}
              onCancelReply={() => setReply(null)} />
          </>
        )}
      </section>

      {/* Student details: a side pane on wide screens, a drawer otherwise */}
      <AnimatePresence>
        {chat && details ? (
          <motion.div key="details" initial={rm ? false : { x: 40, opacity: 0 }} animate={{ x: 0, opacity: 1 }} exit={rm ? undefined : { x: 40, opacity: 0 }} transition={{ duration: 0.22 }}
            className="fixed inset-y-0 right-0 z-40 w-full max-w-[380px] border-l shadow-2xl xl:static xl:z-auto xl:w-[360px] xl:shadow-none">
            <Details sb={sb} chat={chat} chats={chats} mode={mode} tutors={tutors} onClose={() => setDetails(false)} onChanged={() => void reload()} />
          </motion.div>
        ) : null}
      </AnimatePresence>

      {photo ? (
        <div className="fixed inset-0 z-50 grid place-items-center bg-black/90 p-4" role="dialog" aria-label="Photo" onClick={() => setPhoto(null)}>
          <button type="button" className="absolute right-4 top-4 rounded-full bg-white/10 p-2 text-white" aria-label="Close photo"><X size={24} /></button>
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img src={photo} alt="Photo in the chat" className="max-h-full max-w-full rounded-lg object-contain" />
        </div>
      ) : null}

      <Dialog open={starred !== null} onOpenChange={(o) => !o && setStarred(null)}>
        <DialogContent className="max-h-[80dvh] overflow-y-auto">
          <DialogHeader><DialogTitle>Starred messages</DialogTitle></DialogHeader>
          {starred?.length ? starred.map((m) => (
            <div key={m.id} className="rounded-xl bg-muted p-3">
              <p className="text-xs font-bold text-muted-foreground">{m.role === myRole ? "You" : m.role === "student" ? chat?.name : "SolutionTee"} · {dayLabel(m.at)}</p>
              <p className="mt-1 whitespace-pre-wrap text-sm">{preview(m)}</p>
            </div>
          )) : <p className="py-6 text-center text-sm text-muted-foreground">Open a message&apos;s menu and choose Star to keep it here.</p>}
        </DialogContent>
      </Dialog>

      <Dialog open={report !== null} onOpenChange={(o) => !o && setReport(null)}>
        <DialogContent>
          <DialogHeader><DialogTitle>Report this message</DialogTitle></DialogHeader>
          <p className="text-sm text-muted-foreground">&ldquo;{quoteText(report ? { ...report } : null)}&rdquo;. Our team will look at it.</p>
          <div className="grid gap-2">
            {["Rude or bullying", "Asked for money or to chat outside SolutionTee", "Wrong or harmful content", "Something else"].map((r) => (
              <button key={r} type="button" className="rounded-xl border px-4 py-3 text-left text-sm font-bold hover:bg-muted" onClick={async () => {
                const m = report; setReport(null);
                if (!m) return;
                const { error } = await sb.rpc("tutor_message_report", { p_message: m.id, p_reason: r });
                if (error) toast.error("Could not send the report."); else toast.success("Thank you. Our team will look at it.");
              }}>{r}</button>
            ))}
          </div>
        </DialogContent>
      </Dialog>
    </div>
  );
}

export { naira };
