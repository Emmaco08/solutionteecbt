"use client";
import { useTransition } from "react";
import { useRouter } from "next/navigation";
import { SpinnerGap } from "@phosphor-icons/react";
import { toast } from "sonner";
import { cn } from "@/lib/utils";
import { setYearStatus } from "./actions";

export function YearChip({ id, year, status, total, published, editable }: {
  id: number; year: number; status: "draft" | "published"; total: number; published: number; editable: boolean;
}) {
  const router = useRouter();
  const [pending, start] = useTransition();
  const pub = status === "published";
  const toggle = () => {
    if (!editable) return;
    const next = pub ? "draft" : "published";
    if (next === "published" && published === 0 && !confirm(`${year} has no published questions yet. Publish the year anyway?`)) return;
    if (next === "draft" && !confirm(`Unpublish ${year}? Students will stop seeing it.`)) return;
    start(async () => {
      const r = await setYearStatus(id, next);
      if (r.ok) { toast.success(next === "published" ? `${year} published. Students can see it now.` : `${year} unpublished.`); router.refresh(); }
      else toast.error(r.error);
    });
  };
  return (
    <button type="button" onClick={toggle} disabled={pending || !editable}
      aria-label={`${year}: ${pub ? "published" : "draft"}. ${editable ? "Tap to change." : ""}`}
      className={cn("flex flex-col items-start gap-0.5 rounded-xl px-3 py-2.5 text-left ring-1 ring-border transition hover:-translate-y-px hover:shadow-[var(--shadow-1)] disabled:hover:translate-y-0",
        pub ? "bg-success-soft" : "bg-warning-soft")}>
      <b className={cn("flex items-center gap-1", pub ? "text-on-success-soft" : "text-on-warning-soft")}>{year}{pending ? <SpinnerGap size={12} className="animate-spin" /> : null}</b>
      <small className="text-[11px] text-muted-foreground">{published}/{total} live · {pub ? "published" : "draft"}</small>
    </button>
  );
}
