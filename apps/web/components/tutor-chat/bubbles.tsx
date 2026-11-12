"use client";
import { useEffect, useRef, useState } from "react";
import type { SupabaseClient } from "@supabase/supabase-js";
import { AnimatePresence, motion, useReducedMotion } from "motion/react";
import { ArrowBendUpLeft, BookOpenText, CaretDown, Check, Checks, Clock, Copy, Exam, FilePdf, Flag, Pause, Play, Plus, Prohibit, Star, Trash, VideoCamera, WarningCircle } from "@phosphor-icons/react";
import { cn } from "@/lib/utils";
import { CALL_COLOR, CALLS, EMOJI, LOGOS, QUICK, callType, fmtDur, fmtSize, linkParts, quoteText, signed, timeOf, type Msg, type Role } from "./lib";

export type MsgAction = { type: "react"; emoji: string } | { type: "reply" } | { type: "copy" } | { type: "star" } | { type: "delete" } | { type: "report" };

function useSigned(sb: SupabaseClient, key: string | null) {
  const [url, setUrl] = useState<string | null>(null);
  const [err, setErr] = useState(false);
  useEffect(() => {
    let live = true;
    if (key) signed(sb, key).then((u) => live && setUrl(u)).catch(() => live && setErr(true));
    return () => { live = false; };
  }, [sb, key]);
  return { url, err };
}

function Photo({ sb, k, onOpen, pending }: { sb: SupabaseClient; k: string; onOpen: (url: string) => void; pending?: boolean }) {
  const { url, err } = useSigned(sb, k);
  if (err) return <div className="grid h-40 w-56 place-items-center rounded-xl bg-black/10 text-xs">Photo not available</div>;
  if (!url) return <div className="h-40 w-56 animate-pulse rounded-xl bg-black/10" />;
  return (
    <button type="button" onClick={() => onOpen(url)} className="relative block overflow-hidden rounded-xl focus-visible:outline-2" aria-label="Open photo">
      {/* eslint-disable-next-line @next/next/no-img-element */}
      <img src={url} alt="Photo in the chat" className="max-h-72 w-auto max-w-[260px] object-cover transition-transform duration-300 hover:scale-[1.02]" loading="lazy" />
      {pending ? <span className="absolute inset-0 grid place-items-center bg-black/30"><span className="size-8 animate-spin rounded-full border-4 border-white/40 border-t-white" /></span> : null}
    </button>
  );
}

/** Voice note: play / pause, a wave that fills as it plays, the time and the speed (1x, 1.5x, 2x). */
function Voice({ sb, k, duration, mine }: { sb: SupabaseClient; k: string; duration?: number; mine: boolean }) {
  const { url, err } = useSigned(sb, k);
  const ref = useRef<HTMLAudioElement>(null);
  const [playing, setPlaying] = useState(false);
  const [pos, setPos] = useState(0);
  const [len, setLen] = useState(duration ?? 0);
  const [speed, setSpeed] = useState(1);
  const [bars] = useState(() => Array.from({ length: 30 }, (_, i) => 0.3 + 0.7 * Math.abs(Math.sin(i * 1.7 + (k.charCodeAt(5) || 3)))));
  const frac = len ? Math.min(1, pos / len) : 0;
  return (
    <div className="flex w-64 items-center gap-2.5 py-1">
      <button type="button" disabled={!url} onClick={() => { const a = ref.current; if (!a) return; if (a.paused) void a.play(); else a.pause(); }}
        className={cn("grid size-10 shrink-0 place-items-center rounded-full text-white transition-transform active:scale-90", mine ? "bg-white/20" : "bg-[#2563B3]")}
        aria-label={playing ? "Pause voice note" : "Play voice note"}>
        {err ? <WarningCircle size={18} /> : playing ? <Pause size={17} weight="fill" /> : <Play size={17} weight="fill" />}
      </button>
      <div className="min-w-0 flex-1">
        <div className="flex h-7 items-center gap-[2px]" aria-hidden="true">
          {bars.map((h, i) => (
            <span key={i} className={cn("w-[3px] rounded-full transition-colors duration-200",
              i / bars.length <= frac && (playing || pos) ? (mine ? "bg-[#F6C970]" : "bg-[#7AA0D1]") : mine ? "bg-white/35" : "bg-current opacity-30")}
              style={{ height: `${h * 100}%` }} />
          ))}
        </div>
        <p className="text-[11px] tabular-nums opacity-75">{fmtDur(playing || pos ? pos : len)}</p>
      </div>
      <button type="button" onClick={() => { const s = speed === 1 ? 1.5 : speed === 1.5 ? 2 : 1; setSpeed(s); if (ref.current) ref.current.playbackRate = s; }}
        className={cn("h-6 min-w-9 rounded-full px-1.5 text-[11px] font-bold", mine ? "bg-white/15" : "bg-current/10")} aria-label="Playback speed">
        <span className={mine ? "" : "text-inherit"}>{speed}x</span>
      </button>
      {url ? <audio ref={ref} src={url} preload="metadata" onPlay={(e) => { e.currentTarget.playbackRate = speed; setPlaying(true); }} onPause={() => setPlaying(false)}
        onEnded={() => { setPlaying(false); setPos(0); }} onTimeUpdate={(e) => setPos(e.currentTarget.currentTime)}
        onLoadedMetadata={(e) => Number.isFinite(e.currentTarget.duration) && setLen(e.currentTarget.duration)} /> : null}
    </div>
  );
}

