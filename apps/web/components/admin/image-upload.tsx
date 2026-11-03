"use client";
import { useRef, useState } from "react";
import { ImageSquare, SpinnerGap, Trash } from "@phosphor-icons/react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";

/** Uploads one image to R2 through a presigned link and keeps its key in a hidden form field. */
export function ImageUpload({ name, kind, defaultKey }: { name: string; kind: "question" | "news" | "cover" | "receipt"; defaultKey?: string | null }) {
  const [key, setKey] = useState(defaultKey ?? "");
  const [preview, setPreview] = useState(defaultKey ? `/admin/api/${kind === "cover" ? "study-file" : "image"}?key=${encodeURIComponent(defaultKey)}` : "");
  const [busy, setBusy] = useState(false);
  const input = useRef<HTMLInputElement>(null);

  async function onFile(file: File) {
    setBusy(true);
    try {
      const r = await fetch("/admin/api/upload", { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify({ kind, contentType: file.type, size: file.size }) });
      const j = await r.json();
      if (!r.ok) throw new Error(j.error ?? "Upload failed");
      const put = await fetch(j.url, { method: "PUT", headers: { "content-type": file.type }, body: file });
      if (!put.ok) throw new Error("Upload to storage failed. Check the R2 CORS settings (SETUP §7.7).");
      setKey(j.key);
      setPreview(URL.createObjectURL(file));
      toast.success("Image uploaded.");
    } catch (e) {
      toast.error(e instanceof Error ? e.message : "Upload failed");
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="flex items-center gap-3">
      <input type="hidden" name={name} value={key} />
      <input ref={input} type="file" accept="image/webp,image/png,image/jpeg,image/svg+xml" className="hidden"
        onChange={(e) => { const f = e.target.files?.[0]; if (f) onFile(f); e.target.value = ""; }} />
      {preview ? (
        <img src={preview} alt="Question image" className="size-20 rounded-xl border object-contain bg-white" />
      ) : (
        <div className="grid size-20 place-items-center rounded-xl border border-dashed text-subtle"><ImageSquare size={28} /></div>
      )}
      <div className="flex flex-col gap-2">
        <Button type="button" variant="outline" size="sm" disabled={busy} onClick={() => input.current?.click()}>
          {busy ? <SpinnerGap size={16} className="animate-spin" /> : <ImageSquare size={16} />} {key ? "Replace image" : "Add image"}
        </Button>
        {key ? <Button type="button" variant="ghost" size="sm" onClick={() => { setKey(""); setPreview(""); }}><Trash size={16} /> Remove</Button> : null}
      </div>
    </div>
  );
}
