"use client";
import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { UserCircleGear } from "@phosphor-icons/react";
import { Button } from "@/components/ui/button";
import { Dialog, DialogContent, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { createClient } from "@/lib/supabase/client";

const cls = "w-full rounded-xl border bg-background px-3 py-2 text-sm outline-none focus-visible:ring-2 focus-visible:ring-ring";

/** What students see about their tutor: name, subjects and a short bio. */
export function TutorProfileButton({ initial }: { initial: { name: string; subjects: string; bio: string; years: string; qualification: string } }) {
  const router = useRouter();
  const [open, setOpen] = useState(false);
  const [f, setF] = useState(initial);
  const [pending, start] = useTransition();
  return (
    <>
      <button type="button" onClick={() => setOpen(true)} className="hidden items-center gap-1.5 rounded-full bg-white/10 px-3 py-1.5 text-xs font-bold hover:bg-white/20 sm:flex">
        <UserCircleGear size={18} /> My profile
      </button>
      <Dialog open={open} onOpenChange={setOpen}>
        <DialogContent>
          <DialogHeader><DialogTitle>Your tutor profile</DialogTitle></DialogHeader>
          <p className="text-sm text-muted-foreground">Your students see this in the app, on the &ldquo;Tutor assigned&rdquo; screen and in the chat.</p>
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
              const { data, error } = await createClient().rpc("tutor_profile_save", { p_name: f.name, p_subjects: f.subjects, p_bio: f.bio, p_years: f.years === "" ? undefined : Number(f.years), p_qualification: f.qualification });
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