function FileCard({ sb, m, mine }: { sb: SupabaseClient; m: Msg; mine: boolean }) {
  const [busy, setBusy] = useState(false);
  return (
    <button type="button" disabled={busy} onClick={async () => { setBusy(true); try { window.open(await signed(sb, m.attachment!), "_blank", "noopener,noreferrer"); } finally { setBusy(false); } }}
      className={cn("flex w-64 items-center gap-3 rounded-xl p-2 text-left", mine ? "bg-white/15" : "bg-[#F1F4F9] dark:bg-[#0A1A33]")}>
      <span className="grid size-11 place-items-center rounded-lg bg-[#E5484D] text-white"><FilePdf size={22} weight="fill" /></span>
      <span className="min-w-0 flex-1"><b className="block truncate text-sm">{m.meta?.name ?? "Document.pdf"}</b><span className="text-xs opacity-75">PDF · {fmtSize(m.meta?.size)}</span></span>
    </button>
  );
}

/** The service's real logo (Google Meet, WhatsApp, Zoom) or a plain video icon. */
export function CallLogo({ type, size = 32 }: { type: keyof typeof LOGOS; size?: number }) {
  const src = LOGOS[type];
  if (!src) return <span className="grid place-items-center rounded-full bg-[#2563B3] text-white" style={{ width: size, height: size }}><VideoCamera size={size * 0.5} weight="fill" /></span>;
  // eslint-disable-next-line @next/next/no-img-element
  return <img src={src} alt={CALLS[type].label} style={type === "zoom" ? { width: size * 1.6, height: size * 0.5 } : { width: size, height: size }} className="object-contain" />;
}

function CallCard({ m, mine, from }: { m: Msg; mine: boolean; from: string }) {
  const t = callType(m.meta);
  const name = CALLS[t].label === "Video link" ? "Video" : CALLS[t].label;
  return (
    <div className={cn("w-[270px] overflow-hidden rounded-xl", mine ? "bg-white/12" : "bg-[#F1F4F9] dark:bg-[#0A1A33]")}>
      <div className="flex items-center gap-3 p-3">
        <span className="grid size-12 shrink-0 place-items-center rounded-xl bg-white"><CallLogo type={t} size={t === "zoom" ? 26 : 32} /></span>
        <span className="min-w-0">
          <b className="block text-sm leading-snug">{m.body || `${name} call`}</b>
          <span className="block truncate text-xs opacity-75">{name} · {mine ? "from you" : `from ${from.split(" ")[0]}`}</span>
        </span>
      </div>
      <a href={m.meta?.url} target="_blank" rel="noopener noreferrer" style={{ background: CALL_COLOR[t] }}
        className="block py-2.5 text-center text-sm font-bold text-white transition-[filter] hover:brightness-110">Join with {name}</a>
    </div>
  );
}

function RefCard({ m, mine }: { m: Msg; mine: boolean }) {
  const pq = m.ref?.type === "pq";
  return (
    <div className={cn("w-[270px] rounded-xl border-l-[3px] border-[#F2B233] px-3 py-2.5", mine ? "bg-white/12" : "bg-[#F1F4F9] dark:bg-[#0A1A33]")}>
      <p className={cn("flex items-center gap-1.5 text-[11px] font-bold uppercase tracking-wide", mine ? "text-[#F6C970]" : "text-[#8C600F] dark:text-[#F2B233]")}>
        {pq ? <Exam size={14} weight="fill" /> : <BookOpenText size={14} weight="fill" />}<span className="truncate">{m.ref?.title ?? "Study link"}</span>
      </p>
      {m.ref?.snippet ? <p className="mt-1 line-clamp-3 text-[13.5px] leading-snug">{m.ref.snippet}</p> : null}
      <p className="mt-1.5 text-[11px] font-bold opacity-75">{pq ? "Past question" : "Lesson"} · opens in the SolutionTee app</p>
    </div>
  );
}

