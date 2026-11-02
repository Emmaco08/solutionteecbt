"use client";
import { useRef, useState } from "react";
import { FilePdf, FileVideo, ImageSquare, SpinnerGap, Trash, UploadSimple } from "@phosphor-icons/react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { faststart } from "@/lib/mp4-faststart";

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
 * Takes one frame (about a third of the way in, max 3 s) as the video's preview picture: 640 px wide WebP.
 * `src` is a local file URL or a same-origin admin link that redirects to R2 (R2 CORS allows GET, so the canvas stays readable).
 */
function posterFrom(src: string) {
  return new Promise<Blob>((resolve, reject) => {
    const v = document.createElement("video");
    v.crossOrigin = "anonymous";
    v.muted = true;
    v.preload = "auto";
    v.playsInline = true;
    const fail = () => reject(new Error("Could not read a frame from the video."));
    v.onerror = fail;
    v.onloadedmetadata = () => { v.currentTime = Math.min(3, (v.duration || 3) / 3); };
    v.onseeked = () => {
      const w = Math.min(640, v.videoWidth || 640);
      const h = Math.round(w * ((v.videoHeight || 360) / (v.videoWidth || 640)));
      const c = document.createElement("canvas");
      c.width = w; c.height = h;
      c.getContext("2d")?.drawImage(v, 0, 0, w, h);
      c.toBlob((b) => (b ? resolve(b) : fail()), "image/webp", 0.8);
    };
    setTimeout(fail, 30000);
    v.src = src;
  });
}

async function put(kind: string, body: Blob, type: string, onProgress?: (p: number) => void) {
  const r = await fetch("/admin/api/upload", { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify({ kind, contentType: type, size: body.size }) });
  const j = await r.json();
  if (!r.ok) throw new Error(j.error ?? "Upload failed");
  await new Promise<void>((resolve, reject) => {
    const x = new XMLHttpRequest();
    x.open("PUT", j.url);
    x.setRequestHeader("content-type", type);
    if (onProgress) x.upload.onprogress = (e) => e.lengthComputable && onProgress(Math.round((e.loaded / e.total) * 100));
    x.onload = () => (x.status < 300 ? resolve() : reject(new Error("Upload to storage failed. Check the R2 CORS settings (SETUP §10.1).")));
    x.onerror = () => reject(new Error("Upload to storage failed. Check your internet and the R2 CORS settings."));
    x.send(body);
  });
  return j.key as string;
}

/**
 * Uploads one video or PDF to the private R2 bucket through a presigned link, with a progress bar.
 * Videos are made "fast start" first (they play while downloading) and a preview picture is taken from them.
 * Hidden fields: `${name}`, `${name}_size`, `${name}_duration` / `${name}_pages`, and `${name}_poster` for videos.
 */
export function FileUpload({ name, kind, label, defaultKey, defaultSize }: { name: string; kind: Kind; label: string; defaultKey?: string | null; defaultSize?: number | null }) {
  const [file, setFile] = useState<Uploaded | null>(defaultKey ? { key: defaultKey, size: defaultSize ?? 0 } : null);
  const [poster, setPoster] = useState("");
  const [progress, setProgress] = useState<number | null>(null);
  const [step, setStep] = useState("");
  const input = useRef<HTMLInputElement>(null);
  const Icon = kind === "video" ? FileVideo : FilePdf;

  async function makePoster(src: string, quiet = false) {
    try {
      setStep("Making the thumbnail…");
      const key = await put("cover", await posterFrom(src), "image/webp");
      setPoster(key);
      if (!quiet) toast.success("Thumbnail made. Save to keep it.");
    } catch (e) {
      if (!quiet) toast.error(e instanceof Error ? e.message : "Could not make the thumbnail.");
    } finally {
      setStep("");
    }
  }

  async function onFile(f: File) {
    try {
      setProgress(0);
      let body: Blob = f;
      if (kind === "video") {
        setStep("Preparing the video for slow networks…");
        const fs = await faststart(f);
        body = fs.blob;
        if (fs.changed) toast.message("The video was made \"fast start\", so it plays while it downloads.");
      }
      setStep("");
      const key = await put(kind, body, f.type, setProgress);
      const extra = kind === "video" ? { durationS: await videoDuration(f) } : { pages: await pdfPages(f) };
      setFile({ key, size: body.size, ...extra });
      toast.success(`${label} uploaded.`);
      setProgress(null);
      if (kind === "video") {
        const url = URL.createObjectURL(f);
        await makePoster(url, true);
        URL.revokeObjectURL(url);
      }
    } catch (e) {
      toast.error(e instanceof Error ? e.message : "Upload failed");
    } finally {
      setProgress(null);
      setStep("");
    }
  }

  const busy = progress !== null || step !== "";
  return (
    <div className="flex flex-wrap items-center gap-3 rounded-xl border p-3">
      <input type="hidden" name={name} value={file?.key ?? ""} />
      <input type="hidden" name={`${name}_size`} value={file?.size ?? ""} />
      {kind === "video" ? (
        <>
          <input type="hidden" name={`${name}_duration`} value={file?.durationS ?? ""} />
          <input type="hidden" name={`${name}_poster`} value={poster} />
        </>
      ) : <input type="hidden" name={`${name}_pages`} value={file?.pages ?? ""} />}
      <input ref={input} type="file" accept={kind === "video" ? "video/mp4" : "application/pdf"} className="hidden"
        onChange={(e) => { const f = e.target.files?.[0]; if (f) onFile(f); e.target.value = ""; }} />
      <span className={`grid size-11 flex-none place-items-center rounded-xl ${file ? "bg-success-soft text-on-success-soft" : "bg-surface-sunken text-subtle"}`}><Icon size={22} /></span>
      <span className="min-w-0 grow">
        <b className="block text-sm">{label}</b>
        {progress !== null ? (
          <span className="mt-1 block h-2 overflow-hidden rounded-full bg-surface-sunken"><span className="block h-full bg-secondary transition-all" style={{ width: `${progress}%` }} /></span>
        ) : (
          <span className="block truncate text-xs text-muted-foreground">
            {step || (file ? `${file.size ? mb(file.size) : "Uploaded"}${file.durationS ? ` · ${Math.floor(file.durationS / 60)}:${String(file.durationS % 60).padStart(2, "0")}` : ""}${file.pages ? ` · ${file.pages} pages` : ""}${poster ? " · thumbnail ready" : ""}` : kind === "video" ? "MP4 (H.264)" : "PDF")}
          </span>
        )}
      </span>
      {file && !busy ? (
        <>
          <a href={`/admin/api/study-file?key=${encodeURIComponent(file.key)}`} target="_blank" rel="noreferrer" className="text-sm font-bold text-link">Open</a>
          {kind === "video" && !poster ? (
            <Button type="button" variant="ghost" size="sm" onClick={() => makePoster(`/admin/api/study-file?key=${encodeURIComponent(file.key)}`)}>
              <ImageSquare size={16} /> Make thumbnail
            </Button>
          ) : null}
          <Button type="button" variant="ghost" size="sm" onClick={() => { setFile(null); setPoster(""); }} aria-label={`Remove ${label}`}><Trash size={16} /></Button>
        </>
      ) : null}
      <Button type="button" variant="outline" size="sm" disabled={busy} onClick={() => input.current?.click()}>
        {busy ? <><SpinnerGap size={16} className="animate-spin" /> {progress !== null ? `${progress}%` : "Working"}</> : <><UploadSimple size={16} /> {file ? "Replace" : "Upload"}</>}
      </Button>
    </div>
  );
}
