"use client";
import { useEffect, useRef, useState } from "react";
import type { SupabaseClient } from "@supabase/supabase-js";
import { AnimatePresence, motion, useReducedMotion } from "motion/react";
import { toast } from "sonner";
import { BookOpenText, Books, Microphone, PaperPlaneRight, Paperclip, Phone, Plus, Trash, VideoCamera } from "@phosphor-icons/react";
import { Button } from "@/components/ui/button";
import { Dialog, DialogContent, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { DropdownMenu, DropdownMenuContent, DropdownMenuItem, DropdownMenuTrigger } from "@/components/ui/dropdown-menu";
import { cn } from "@/lib/utils";
import { CALLS, fmtDur, type CallType, type Msg } from "./lib";

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

export function Composer({ sb, onSend, onTyping, disabled, staff, subjectId }: {
  sb: SupabaseClient; onSend: SendFn; onTyping: () => void; disabled?: string; staff: boolean; subjectId?: number | null;
}) {
  const rm = useReducedMotion();
  const [text, setText] = useState("");
  const [rec, setRec] = useState<{ start: number } | null>(null);
  const recorder = useRef<{ mr: MediaRecorder; chunks: Blob[]; start: number; timer: ReturnType<typeof setTimeout> } | null>(null);
  const [now, setNow] = useState(0);
  const [call, setCall] = useState<CallType | null>(null);
  const [refKind, setRefKind] = useState<"pq" | "lesson" | null>(null);
  const fileRef = useRef<HTMLInputElement>(null);
  const area = useRef<HTMLTextAreaElement>(null);

  useEffect(() => {
    if (!rec) return;
    const t = setInterval(() => setNow(Date.now()), 200);
    return () => clearInterval(t);
  }, [rec]);
  useEffect(() => {
    const a = area.current;
    if (a) { a.style.height = "auto"; a.style.height = `${Math.min(a.scrollHeight, 160)}px`; }
  }, [text]);

  const send = () => {
    const t = text.trim();
    if (!t) return;
    setText("");
    void onSend("text", t);
  };

  async function startRec() {
    try {
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
      const type = voiceType();
      const mr = new MediaRecorder(stream, type ? { mimeType: type } : undefined);
      const chunks: Blob[] = [];
      mr.ondataavailable = (e) => { if (e.data.size) chunks.push(e.data); };
      mr.start(250);
      const start = Date.now();
      recorder.current = { mr, chunks, start, timer: setTimeout(() => stopRec(true), 180_000) };
      setNow(start);
      setRec({ start });
    } catch {
      toast.error("Allow the microphone to record a voice note.");
    }
  }
  function stopRec(keep: boolean) {
    const r = recorder.current;
    if (!r) return;
    recorder.current = null;
    clearTimeout(r.timer);
    const secs = (Date.now() - r.start) / 1000;
    r.mr.addEventListener("stop", () => {
      r.mr.stream.getTracks().forEach((t) => t.stop());
      if (!keep || secs < 1) return;
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
    <div className="border-t bg-card px-2 py-2 sm:px-3">
      <AnimatePresence mode="wait" initial={false}>
        {rec ? (
          <motion.div key="rec" initial={rm ? false : { opacity: 0, y: 6 }} animate={{ opacity: 1, y: 0 }} exit={{ opacity: 0 }} className="flex items-center gap-3 px-2 py-1">
            <button type="button" onClick={() => stopRec(false)} className="grid size-11 place-items-center rounded-full text-red-600 hover:bg-red-50" aria-label="Delete recording"><Trash size={22} /></button>
            <motion.span className="size-3 rounded-full bg-red-500" animate={rm ? undefined : { opacity: [1, 0.3, 1] }} transition={{ duration: 1.1, repeat: Infinity }} />
            <span className="flex-1 font-mono text-sm tabular-nums">{fmtDur((now - rec.start) / 1000)} <span className="text-muted-foreground">· recording (max 3:00)</span></span>
            <button type="button" onClick={() => stopRec(true)} className="grid size-11 place-items-center rounded-full bg-primary text-primary-foreground" aria-label="Send voice note"><PaperPlaneRight size={20} weight="fill" /></button>
          </motion.div>
        ) : (
          <motion.div key="type" initial={false} className="flex items-end gap-1.5">
            <DropdownMenu>
              <DropdownMenuTrigger className="grid size-11 shrink-0 place-items-center rounded-full text-muted-foreground hover:bg-muted" aria-label="More: call links, study links, files">
                <Plus size={22} weight="bold" />
              </DropdownMenuTrigger>
              <DropdownMenuContent align="start" className="w-60">
                <DropdownMenuItem className="gap-2 py-2" onClick={() => fileRef.current?.click()}><Paperclip size={18} /> Photo or PDF</DropdownMenuItem>
                {staff ? <>
                  <DropdownMenuItem className="gap-2 py-2" onClick={() => setCall("meet")}><VideoCamera size={18} /> Google Meet link</DropdownMenuItem>
                  <DropdownMenuItem className="gap-2 py-2" onClick={() => setCall("whatsapp")}><Phone size={18} /> WhatsApp call link</DropdownMenuItem>
                  <DropdownMenuItem className="gap-2 py-2" onClick={() => setCall("video")}><VideoCamera size={18} /> Zoom or other video link</DropdownMenuItem>
                  <DropdownMenuItem className="gap-2 py-2" onClick={() => setRefKind("pq")}><Books size={18} /> Past question</DropdownMenuItem>
                  <DropdownMenuItem className="gap-2 py-2" onClick={() => setRefKind("lesson")}><BookOpenText size={18} /> Lesson or note</DropdownMenuItem>
                </> : null}
              </DropdownMenuContent>
            </DropdownMenu>
            <input ref={fileRef} type="file" accept="image/*,application/pdf" className="hidden" onChange={(e) => { void pickFile(e.target.files?.[0]); e.target.value = ""; }} />
            <textarea ref={area} rows={1} value={text} placeholder="Message" aria-label="Message"
              onChange={(e) => { setText(e.target.value); onTyping(); }}
              onKeyDown={(e) => { if (e.key === "Enter" && !e.shiftKey && !e.nativeEvent.isComposing) { e.preventDefault(); send(); } }}
              onPaste={(e) => { const f = [...e.clipboardData.files][0]; if (f) { e.preventDefault(); void pickFile(f); } }}
              className="max-h-40 min-h-11 flex-1 resize-none rounded-3xl border bg-background px-4 py-2.5 text-[15px] leading-snug outline-none focus-visible:ring-2 focus-visible:ring-ring" />
            {text.trim() ? (
              <motion.button key="send" type="button" onClick={send} initial={rm ? false : { scale: 0.6 }} animate={{ scale: 1 }}
                className="grid size-11 shrink-0 place-items-center rounded-full bg-primary text-primary-foreground shadow active:scale-90" aria-label="Send">
                <PaperPlaneRight size={20} weight="fill" />
              </motion.button>
            ) : (
              <motion.button key="mic" type="button" onClick={startRec} initial={rm ? false : { scale: 0.6 }} animate={{ scale: 1 }}
                className="grid size-11 shrink-0 place-items-center rounded-full bg-primary text-primary-foreground shadow active:scale-90" aria-label="Record a voice note">
                <Microphone size={20} weight="fill" />
              </motion.button>
            )}
          </motion.div>
        )}
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
                className={cn("rounded-full border px-3 py-1.5 text-sm font-bold", t === k ? "border-primary bg-primary text-primary-foreground" : "hover:bg-muted")}>{CALLS[k].label}</button>
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
