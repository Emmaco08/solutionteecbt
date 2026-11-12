"use client";
import { useEffect, useRef, useState } from "react";
import type { SupabaseClient } from "@supabase/supabase-js";
import { AnimatePresence, motion, useReducedMotion } from "motion/react";
import { toast } from "sonner";
import { BookOpenText, Books, Image as ImageIcon, Microphone, PaperPlaneRight, Paperclip, Pause, Smiley, Trash, VideoCamera, X } from "@phosphor-icons/react";
import { Button } from "@/components/ui/button";
import { Dialog, DialogContent, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { DropdownMenu, DropdownMenuContent, DropdownMenuItem, DropdownMenuTrigger } from "@/components/ui/dropdown-menu";
import { cn } from "@/lib/utils";
import { CallLogo } from "./bubbles";
import { CALLS, EMOJI, fmtDur, quoteText, type CallType, type Msg } from "./lib";

export type SendFn = (kind: Msg["kind"], body: string, extra?: { file?: Blob; contentType?: string; meta?: Msg["meta"]; ref?: Msg["ref"] }) => Promise<void>;

const inputCls = "w-full rounded-xl border bg-background px-3 py-2 text-sm outline-none focus-visible:ring-2 focus-visible:ring-ring";

/** Picks a voice format the browser can record (Chrome: webm/opus, Safari: mp4/aac). */
function voiceType() {
  for (const t of ["audio/webm;codecs=opus", "audio/webm", "audio/mp4", "audio/ogg"]) if (typeof MediaRecorder !== "undefined" && MediaRecorder.isTypeSupported(t)) return t;
  return "";
}

/** Shrinks a photo to 1600 px (JPEG) before upload so chats stay light on data. */
async function shrink(file: File): Promise<Blob> {
  if (!file.type.startsWith("image/") || file.size < 400_000) return file;
  const img = await createImageBitmap(file);
  const scale = Math.min(1, 1600 / Math.max(img.width, img.height));
  const c = document.createElement("canvas");
  c.width = Math.round(img.width * scale); c.height = Math.round(img.height * scale);
  c.getContext("2d")!.drawImage(img, 0, 0, c.width, c.height);
  return await new Promise<Blob>((res) => c.toBlob((b) => res(b ?? file), "image/jpeg", 0.82));
}

export function Composer({ sb, onSend, onTyping, disabled, staff, subjectId, reply, replyName, onCancelReply }: {
  sb: SupabaseClient; onSend: SendFn; onTyping: (voice?: boolean) => void; disabled?: string; staff: boolean; subjectId?: number | null;
  reply?: Msg | null; replyName?: string; onCancelReply?: () => void;
}) {
  const rm = useReducedMotion();
  const [text, setText] = useState("");
  const [rec, setRec] = useState<{ paused: boolean } | null>(null);
  const recorder = useRef<{ mr: MediaRecorder; chunks: Blob[]; done: number; since: number; timer: ReturnType<typeof setInterval>; ctx?: AudioContext; an?: AnalyserNode } | null>(null);
  const [elapsed, setElapsed] = useState(0);
  const [levels, setLevels] = useState<number[]>([]);
  const [call, setCall] = useState<CallType | null>(null);
  const [refKind, setRefKind] = useState<"pq" | "lesson" | null>(null);
  const [emoji, setEmoji] = useState(false);
  const [tab, setTab] = useState(0);
  const fileRef = useRef<HTMLInputElement>(null);
  const area = useRef<HTMLTextAreaElement>(null);

  useEffect(() => {
    const a = area.current;
    if (a) { a.style.height = "auto"; a.style.height = `${Math.min(a.scrollHeight, 160)}px`; }
  }, [text]);
  useEffect(() => { if (reply) area.current?.focus(); }, [reply]);

  const send = () => {
    const t = text.trim();
    if (!t) return;
    setText("");
    setEmoji(false);
    void onSend("text", t);
  };

  const addEmoji = (e: string) => {
    const a = area.current;
    const at = a?.selectionStart ?? text.length, end = a?.selectionEnd ?? text.length;
    setText(text.slice(0, at) + e + text.slice(end));
    requestAnimationFrame(() => { a?.focus(); a?.setSelectionRange(at + e.length, at + e.length); });
  };

  async function startRec() {
    try {
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
      const type = voiceType();
      const mr = new MediaRecorder(stream, type ? { mimeType: type } : undefined);
      const chunks: Blob[] = [];
      mr.ondataavailable = (e) => { if (e.data.size) chunks.push(e.data); };
      mr.start(250);
      let ctx: AudioContext | undefined, an: AnalyserNode | undefined;
      try { ctx = new AudioContext(); an = ctx.createAnalyser(); an.fftSize = 256; ctx.createMediaStreamSource(stream).connect(an); } catch {}
      const buf = new Uint8Array(128);
      const timer = setInterval(() => {
        const r = recorder.current;
        if (!r) return;
        const secs = (r.done + (r.mr.state === "recording" ? Date.now() - r.since : 0)) / 1000;
        setElapsed(secs);
        if (r.an && r.mr.state === "recording") {
          r.an.getByteTimeDomainData(buf);
          let peak = 0;
          for (const v of buf) peak = Math.max(peak, Math.abs(v - 128));
          setLevels((l) => [...l.slice(-59), Math.max(0.08, Math.min(1, peak / 64))]);
        }
        if (r.mr.state === "recording") onTyping(true);
        if (secs > 300) stopRec(true);
      }, 110);
      recorder.current = { mr, chunks, done: 0, since: Date.now(), timer, ctx, an };
      setElapsed(0); setLevels([]);
      setRec({ paused: false });
    } catch {
      toast.error("Allow the microphone to record a voice note.");
    }
  }
  function pauseRec() {
    const r = recorder.current;
    if (!r) return;
    if (r.mr.state === "recording") { r.done += Date.now() - r.since; r.mr.pause(); setRec({ paused: true }); }
    else if (r.mr.state === "paused") { r.since = Date.now(); r.mr.resume(); setRec({ paused: false }); }
  }
  function stopRec(keep: boolean) {
    const r = recorder.current;
    if (!r) return;
    recorder.current = null;
    clearInterval(r.timer);
    const secs = (r.done + (r.mr.state === "recording" ? Date.now() - r.since : 0)) / 1000;
    r.mr.addEventListener("stop", () => {
      r.mr.stream.getTracks().forEach((t) => t.stop());
      void r.ctx?.close();
      if (!keep) return;
      if (secs < 1) return void toast("That was too short to send.");
      const type = (r.mr.mimeType || "audio/webm").split(";")[0];
      void onSend("voice", "", { file: new Blob(r.chunks, { type }), contentType: type, meta: { duration: Math.round(secs), mime: type } });
    }, { once: true });
    r.mr.stop();
    setRec(null);
  }

  async function pickFile(f: File | undefined) {
    if (!f) return;
    const isPdf = f.type === "application/pdf";
    if (!isPdf && !f.type.startsWith("image/")) return toast.error("Send a photo or a PDF.");
    const blob = isPdf ? f : await shrink(f);
    if (blob.size > 10 * 1024 * 1024) return toast.error("That file is over 10 MB.");
    await onSend(isPdf ? "file" : "image", "", { file: blob, contentType: isPdf ? "application/pdf" : blob.type || "image/jpeg", meta: { name: f.name, size: blob.size, mime: blob.type } });
  }

  if (disabled) return <div className="border-t bg-card px-4 py-3 text-center text-sm text-muted-foreground">{disabled}</div>;

  return (
    <div className="bg-[#EEF2F8] px-2 pb-2 pt-1.5 dark:bg-[#081224] sm:px-4">
      <AnimatePresence initial={false}>
        {reply ? (
          <motion.div key="reply" initial={rm ? false : { height: 0, opacity: 0 }} animate={{ height: "auto", opacity: 1 }} exit={rm ? undefined : { height: 0, opacity: 0 }} className="overflow-hidden">
            <div className="mb-1.5 flex items-center gap-2 rounded-2xl border-l-[3px] border-[#F2B233] bg-white py-2 pl-3 pr-1 dark:bg-[#13233F]">
              <div className="min-w-0 flex-1">
                <p className="text-xs font-bold text-[#8C600F] dark:text-[#F2B233]">Replying to {replyName}</p>
                <p className="truncate text-sm text-muted-foreground">{quoteText(reply)}</p>
              </div>
              <button type="button" onClick={onCancelReply} className="grid size-9 place-items-center rounded-full text-muted-foreground hover:bg-muted" aria-label="Cancel reply"><X size={18} /></button>
            </div>
          </motion.div>
        ) : null}
      </AnimatePresence>
      <AnimatePresence mode="wait" initial={false}>
        {rec ? (
          <motion.div key="rec" initial={rm ? false : { opacity: 0, y: 6 }} animate={{ opacity: 1, y: 0 }} exit={{ opacity: 0 }}
            className="flex items-center gap-2 rounded-full bg-white py-1.5 pl-1.5 pr-1.5 shadow-sm dark:bg-[#13233F]">
            <button type="button" onClick={() => stopRec(false)} className="grid size-11 place-items-center rounded-full text-red-600 hover:bg-red-50 dark:hover:bg-red-950" aria-label="Delete recording"><Trash size={22} weight="fill" /></button>
            <motion.span className={cn("size-2.5 rounded-full", rec.paused ? "bg-muted-foreground" : "bg-red-500")} animate={rm || rec.paused ? undefined : { opacity: [1, 0.25, 1] }} transition={{ duration: 1, repeat: Infinity }} />
            <span className="w-12 font-bold tabular-nums">{fmtDur(elapsed)}</span>
            <div className="flex h-8 min-w-0 flex-1 items-center justify-end gap-[2px] overflow-hidden" aria-hidden="true">
              {levels.map((l, i) => <span key={i} className={cn("w-[3px] shrink-0 rounded-full", rec.paused ? "bg-muted-foreground/50" : "bg-foreground/80")} style={{ height: `${Math.max(10, l * 100)}%` }} />)}
            </div>
            <button type="button" onClick={pauseRec} className={cn("grid size-11 place-items-center rounded-full hover:bg-muted", rec.paused ? "text-red-600" : "text-muted-foreground")} aria-label={rec.paused ? "Go on recording" : "Pause"}>
              {rec.paused ? <Microphone size={22} weight="fill" /> : <Pause size={22} weight="fill" />}
            </button>
            <button type="button" onClick={() => stopRec(true)} className="grid size-11 place-items-center rounded-full bg-[#F2B233] text-[#0B1F44] active:scale-90" aria-label="Send voice note"><PaperPlaneRight size={20} weight="fill" /></button>
          </motion.div>
        ) : (
          <motion.div key="type" initial={false} className="flex items-end gap-1.5">
            <div className="flex min-h-12 flex-1 items-end rounded-[26px] bg-white shadow-sm dark:bg-[#13233F]">
              <button type="button" onClick={() => setEmoji((x) => !x)} className={cn("grid size-11 shrink-0 place-items-center rounded-full hover:text-foreground", emoji ? "text-[#2563B3] dark:text-[#F2B233]" : "text-muted-foreground")} aria-label="Emoji" aria-expanded={emoji}>
                <Smiley size={23} />
              </button>
              <textarea ref={area} rows={1} value={text} placeholder="Type a message · Enter to send" aria-label="Message"
                onChange={(e) => { setText(e.target.value); onTyping(); }}
                onKeyDown={(e) => { if (e.key === "Enter" && !e.shiftKey && !e.nativeEvent.isComposing) { e.preventDefault(); send(); } if (e.key === "Escape") onCancelReply?.(); }}
                onPaste={(e) => { const f = [...e.clipboardData.files][0]; if (f) { e.preventDefault(); void pickFile(f); } }}
                className="max-h-40 min-h-11 flex-1 resize-none bg-transparent py-3 text-[15px] leading-snug outline-none placeholder:text-muted-foreground" />
              <DropdownMenu>
                <DropdownMenuTrigger className="grid size-11 shrink-0 place-items-center rounded-full text-muted-foreground hover:text-foreground" aria-label="Attach: photo, PDF, call link, study link">
                  <Paperclip size={22} />
                </DropdownMenuTrigger>
                <DropdownMenuContent align="end" className="w-64">
                  <DropdownMenuItem className="gap-3 py-2" onClick={() => fileRef.current?.click()}><span className="grid size-8 place-items-center rounded-full bg-[#2563B3] text-white"><ImageIcon size={16} weight="fill" /></span> Photo or PDF</DropdownMenuItem>
                  {staff ? <>
                    <DropdownMenuItem className="gap-3 py-2" onClick={() => setCall("meet")}><span className="grid size-8 place-items-center rounded-full bg-white ring-1 ring-border"><CallLogo type="meet" size={20} /></span> Google Meet link</DropdownMenuItem>
                    <DropdownMenuItem className="gap-3 py-2" onClick={() => setCall("whatsapp")}><span className="grid size-8 place-items-center rounded-full bg-white ring-1 ring-border"><CallLogo type="whatsapp" size={22} /></span> WhatsApp call link</DropdownMenuItem>
                    <DropdownMenuItem className="gap-3 py-2" onClick={() => setCall("zoom")}><span className="grid size-8 place-items-center rounded-full bg-white ring-1 ring-border"><CallLogo type="zoom" size={14} /></span> Zoom link</DropdownMenuItem>
                    <DropdownMenuItem className="gap-3 py-2" onClick={() => setCall("video")}><span className="grid size-8 place-items-center rounded-full bg-[#2563B3] text-white"><VideoCamera size={16} weight="fill" /></span> Other video link</DropdownMenuItem>
                    <DropdownMenuItem className="gap-3 py-2" onClick={() => setRefKind("pq")}><span className="grid size-8 place-items-center rounded-full bg-[#F2B233] text-[#0B1F44]"><Books size={16} weight="fill" /></span> Past question</DropdownMenuItem>
                    <DropdownMenuItem className="gap-3 py-2" onClick={() => setRefKind("lesson")}><span className="grid size-8 place-items-center rounded-full bg-[#1FA463] text-white"><BookOpenText size={16} weight="fill" /></span> Lesson or note</DropdownMenuItem>
                  </> : null}
                </DropdownMenuContent>
              </DropdownMenu>
            </div>
            <input ref={fileRef} type="file" accept="image/*,application/pdf" className="hidden" onChange={(e) => { void pickFile(e.target.files?.[0]); e.target.value = ""; }} />
            <AnimatePresence mode="popLayout" initial={false}>
              {text.trim() ? (
                <motion.button key="send" type="button" onClick={send} initial={rm ? false : { scale: 0.5, rotate: -30 }} animate={{ scale: 1, rotate: 0 }} exit={rm ? undefined : { scale: 0.5 }}
                  className="grid size-12 shrink-0 place-items-center rounded-full bg-[#F2B233] text-[#0B1F44] shadow active:scale-90" aria-label="Send">
                  <PaperPlaneRight size={21} weight="fill" />
                </motion.button>
              ) : (
                <motion.button key="mic" type="button" onClick={startRec} initial={rm ? false : { scale: 0.5 }} animate={{ scale: 1 }} exit={rm ? undefined : { scale: 0.5 }}
                  className="grid size-12 shrink-0 place-items-center rounded-full bg-[#F2B233] text-[#0B1F44] shadow active:scale-90" aria-label="Record a voice note">
                  <Microphone size={21} weight="fill" />
                </motion.button>
              )}
            </AnimatePresence>
          </motion.div>
        )}
      </AnimatePresence>
      <AnimatePresence initial={false}>
        {emoji && !rec ? (
          <motion.div key="emoji" initial={rm ? false : { height: 0, opacity: 0 }} animate={{ height: 240, opacity: 1 }} exit={rm ? undefined : { height: 0, opacity: 0 }}
            className="mt-1.5 overflow-hidden rounded-2xl bg-white dark:bg-[#13233F]">
            <div className="flex border-b">
              {EMOJI.map(([g], i) => (
                <button key={g} type="button" onClick={() => setTab(i)} className={cn("flex-1 border-b-2 py-2 text-xs font-bold", tab === i ? "border-[#F2B233] text-foreground" : "border-transparent text-muted-foreground")}>{g}</button>
              ))}
            </div>
            <div className="grid h-[200px] grid-cols-8 content-start gap-0.5 overflow-y-auto p-2 sm:grid-cols-12">
              {EMOJI[tab][1].map((e) => <button key={e} type="button" onClick={() => addEmoji(e)} className="grid h-9 place-items-center rounded-lg text-2xl transition-transform hover:scale-125 hover:bg-muted">{e}</button>)}
            </div>
          </motion.div>
        ) : null}
      </AnimatePresence>
      {call ? <CallDialog type={call} onClose={() => setCall(null)} onSend={(url, note, t) => onSend("link", note || CALLS[t].label, { meta: { url, type: t } })} /> : null}
      {refKind ? <RefDialog sb={sb} kind={refKind} subjectId={subjectId} onClose={() => setRefKind(null)} onPick={(r) => onSend("ref", r.title ?? "", { ref: r })} /> : null}
    </div>
  );
}

function CallDialog({ type, onClose, onSend }: { type: CallType; onClose: () => void; onSend: (url: string, note: string, t: CallType) => void }) {
  const [t, setT] = useState<CallType>(type);
  const [url, setUrl] = useState<string>(CALLS[type].prefix);
  const [note, setNote] = useState("");
  const ok = /^https:\/\/[^\s]+\.[^\s]+/.test(url.trim()) && url.trim() !== CALLS[t].prefix;
  return (
    <Dialog open onOpenChange={(o) => !o && onClose()}>
      <DialogContent>
        <DialogHeader><DialogTitle>Send a call link</DialogTitle></DialogHeader>
        <div className="grid gap-3">
          <div className="flex flex-wrap gap-2">
            {(Object.keys(CALLS) as CallType[]).map((k) => (
              <button key={k} type="button" onClick={() => { setT(k); if (url === CALLS[t].prefix) setUrl(CALLS[k].prefix); }}
                className={cn("inline-flex items-center gap-2 rounded-full border px-3 py-1.5 text-sm font-bold", t === k ? "border-[#0B1F44] bg-[#0B1F44] text-white dark:border-[#F2B233] dark:bg-[#F2B233] dark:text-[#0B1F44]" : "hover:bg-muted")}>
                {k !== "video" ? <span className="grid size-5 place-items-center rounded-full bg-white"><CallLogo type={k} size={k === "zoom" ? 10 : 16} /></span> : null}{CALLS[k].label}</button>
            ))}
          </div>
          <label className="grid gap-1 text-sm font-medium">Link<input className={inputCls} value={url} onChange={(e) => setUrl(e.target.value)} placeholder="https://" autoFocus /></label>
          <label className="grid gap-1 text-sm font-medium">Message (optional)<input className={inputCls} value={note} maxLength={120} onChange={(e) => setNote(e.target.value)} placeholder="Our physics class starts now" /></label>
          <p className="text-xs text-muted-foreground">The student sees a call card with a Join button. Use your own Meet, WhatsApp call or Zoom link.</p>
          <div className="flex justify-end gap-2"><Button variant="ghost" onClick={onClose}>Cancel</Button><Button disabled={!ok} onClick={() => { onSend(url.trim(), note.trim(), t); onClose(); }}>Send link</Button></div>
        </div>
      </DialogContent>
    </Dialog>
  );
}

type RefRow = NonNullable<Msg["ref"]>;
function RefDialog({ sb, kind, subjectId, onClose, onPick }: { sb: SupabaseClient; kind: "pq" | "lesson"; subjectId?: number | null; onClose: () => void; onPick: (r: RefRow) => void }) {
  const [q, setQ] = useState("");
  const [rows, setRows] = useState<RefRow[] | null>(null);
  const [onlySubject, setOnlySubject] = useState(Boolean(subjectId));
  useEffect(() => {
    let live = true;
    const t = setTimeout(async () => {
      const { data } = await sb.rpc("tutor_ref_search", { p_kind: kind, p_q: q, p_subject: onlySubject && subjectId ? subjectId : undefined });
      if (live) setRows((data ?? []) as RefRow[]);
    }, 250);
    return () => { live = false; clearTimeout(t); };
  }, [sb, kind, q, onlySubject, subjectId]);
  return (
    <Dialog open onOpenChange={(o) => !o && onClose()}>
      <DialogContent className="max-h-[85dvh] overflow-hidden sm:max-w-lg">
        <DialogHeader><DialogTitle>{kind === "pq" ? "Send a past question" : "Send a lesson or note"}</DialogTitle></DialogHeader>
        <input className={inputCls} value={q} onChange={(e) => setQ(e.target.value)} placeholder={kind === "pq" ? "Search words in the question, or a year like 2019" : "Search lesson titles"} autoFocus />
        {subjectId ? <label className="flex items-center gap-2 text-sm"><input type="checkbox" checked={onlySubject} onChange={(e) => setOnlySubject(e.target.checked)} /> Only this student&apos;s subject</label> : null}
        <ul className="-mx-2 max-h-[50dvh] overflow-auto">
          {rows === null ? <li className="p-4 text-sm text-muted-foreground">Searching…</li> : rows.length === 0 ? <li className="p-4 text-sm text-muted-foreground">Nothing found.</li> : rows.map((r, i) => (
            <li key={i}>
              <button type="button" onClick={() => { onPick(r); onClose(); }} className="w-full rounded-xl px-3 py-2 text-left hover:bg-muted">
                <b className="block text-sm">{r.title}</b>
                <span className="line-clamp-2 text-xs text-muted-foreground">{r.snippet ?? r.subtitle ?? (r as { subject?: string }).subject ?? ""}</span>
              </button>
            </li>
          ))}
        </ul>
      </DialogContent>
    </Dialog>
  );
}
