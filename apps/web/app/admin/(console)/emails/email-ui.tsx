"use client";
import { useState, useTransition } from "react";
import { CaretDown, PaperPlaneTilt, SpinnerGap } from "@phosphor-icons/react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { cn } from "@/lib/utils";
import { sendTestToMe } from "./actions";

export function TestButton() {
  const [pending, start] = useTransition();
  return (
    <Button disabled={pending} onClick={() => start(async () => { const r = await sendTestToMe(); if (r.ok) toast.success(r.message); else toast.error(r.error); })}>
      {pending ? <SpinnerGap size={18} className="animate-spin" /> : <PaperPlaneTilt size={18} />} Send me a test email
    </Button>
  );
}

/** Opens a template in a sandboxed frame (no scripts) so it looks like the real email. */
export function Preview({ label, subject, html }: { label: string; subject: string; html: string }) {
  const [open, setOpen] = useState(false);
  return (
    <div className="rounded-xl border">
      <button onClick={() => setOpen((o) => !o)} aria-expanded={open} className="flex w-full items-center gap-3 px-4 py-3 text-left">
        <span className="grow"><b className="block text-sm">{label}</b><span className="block truncate text-xs text-muted-foreground">Subject: {subject}</span></span>
        <CaretDown size={16} className={cn("text-subtle transition-transform", open && "rotate-180")} />
      </button>
      {open ? <iframe title={`${label} preview`} sandbox="" srcDoc={html} className="h-[520px] w-full rounded-b-xl border-t bg-[#F4F6FA]" /> : null}
    </div>
  );
}