const who = (role: Role, me: Role, peer: string, tutor: string) => (role === me ? "You" : role === "student" ? peer : role === "tutor" ? tutor : "SolutionTee");

/**
 * One message (D-153). Mine on the right (navy, blue in dark mode), theirs on the left; system notes in the middle.
 * Hover (or right-click, or press and hold on a phone) for the menu: reactions, reply, copy, star, delete, report.
 */
export function Bubble({ sb, m, me, first, peer, tutor, onPhoto, onAction, showName }: {
  sb: SupabaseClient; m: Msg; me: Role; first: boolean; peer: string; tutor: string; onPhoto: (url: string) => void; onAction: (m: Msg, a: MsgAction) => void; showName?: boolean;
}) {
  const rm = useReducedMotion();
  const [menu, setMenu] = useState(false);
  const [more, setMore] = useState(false);
  const [openedAt, setOpenedAt] = useState(0);
  const open = () => { setOpenedAt(Date.now()); setMenu(true); };
  const hold = useRef<ReturnType<typeof setTimeout> | null>(null);
  const box = useRef<HTMLDivElement>(null);
  const mine = m.role === me;
  useEffect(() => {
    if (!menu) return;
    const close = (e: MouseEvent) => { if (!box.current?.contains(e.target as Node)) { setMenu(false); setMore(false); } };
    const esc = (e: KeyboardEvent) => { if (e.key === "Escape") { setMenu(false); setMore(false); } };
    document.addEventListener("mousedown", close);
    document.addEventListener("keydown", esc);
    return () => { document.removeEventListener("mousedown", close); document.removeEventListener("keydown", esc); };
  }, [menu]);

  if (m.role === "system") {
    return <div className="my-2 flex justify-center"><span className="max-w-[85%] rounded-lg bg-[#FDF3E0] px-3 py-1.5 text-center text-xs text-[#66450C] dark:bg-[#2B2210] dark:text-[#F9D99A]">{m.body}</span></div>;
  }
  const media = !m.deleted && (m.kind === "image" || m.kind === "link" || m.kind === "ref");
  const reactions = Object.values(m.reactions ?? {}).filter(Boolean) as string[];
  const act = (a: MsgAction) => { setMenu(false); setMore(false); onAction(m, a); };
  const canDelete = mine && !m.deleted && !m.pending && (me === "admin" || openedAt - new Date(m.at).getTime() < 48 * 3600 * 1000);
  const my = m.reactions?.[me];

  return (
    <motion.div initial={rm ? false : { opacity: 0, x: mine ? 14 : -14, scale: 0.97 }} animate={{ opacity: 1, x: 0, scale: 1 }} transition={{ duration: 0.22, ease: "easeOut" }}
      className={cn("group flex", mine ? "justify-end" : "justify-start", first ? "mt-2.5" : "mt-0.5", reactions.length && "mb-3")}>
      <div ref={box} className={cn("relative max-w-[min(78%,520px)]", mine ? "items-end" : "items-start")}
        onContextMenu={(e) => { if (m.pending) return; e.preventDefault(); open(); }}
        onPointerDown={(e) => { if (e.pointerType !== "touch" || m.pending) return; hold.current = setTimeout(open, 450); }}
        onPointerUp={() => { if (hold.current) clearTimeout(hold.current); }} onPointerLeave={() => { if (hold.current) clearTimeout(hold.current); }}>
        <div className={cn("relative rounded-[18px]", media ? "p-[5px]" : "px-3 pb-1.5 pt-2",
          mine ? "bg-[#0B1F44] text-white dark:bg-[#1E5BB0]" : "bg-white text-[#0B1F44] shadow-[0_1px_2px_rgba(11,31,68,.08)] dark:bg-[#13233F] dark:text-[#EAF0FA] dark:shadow-none",
          first && (mine ? "rounded-tr-md" : "rounded-tl-md"), menu && "ring-2 ring-[#F2B233]")}>
          {showName && !mine && first ? <p className={cn("mb-0.5 text-xs font-bold text-[#2563B3] dark:text-[#F2B233]", media && "px-1.5 pt-0.5")}>{who(m.role, me, peer, tutor)}</p> : null}
          {m.reply ? (
            <div className={cn("mb-1.5 rounded-[10px] border-l-[3px] border-[#F2B233] px-2.5 py-1.5", mine ? "bg-white/14" : "bg-[#F1F4F9] dark:bg-[#0A1A33]")}>
              <p className={cn("text-xs font-bold", mine ? "text-[#F6C970]" : "text-[#2563B3] dark:text-[#F2B233]")}>{who(m.reply.role, me, peer, tutor)}</p>
              <p className="line-clamp-2 text-[13px] opacity-80">{quoteText(m.reply)}</p>
            </div>
          ) : null}
          {m.deleted ? (
            <p className="flex items-center gap-1.5 text-[15px] italic opacity-70"><Prohibit size={16} />{mine ? "You deleted this message" : "This message was deleted"}</p>
          ) : (
            <>
              {m.kind === "image" && m.attachment ? <Photo sb={sb} k={m.attachment} onOpen={onPhoto} pending={m.pending} /> : null}
              {m.kind === "voice" && m.attachment ? <Voice sb={sb} k={m.attachment} duration={m.meta?.duration} mine={mine} /> : null}
              {m.kind === "voice" && !m.attachment && m.pending ? <p className="flex items-center gap-2 py-2 text-sm opacity-80"><span className="size-4 animate-spin rounded-full border-2 border-current border-t-transparent" /> Sending voice note…</p> : null}
              {m.kind === "file" && m.attachment ? <FileCard sb={sb} m={m} mine={mine} /> : null}
              {m.kind === "link" ? <CallCard m={m} mine={mine} from={who(m.role, me, peer, tutor)} /> : null}
              {m.kind === "ref" ? <RefCard m={m} mine={mine} /> : null}
              {m.kind === "text" || (m.body && m.kind === "image") ? (
                <p className={cn("whitespace-pre-wrap break-words text-[15px] leading-[1.38]", media && "px-2 pt-1", /^(\p{Extended_Pictographic}|‍|️|\s){1,8}$/u.test(m.body) && "text-4xl leading-tight")}>
                  {linkParts(m.body).map((p, i) => p.href ? <a key={i} href={p.href} target="_blank" rel="noopener noreferrer" className={cn("underline underline-offset-2", mine ? "text-[#F6C970]" : "text-[#2563B3] dark:text-[#98B6DB]")}>{p.t}</a> : <span key={i}>{p.t}</span>)}
                </p>
              ) : null}
            </>
          )}
          <span className={cn("mt-0.5 flex items-center justify-end gap-1 text-[11px] tabular-nums", media && "px-1.5 pb-0.5", mine ? "text-white/70" : "text-[#6B7A93] dark:text-[#8090AA]")}>
            {m.starred ? <Star size={11} weight="fill" aria-label="Starred" /> : null}
            {timeOf(m.at)}
            {mine && !m.deleted ? (m.failed ? <WarningCircle size={14} className="text-[#F6C970]" aria-label="Not sent" />
              : m.pending ? <Clock size={13} aria-label="Sending" />
              : m.read_at ? <Checks size={16} weight="bold" className="text-[#7DD3FC]" aria-label="Seen" />
              : <Check size={14} weight="bold" aria-label="Sent" />) : null}
          </span>
          {!m.pending && !menu ? (
            <button type="button" onClick={open} aria-label="Message options"
              className={cn("absolute right-1.5 top-1.5 grid size-6 place-items-center rounded-full opacity-0 transition-opacity focus-visible:opacity-100 group-hover:opacity-100",
                mine ? "bg-[#0B1F44]/80 text-white dark:bg-[#1E5BB0]/90" : "bg-white/90 text-[#0B1F44] dark:bg-[#13233F]/90 dark:text-white")}>
              <CaretDown size={14} weight="bold" />
            </button>
          ) : null}
        </div>
        {reactions.length ? (
          <motion.button type="button" key={reactions.join("")} onClick={open} initial={rm ? false : { scale: 0.4 }} animate={{ scale: 1 }} transition={{ type: "spring", stiffness: 420, damping: 18 }}
            className={cn("absolute -bottom-3.5 rounded-full border-2 border-[#EEF2F8] bg-white px-1.5 text-[13px] shadow-sm dark:border-[#081224] dark:bg-[#13233F]", mine ? "right-3" : "left-3")}
            aria-label={`Reactions ${reactions.join(" ")}`}>
            {[...new Set(reactions)].join("")}{reactions.length > 1 ? <span className="ml-0.5 text-[11px] font-bold opacity-70">{reactions.length}</span> : null}
          </motion.button>
        ) : null}
        <AnimatePresence>
          {menu ? (
            <motion.div initial={rm ? false : { opacity: 0, scale: 0.94, y: -4 }} animate={{ opacity: 1, scale: 1, y: 0 }} exit={rm ? undefined : { opacity: 0, scale: 0.96 }} transition={{ duration: 0.16 }}
              className={cn("absolute top-full z-30 mt-2 w-64 origin-top", mine ? "right-0" : "left-0")}>
              {!m.deleted ? (
                <div className="mb-2 flex items-center rounded-full border bg-popover px-1 py-1 shadow-lg">
                  {QUICK.map((e, i) => (
                    <motion.button key={e} type="button" onClick={() => act({ type: "react", emoji: e })} aria-label={`React ${e}`}
                      initial={rm ? false : { scale: 0.3 }} animate={{ scale: 1 }} transition={{ delay: i * 0.025, type: "spring", stiffness: 500, damping: 20 }}
                      className={cn("grid size-9 place-items-center rounded-full text-xl transition-transform hover:scale-125", my === e && "bg-muted")}>{e}</motion.button>
                  ))}
                  <button type="button" onClick={() => setMore((x) => !x)} className="grid size-9 place-items-center rounded-full text-muted-foreground hover:bg-muted" aria-label="More emoji"><Plus size={16} weight="bold" /></button>
                </div>
              ) : null}
              {more ? (
                <div className="mb-2 max-h-48 overflow-y-auto rounded-2xl border bg-popover p-2 shadow-lg">
                  {EMOJI.map(([g, list]) => (
                    <div key={g}><p className="px-1 pt-1 text-[11px] font-bold text-muted-foreground">{g}</p>
                      <div className="grid grid-cols-8">{list.map((e) => <button key={g + e} type="button" onClick={() => act({ type: "react", emoji: e })} className="grid size-7 place-items-center rounded text-lg hover:bg-muted">{e}</button>)}</div>
                    </div>
                  ))}
                </div>
              ) : null}
              <div className="overflow-hidden rounded-2xl border bg-popover py-1 text-popover-foreground shadow-lg">
                {!m.deleted ? <MenuItem icon={ArrowBendUpLeft} label="Reply" onClick={() => act({ type: "reply" })} /> : null}
                {!m.deleted && (m.kind === "text" || m.kind === "link") ? <MenuItem icon={Copy} label="Copy" onClick={() => act({ type: "copy" })} /> : null}
                {!m.deleted ? <MenuItem icon={Star} label={m.starred ? "Unstar" : "Star"} onClick={() => act({ type: "star" })} /> : null}
                {canDelete ? <MenuItem icon={Trash} label="Delete for everyone" onClick={() => act({ type: "delete" })} danger /> : null}
                {!mine && !m.deleted && me !== "admin" ? <MenuItem icon={Flag} label="Report" onClick={() => act({ type: "report" })} danger /> : null}
              </div>
            </motion.div>
          ) : null}
        </AnimatePresence>
      </div>
    </motion.div>
  );
}

