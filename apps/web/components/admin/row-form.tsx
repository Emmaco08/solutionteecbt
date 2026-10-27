"use client";
import { useTransition } from "react";
import { useRouter } from "next/navigation";
import { SpinnerGap } from "@phosphor-icons/react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { cn } from "@/lib/utils";
import type { ActionResult } from "@/lib/result";

/** A small form that saves one row with a server action and shows a toast. */
export function RowForm({ action, success, children, className, submitLabel = "Save", extra }: {
  action: (f: FormData) => Promise<ActionResult>; success: string; children: React.ReactNode; className?: string; submitLabel?: string; extra?: React.ReactNode;
}) {
  const router = useRouter();
  const [pending, start] = useTransition();
  return (
    <form className={cn("space-y-3", className)}
      action={(f) => start(async () => { const r = await action(f); if (r.ok) { toast.success(r.message ?? success); router.refresh(); } else toast.error(r.error); })}>
      {children}
      <div className="flex items-center justify-end gap-2">
        {extra}
        <Button type="submit" size="sm" disabled={pending}>{pending ? <SpinnerGap size={14} className="animate-spin" /> : null} {submitLabel}</Button>
      </div>
    </form>
  );
}

export const inputCls = "h-10 w-full rounded-xl border border-input bg-card px-3 text-sm outline-none focus-visible:ring-2 focus-visible:ring-ring";
