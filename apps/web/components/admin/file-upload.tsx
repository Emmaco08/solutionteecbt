"use client";
import { useRef, useState } from "react";
import { FilePdf, FileVideo, SpinnerGap, Trash, UploadSimple } from "@phosphor-icons/react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";

type Kind = "video" | "pdf";
export type Uploaded = { key: string; size: number; durationS?: number; pages?: number };

const mb = (n: number) => `${(n / 1024 / 1024).toFixed(n > 10 * 1024 * 1024 ? 0 : 1)} MB`;

/** Reads a video's length in the browser before upload (so the app can show "6:12"). */
function videoDuration(file: File) {
  return new Promise<number | undefined>((resolve) => {
    const v = document.createElement("video");
    v.preload = "metadata";
    v.onloadedmetadata = () => { URL.revokeObjectURL(v.src); resolve(Number.isFinite(v.duration) ? Math.round(v.duration) : undefined); };
    v.onerror = () => resolve(undefined);
    v.src = URL.createObjectURL(file);
  });
}

/** Counts PDF pages from the file itself (good enough for normal PDFs; the field stays editable). */
async function pdfPages(file: File) {
  const text = new TextDecoder("latin1").decode(await file.arrayBuffer());
  const m = text.match(/\/Type\s*\/Page[^s]/g);
  return m ? m.length : undefined;
}

/**
 * Uploads one video or PDF to the private R2 bucket through a presigned link, with a progress bar.
 * The key, size and length are kept in hidden fields named `${name}`, `${name}_size`, `${name}_duration` / `${name}_pages`.
 */
export function FileUpload({ name, kind, label, defaultKey, defaultSize }: { name: string; kind: Kind; label: string; defaultKey?: string | null; defaultSize?: number | null }) {
  const [file, setFile] = useState<Uploaded | null>(defaultKey ? { key: defaultKey, size: defaultSize ?? 0 } : null);
  const [progress, setProgress] = useState<number | null>(null);
  const input = useRef<HTMLInputElement>(null);
  const Icon = kind === "video" ? FileVideo : FilePdf;

  async function onFile(f: File) {
    try {
      setProgress(0);
      const r = await fetch("/admin/api/upload", { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify({ kind, contentType: f.type, size: f.size }) });
      const j = await r.json();
      if (!r.ok) throw new Error(j.error ?? "Upload failed");
      await new Promise<void>((resolve, reject) => {
        const x = new XMLHttpRequest();
        x.open("PUT", j.url);
        x.setRequestHeader("content-type", f.type);
        x.upload.onprogress = (e) => e.lengthComputable && setProgress(Math.round((e.loaded / e.total) * 100));
        x.onload = () => (x.status < 300 ? resolve() : reject(new Error("Upload to storage failed. Check the R2 CORS settings (SETUP §7.7).")));
        x.onerror = () => reject(new Error("Upload to storage failed. Check your internet and the R2 CORS settings."));
        x.send(f);
      });
      const extra = kind === "video" ? { durationS: await videoDuration(f) } : { pages: await pdfPages(f) };
      setFile({ key: j.key, size: f.size, ...extra });
      toast.success(`${label} uploaded.`);
    } catch (e) {
      toast.error(e instanceof Error ? e.message : "Upload failed");
    } finally {
      setProgress(null);
    }
  }

  return (
    <div className="flex items-center gap-3 rounded-xl border p-3">
      <input type="hidden" name={name} value={file?.key ?? ""} />
      <input type="hidden" name={`${name}_size`} value={file?.size ?? ""} />
      {kind === "video" ? <input type="hidden" name={`${name}_duration`} value={file?.durationS ?? ""} /> : <input type="hidden" name={`${name}_pages`} value={file?.pages ?? ""} />}
      <input ref={input} type="file" accept={kind === "video" ? "video/mp4" : "application/pdf"} className="hidden"
        onChange={(e) => { const f = e.target.files?.[0]; if (f) onFile(f); e.target.value = ""; }} />
      <span className={`grid size-11 flex-none place-items-center rounded-xl ${file ? "bg-success-soft text-on-success-soft" : "bg-surface-sunken text-subtle"}`}><Icon size={22} /></span>
      <span className="min-w-0 grow">
        <b className="block text-sm">{label}</b>
        {progress !== null ? (
          <span className="mt-1 block h-2 overflow-hidden rounded-full bg-surface-sunken"><span className="block h-full bg-secondary transition-all" style={{ width: `${progress}%` }} /></span>
        ) : (
          <span className="block truncate text-xs text-muted-foreground">
            {file ? `${file.size ? mb(file.size) : "Uploaded"}${file.durationS ? ` · ${Math.floor(file.durationS / 60)}:${String(file.durationS % 60).padStart(2, "0")}` : ""}${file.pages ? ` · ${file.pages} pages` : ""}` : kind === "video" ? "MP4 (H.264)" : "PDF"}
          </span>
        )}
      </span>
      {file && progress === null ? (
        <>
          <a href={`/admin/api/study-file?key=${encodeURIComponent(file.key)}`} target="_blank" rel="noreferrer" className="text-sm font-bold text-link">Open</a>
          <Button type="button" variant="ghost" size="sm" onClick={() => setFile(null)} aria-label={`Remove ${label}`}><Trash size={16} /></Button>
        </>
      ) : null}
      <Button type="button" variant="outline" size="sm" disabled={progress !== null} onClick={() => input.current?.click()}>
        {progress !== null ? <><SpinnerGap size={16} className="animate-spin" /> {progress}%</> : <><UploadSimple size={16} /> {file ? "Replace" : "Upload"}</>}
      </Button>
    </div>
  );
}