function MenuItem({ icon: I, label, onClick, danger }: { icon: typeof Copy; label: string; onClick: () => void; danger?: boolean }) {
  return (
    <button type="button" onClick={onClick} className={cn("flex w-full items-center justify-between gap-6 px-4 py-2.5 text-left text-sm hover:bg-muted", danger && "text-red-600")}>
      {label}<I size={18} className={danger ? "" : "text-muted-foreground"} />
    </button>
  );
}

/** Three bouncing dots while the other person types. */
export function Typing({ name, what }: { name: string; what?: string }) {
  const rm = useReducedMotion();
  return (
    <motion.div initial={rm ? false : { opacity: 0, y: 6 }} animate={{ opacity: 1, y: 0 }} className="mt-2 flex items-center gap-2">
      <div className="flex gap-1 rounded-2xl bg-white px-3.5 py-3 shadow-sm dark:bg-[#13233F]" aria-label={`${name} is ${what ?? "typing"}`}>
        {[0, 1, 2].map((i) => (
          <motion.span key={i} className="size-[7px] rounded-full bg-[#8090AA]"
            animate={rm ? undefined : { y: [0, -4, 0] }} transition={{ duration: 0.9, repeat: Infinity, delay: i * 0.15 }} />
        ))}
      </div>
    </motion.div>
  );
}
