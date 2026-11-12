"use client";
import { useMemo, useRef, useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { Camera, UserCircleGear } from "@phosphor-icons/react";
import { Button } from "@/components/ui/button";
import { Dialog, DialogContent, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { Face } from "@/components/tutor-chat/face";
import { createClient } from "@/lib/supabase/client";

const cls = "w-full rounded-xl border bg-background px-3 py-2 text-sm outline-none focus-visible:ring-2 focus-visible:ring-ring";

/** A square 512 px JPEG under 1 MB, cut from the middle of the picture. */
async function squareJpeg(file: File): Promise<Blob> {
  const img = await createImageBitmap(file);
  const side = Math.min(img.width, img.height);
  const c = document.createElement("canvas");
  c.width = c.height = 512;
  c.getContext("2d")!.drawImage(img, (img.width - side) / 2, (img.height - side) / 2, side, side, 0, 0, 512, 512);
  return await new Promise<Blob>((res, rej) => c.toBlob((b) => (b ? res(b) : rej(new Error("photo"))), "image/jpeg", 0.85));
}

/** What students see about their tutor: photo, name, subjects, years, qualification and a short bio (D-152, D-154). */
export function TutorProfileButton({ initial }: { initial: { name: string; subjects: string; bio: string; years: string; qualification: string; photo: string | null } }) {
  const router = useRouter();
  const sb = useMemo(() => createClient(), []);
  const [open, setOpen] = useState(false);
  const [f, setF] = useState(initial);
  const [photo, setPhoto] = useState<string | null>(initial.photo);
  const [preview, setPreview] = useState<string | null>(null);
  const [uploading, setUploading] = useState(false);
  const [pending, start] = useTransition();
  const file = useRef<HTMLInputElement>(null);

  async function upload(picked: File | undefined) {
    if (!picked) return;
    if (!picked.type.startsWith("image/")) return void toast.error("Choose a photo.");
    setUploading(true);
    try {
      const blob = await squareJpeg(picked);
      const { data } = await sb.auth.getSession();
      const r = await fetch("/api/account/avatar", {
        method: "POST", headers: { "content-type": "application/json", authorization: `Bearer ${data.session?.access_token ?? ""}` },
        body: JSON.stringify({ contentType: "image/jpeg", size: blob.size, purpose: "avatar" }),
      });
      const j = await r.json().catch(() => ({}));
      if (!r.ok) throw new Error(j.error ?? "Could not upload the photo.");
      const put = await fetch(j.url, { method: "PUT", headers: { "content-type": "image/jpeg" }, body: blob });
      if (!put.ok) throw new Error("Upload failed. Check your internet.");
      const { data: saved, error } = await sb.rpc("tutor_photo_save", { p_path: j.key });
      if (error || !(saved as { ok?: boolean })?.ok) throw new Error("Could not save the photo.");
      setPhoto(j.key);
      setPreview(URL.createObjectURL(blob));
      toast.success("Photo saved. Your students see it now.");
      router.refresh();
    } catch (e) {
      toast.error(e instanceof Error ? e.message : "Could not upload the photo.");
    } finally {
      setUploading(false);
    }
  }

  return (
    <>
      <button type="button" onClick={() => setOpen(true)} aria-label="My profile"
        className="flex items-center gap-1.5 rounded-full bg-white/10 p-1.5 text-xs font-bold hover:bg-white/20 sm:px-3">
        <UserCircleGear size={20} /> <span className="hidden sm:inline">My profile</span>
      </button>
      <Dialog open={open} onOpenChange={setOpen}>
        <DialogContent className="max-h-[90dvh] overflow-y-auto">
          <DialogHeader><DialogTitle>Your tutor profile</DialogTitle></DialogHeader>
          <p className="text-sm text-muted-foreground">Your students see this in the app: on the &ldquo;Tutor assigned&rdquo; screen and in the chat.</p>
          <div className="flex items-center gap-4">
            <button type="button" onClick={() => file.current?.click()} className="group relative rounded-full" aria-label="Change photo" disabled={uploading}>
              {preview ? (
                // eslint-disable-next-line @next/next/no-img-element
                <img src={preview} alt="Your photo" className="size-20 rounded-full object-cover" />
              ) : <Face sb={sb} path={photo} name={f.name || "Tutor"} size={80} className="bg-[#F2B233] text-[#0B1F44]" />}
              <span className="absolute -bottom-1 -right-1 grid size-8 place-items-center rounded-full border-2 border-background bg-[#0B1F44] text-white">
                {uploading ? <span className="size-4 animate-spin rounded-full border-2 border-white/40 border-t-white" /> : <Camera size={16} weight="fill" />}
              </span>
            </button>
            <div className="text-sm">
              <b className="block">Profile photo</b>
              <span className="text-muted-foreground">A clear photo of your face helps students trust you.</span>
              {photo ? <button type="button" className="mt-1 block text-xs font-bold text-red-600" onClick={async () => { await sb.rpc("tutor_photo_save", { p_path: null }); setPhoto(null); setPreview(null); router.refresh(); }}>Remove photo</button> : null}
            </div>
            <input ref={file} type="file" accept="image/*" className="hidden" onChange={(e) => { void upload(e.target.files?.[0]); e.target.value = ""; }} />
          </div>
          <label className="grid gap-1 text-sm font-medium">Name<input className={cls} maxLength={80} value={f.name} onChange={(e) => setF({ ...f, name: e.target.value })} /></label>
          <label className="grid gap-1 text-sm font-medium">Subjects<input className={cls} maxLength={200} placeholder="Physics, Mathematics" value={f.subjects} onChange={(e) => setF({ ...f, subjects: e.target.value })} /></label>
          <div className="grid grid-cols-[110px_1fr] gap-3">
            <label className="grid gap-1 text-sm font-medium">Years teaching<input className={cls} type="number" min={0} max={60} value={f.years} onChange={(e) => setF({ ...f, years: e.target.value })} /></label>
            <label className="grid gap-1 text-sm font-medium">Qualification<input className={cls} maxLength={120} placeholder="B.Sc. Physics" value={f.qualification} onChange={(e) => setF({ ...f, qualification: e.target.value })} /></label>
          </div>
          <label className="grid gap-1 text-sm font-medium">Short bio (shown when you are assigned)<textarea className={cls} rows={4} maxLength={600} placeholder="5 years teaching JAMB Physics…" value={f.bio} onChange={(e) => setF({ ...f, bio: e.target.value })} /></label>
          <div className="flex justify-end gap-2">
            <Button variant="ghost" onClick={() => setOpen(false)}>Cancel</Button>
            <Button disabled={pending} onClick={() => start(async () => {
              const { data, error } = await sb.rpc("tutor_profile_save", { p_name: f.name, p_subjects: f.subjects, p_bio: f.bio, p_years: f.years === "" ? undefined : Number(f.years), p_qualification: f.qualification });
              if (error || !(data as { ok?: boolean })?.ok) return void toast.error("Could not save. Check your name.");
              toast.success("Saved.");
              setOpen(false);
              router.refresh();
            })}>Save</Button>
          </div>
        </DialogContent>
      </Dialog>
    </>
  );
}
