"use client";
import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import type { RealtimeChannel } from "@supabase/supabase-js";
import { AnimatePresence, motion, useReducedMotion } from "motion/react";
import { toast } from "sonner";
import { ArrowLeft, ChatsCircle, IdentificationCard, MagnifyingGlass, X } from "@phosphor-icons/react";
import { createClient } from "@/lib/supabase/client";
import { cn } from "@/lib/utils";
import { Bubble, Typing } from "./bubbles";
import { Composer, type SendFn } from "./composer";
import { Details } from "./details";
import { dayLabel, fromRow, initials, listTime, naira, planInfo, preview, upload, type Chat, type Msg, type TutorOpt } from "./lib";

const STATUS: Record<string, { label: string; tone: string }> = {
  new: { label: "Choosing a plan", tone: "bg-slate-100 text-slate-700 dark:bg-slate-800 dark:text-slate-200" },
  quoted: { label: "Price sent", tone: "bg-violet-100 text-violet-700 dark:bg-violet-950 dark:text-violet-200" },
  paid: { label: "Needs a tutor", tone: "bg-amber-100 text-amber-800 dark:bg-amber-950 dark:text-amber-200" },
  matched: { label: "Active", tone: "bg-emerald-100 text-emerald-700 dark:bg-emerald-950 dark:text-emerald-200" },
  ended: { label: "Plan ended", tone: "bg-slate-100 text-slate-500 dark:bg-slate-800" },
  closed: { label: "Closed", tone: "bg-slate-100 text-slate-500 dark:bg-slate-800" },
};
const FILTERS = [["open", "Open"], ["paid", "Needs a tutor"], ["new", "Choosing"], ["matched", "Active"], ["ended", "Ended"], ["all", "All"]] as const;

/**
 * WhatsApp-style tutor chat (D-152) for tutors (/admin/tutor: only their students) and admins (/admin/tutors: every
 * request, assignment and custom prices). Live through Supabase Realtime: messages (RLS), typing and online (private
 * broadcast/presence channel "tutor:<id>" with RLS on realtime.messages).
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
  const [typing, setTyping] = useState(false);
  const [online, setOnline] = useState(false);
  const [details, setDetails] = useState(false);
  const [photo, setPhoto] = useState<string | null>(null);
  const scroller = useRef<HTMLDivElement>(null);
  const channel = useRef<RealtimeChannel | null>(null);
  const lastTyping = useRef(0);
  const typingTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const tempId = useRef(-1);
  const myRole = mode === "tutor" ? "tutor" : "admin";

  const chat = chats.find((c) => c.id === active) ?? null;
  const reload = useCallback(async () => {
    const { data } = await sb.rpc("tutor_chats", { p_scope: mode === "tutor" ? "mine" : "all" });
    if (data) setChats(data as unknown as Chat[]);
  }, [sb, mode]);

  const atBottom = () => { const el = scroller.current; return !el || el.scrollHeight - el.scrollTop - el.clientHeight < 120; };
  const toBottom = (smooth = true) => requestAnimationFrame(() => scroller.current?.scrollTo({ top: scroller.current.scrollHeight, behavior: smooth && !rm ? "smooth" : "auto" }));

  // List: any new message in chats I can see (RLS) refreshes the list.
  useEffect(() => {
    const ch = sb.channel(`tutor-list-${mode}`).on("postgres_changes", { event: "*", schema: "public", table: "tutor_messages" }, () => { void reload(); }).subscribe();
    const t = setInterval(() => void reload(), 60_000);
    return () => { void sb.removeChannel(ch); clearInterval(t); };
  }, [sb, mode, reload]);

  const markRead = useCallback(async (id: string) => {
    if (document.visibilityState !== "visible") return;
    const { data } = await sb.rpc("tutor_mark_read", { p_request: id });
    if (data) setChats((cs) => cs.map((c) => (c.id === id ? { ...c, unread: 0 } : c)));
  }, [sb]);

  // Open chat: history, live messages, typing and online.
  useEffect(() => {
    if (!active) return;
    let live = true;
    queueMicrotask(() => { setLoading(true); setMsgs([]); setTyping(false); setOnline(false); setOlder(true); });
    void (async () => {
      const { data } = await sb.from("tutor_messages").select("*").eq("request_id", active).order("id", { ascending: false }).limit(80);
      if (!live) return;
      const rows = (data ?? []).map((r) => fromRow(r as Record<string, unknown>)).reverse();
      setMsgs(rows); setOlder(rows.length >= 80); setLoading(false); toBottom(false);
      void markRead(active);
    })();
    void sb.realtime.setAuth();
    const ch = sb.channel(`tutor:${active}`, { config: { private: true, broadcast: { self: false }, presence: { key: myRole } } })
      .on("postgres_changes", { event: "INSERT", schema: "public", table: "tutor_messages", filter: `request_id=eq.${active}` }, (p) => {
        const m = fromRow(p.new as Record<string, unknown>);
        const stick = atBottom();
        setMsgs((ms) => (ms.some((x) => x.id === m.id) ? ms : [...ms.filter((x) => !(x.pending && x.kind === m.kind && x.body === m.body && m.role === myRole)), m]));
        if (m.role === "student") { setTyping(false); void markRead(active); }
        if (stick || m.role === myRole) toBottom();
      })
      .on("postgres_changes", { event: "UPDATE", schema: "public", table: "tutor_messages", filter: `request_id=eq.${active}` }, (p) => {
        const m = fromRow(p.new as Record<string, unknown>);
        setMsgs((ms) => ms.map((x) => (x.id === m.id ? { ...x, read_at: m.read_at } : x)));
      })
      .on("broadcast", { event: "typing" }, (p) => {
        if ((p.payload as { role?: string })?.role !== "student") return;
        setTyping(true);
        if (typingTimer.current) clearTimeout(typingTimer.current);
        typingTimer.current = setTimeout(() => setTyping(false), 4000);
      })
      .on("presence", { event: "sync" }, () => setOnline(Object.keys(ch.presenceState()).includes("student")))
      .subscribe((s) => { if (s === "SUBSCRIBED") void ch.track({ role: myRole, at: Date.now() }); });
    channel.current = ch;
    const onVis = () => void markRead(active);
    document.addEventListener("visibilitychange", onVis);
    return () => { live = false; document.removeEventListener("visibilitychange", onVis); void sb.removeChannel(ch); channel.current = null; };
  }, [sb, active, myRole, markRead]); // eslint-disable-line react-hooks/exhaustive-deps

  async function loadOlder() {
    if (!active || !msgs.length) return;
    const el = scroller.current, h = el?.scrollHeight ?? 0;
    const { data } = await sb.rpc("tutor_messages_before", { p_request: active, p_before: msgs[0].id, p_limit: 60 });
    const rows = ((data ?? []) as unknown as Record<string, unknown>[]).map(fromRow);
    setOlder(rows.length >= 60);
    setMsgs((ms) => [...rows, ...ms]);
    requestAnimationFrame(() => { if (el) el.scrollTop = el.scrollHeight - h; });
  }

  const onTyping = () => {
    if (Date.now() - lastTyping.current < 2500) return;
    lastTyping.current = Date.now();
    void channel.current?.send({ type: "broadcast", event: "typing", payload: { role: myRole } });
  };

  const send: SendFn = async (kind, body, extra) => {
    if (!active) return;
    const id = tempId.current--;
    const temp: Msg = { id, role: myRole, kind, body, attachment: null, at: new Date().toISOString(), read_at: null, meta: extra?.meta ?? null, ref: extra?.ref ?? null, pending: true };
    setMsgs((ms) => [...ms, temp]);
    toBottom();
    try {
      let key: string | undefined;
      if (extra?.file) key = await upload(sb, active, extra.file, extra.contentType ?? extra.file.type);
      const { data, error } = await sb.rpc("tutor_message_send", { p_request: active, p_body: body, p_kind: kind, p_attachment: key, p_meta: extra?.meta ?? undefined, p_ref: extra?.ref ?? undefined });
      const d = (data ?? {}) as { ok?: boolean; error?: string; message?: Record<string, unknown> };
      if (error || !d.ok || !d.message) throw new Error(d.error === "too_many" ? "Slow down a little." : "Not sent. Tap to try again.");
      const m = fromRow(d.message);
      setMsgs((ms) => (ms.some((x) => x.id === m.id) ? ms.filter((x) => x.id !== id) : ms.map((x) => (x.id === id ? m : x))));
    } catch (e) {
      setMsgs((ms) => ms.map((x) => (x.id === id ? { ...x, pending: false, failed: true } : x)));
      toast.error(e instanceof Error ? e.message : "Not sent.");
    }
  };

  const shown = chats.filter((c) => (mode === "tutor" || filter === "all" || (filter === "open" ? ["new", "quoted", "paid", "matched"].includes(c.status) : c.status === filter))
    && (!q || c.name.toLowerCase().includes(q.toLowerCase()) || (c.subject ?? "").toLowerCase().includes(q.toLowerCase())));
  const unreadTotal = chats.reduce((n, c) => n + (c.unread || 0), 0);
  const needTutor = chats.filter((c) => c.status === "paid").length;
  const readOnly = chat && mode === "tutor" && chat.status !== "matched" ? "This student's plan has ended. You can read the chat." : undefined;
  const otherName = chat?.name ?? "";

  return (
    <div className={cn("flex min-h-0 overflow-hidden bg-background", className)}>
      {/* Chat list */}
      <section className={cn("flex min-h-0 w-full flex-col border-r bg-card lg:w-[360px] lg:shrink-0", active && "hidden lg:flex")} aria-label="Chats">
        <div className="space-y-3 border-b p-3">
          <div className="flex items-center gap-2">
            <h2 className="flex-1 text-xl font-bold">{mode === "tutor" ? "My students" : "Tutor requests"}</h2>
            {unreadTotal ? <span className="rounded-full bg-emerald-500 px-2 py-0.5 text-xs font-bold text-white">{unreadTotal} new</span> : null}
          </div>
          <label className="flex items-center gap-2 rounded-full bg-muted px-3">
            <MagnifyingGlass size={18} className="text-muted-foreground" />
            <input value={q} onChange={(e) => setQ(e.target.value)} placeholder="Search students" aria-label="Search students" className="h-10 flex-1 bg-transparent text-sm outline-none" />
          </label>
          {mode === "admin" ? (
            <div className="-mx-1 flex gap-1.5 overflow-x-auto px-1 pb-0.5">
              {FILTERS.map(([k, l]) => (
                <button key={k} type="button" onClick={() => setFilter(k)}
                  className={cn("shrink-0 rounded-full px-3 py-1.5 text-xs font-bold transition-colors", filter === k ? "bg-primary text-primary-foreground" : "bg-muted text-muted-foreground hover:text-foreground")}>
                  {l}{k === "paid" && needTutor ? ` · ${needTutor}` : ""}
                </button>
              ))}
            </div>
          ) : null}
        </div>
        <ul className="min-h-0 flex-1 overflow-y-auto">
          {shown.length === 0 ? (
            <li className="grid place-items-center gap-2 p-10 text-center text-sm text-muted-foreground">
              <ChatsCircle size={40} />{mode === "tutor" ? "No students yet. When an admin assigns a student to you, they show here and you get an email." : "No requests here."}
            </li>
          ) : (
            <AnimatePresence initial={false}>
              {shown.map((c) => (
                <motion.li key={c.id} layout={!rm} initial={rm ? false : { opacity: 0 }} animate={{ opacity: 1 }}>
                  <button type="button" onClick={() => { setActive(c.id); setDetails(false); }}
                    className={cn("flex w-full items-center gap-3 px-3 py-3 text-left transition-colors hover:bg-muted/70", active === c.id && "bg-muted")}>
                    <span className="grid size-12 shrink-0 place-items-center rounded-full bg-gradient-to-br from-[#2563B3] to-[#0B1F44] font-bold text-white">{initials(c.name)}</span>
                    <span className="min-w-0 flex-1 border-b pb-3 pt-1 [li:last-child_&]:border-0">
                      <span className="flex items-baseline gap-2">
                        <b className="min-w-0 flex-1 truncate">{c.name}</b>
                        <span className={cn("shrink-0 text-xs", c.unread ? "font-bold text-emerald-600" : "text-muted-foreground")}>{listTime(c.last?.at ?? c.created_at)}</span>
                      </span>
                      <span className="flex items-center gap-2">
                        <span className="min-w-0 flex-1 truncate text-sm text-muted-foreground">{c.last?.role === myRole ? "You: " : ""}{preview(c.last)}</span>
                        {c.unread ? <span className="grid h-5 min-w-5 place-items-center rounded-full bg-emerald-500 px-1.5 text-[11px] font-bold text-white">{c.unread}</span> : null}
                      </span>
                      {mode === "admin" ? (
                        <span className="mt-1 flex flex-wrap items-center gap-1.5 text-[11px]">
                          <span className={cn("rounded-full px-2 py-0.5 font-bold", STATUS[c.status]?.tone)}>{STATUS[c.status]?.label ?? c.status}</span>
                          {c.tutor ? <span className="text-muted-foreground">Tutor: {c.tutor}</span> : null}
                          {c.status === "paid" && c.paid_at ? <span className="font-bold text-amber-700">paid {listTime(c.paid_at)}</span> : null}
                          {c.custom_note && !c.custom_price_kobo ? <span className="font-bold text-violet-700">custom plan asked</span> : null}
                        </span>
                      ) : c.subject ? <span className="text-[11px] text-muted-foreground">{c.subject}</span> : null}
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
          <div className="grid flex-1 place-items-center bg-[radial-gradient(circle_at_top,theme(colors.sky.100),transparent_60%)] p-8 text-center dark:bg-none">
            <div><ChatsCircle size={72} weight="duotone" className="mx-auto text-primary" /><p className="mt-3 text-lg font-bold">Pick a chat</p><p className="text-sm text-muted-foreground">Messages arrive here live. Students see when you have read them.</p></div>
          </div>
        ) : (
          <>
            <header className="flex h-16 shrink-0 items-center gap-2 border-b bg-card px-2 sm:px-3">
              <button type="button" onClick={() => setActive(null)} className="rounded-full p-2 hover:bg-muted lg:hidden" aria-label="Back to chats"><ArrowLeft size={22} /></button>
              <button type="button" onClick={() => setDetails((d) => !d)} className="flex min-w-0 flex-1 items-center gap-3 rounded-xl p-1 text-left hover:bg-muted/60">
                <span className="relative grid size-10 shrink-0 place-items-center rounded-full bg-gradient-to-br from-[#2563B3] to-[#0B1F44] text-sm font-bold text-white">
                  {initials(chat.name)}{online ? <span className="absolute bottom-0 right-0 size-3 rounded-full border-2 border-card bg-emerald-500" /> : null}
                </span>
                <span className="min-w-0">
                  <b className="block truncate">{chat.name}</b>
                  <span className={cn("block truncate text-xs", typing ? "font-bold text-emerald-600" : "text-muted-foreground")}>
                    {typing ? "typing…" : online ? "online" : [chat.subject, planInfo(chat.plan) ? `${planInfo(chat.plan)!.left} days left` : STATUS[chat.status]?.label].filter(Boolean).join(" · ")}
                  </span>
                </span>
              </button>
              <button type="button" onClick={() => setDetails((d) => !d)} className="rounded-full p-2 hover:bg-muted" aria-label="Student details"><IdentificationCard size={22} /></button>
            </header>
            <div ref={scroller} className="min-h-0 flex-1 overflow-y-auto bg-[#efeae2] px-3 py-3 dark:bg-[#0b141a] sm:px-6"
              style={{ backgroundImage: "radial-gradient(rgba(11,31,68,.06) 1px, transparent 1px)", backgroundSize: "18px 18px" }}>
              {older && msgs.length ? <div className="mb-2 text-center"><button type="button" onClick={loadOlder} className="rounded-full bg-card px-3 py-1 text-xs font-bold shadow">Load earlier messages</button></div> : null}
              {loading ? <div className="space-y-2">{[60, 40, 70, 30].map((w, i) => <div key={i} className={cn("h-10 animate-pulse rounded-2xl bg-black/5", i % 2 ? "ml-auto" : "")} style={{ width: `${w}%` }} />)}</div> : null}
              {msgs.map((m, i) => {
                const prev = msgs[i - 1];
                const newDay = !prev || dayLabel(prev.at) !== dayLabel(m.at);
                const mine = m.role === myRole;
                return (
                  <div key={m.id}>
                    {newDay ? <div className="sticky top-0 z-10 my-3 flex justify-center"><span className="rounded-lg bg-card/90 px-3 py-1 text-xs font-bold text-muted-foreground shadow-sm backdrop-blur">{dayLabel(m.at)}</span></div> : null}
                    <Bubble sb={sb} m={m} mine={mine} first={newDay || !prev || prev.role !== m.role}
                      who={m.role === "student" ? undefined : m.role === "tutor" ? chat.tutor ?? "Tutor" : "SolutionTee"} onPhoto={setPhoto} />
                  </div>
                );
              })}
              {typing ? <Typing name={otherName} /> : null}
            </div>
            <Composer sb={sb} onSend={send} onTyping={onTyping} staff disabled={readOnly} subjectId={null} />
          </>
        )}
      </section>

      {/* Student details: a side pane on wide screens, a drawer otherwise */}
      <AnimatePresence>
        {chat && details ? (
          <motion.div key="details" initial={rm ? false : { x: 40, opacity: 0 }} animate={{ x: 0, opacity: 1 }} exit={rm ? undefined : { x: 40, opacity: 0 }} transition={{ duration: 0.22 }}
            className="fixed inset-y-0 right-0 z-40 w-full max-w-[380px] border-l shadow-2xl xl:static xl:z-auto xl:w-[360px] xl:shadow-none">
            <Details sb={sb} chat={chat} mode={mode} tutors={tutors} onClose={() => setDetails(false)} onChanged={() => void reload()} />
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
    </div>
  );
}

export { naira };
