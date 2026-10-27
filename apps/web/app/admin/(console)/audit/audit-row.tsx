"use client";
import { useState } from "react";
import { CaretDown } from "@phosphor-icons/react";
import { cn } from "@/lib/utils";

type J = Record<string, unknown> | null;
const SKIP = new Set(["updated_at", "content_hash", "updated_by"]);

/** One audit entry; opens to show only the fields that changed. */
export function AuditRow({ when, who, action, table, rowId, area, before, after }: {
  when: string; who: string; action: string; table: string; rowId: string; area: React.ReactNode; before: unknown; after: unknown;
}) {
  const [open, setOpen] = useState(false);
  const b = (before ?? null) as J, a = (after ?? null) as J;
  const keys = [...new Set([...Object.keys(b ?? {}), ...Object.keys(a ?? {})])].filter((k) => !SKIP.has(k) && JSON.stringify(b?.[k]) !== JSON.stringify(a?.[k]));
  const show = (v: unknown) => (v === undefined ? "—" : typeof v === "string" ? v : JSON.stringify(v));
  return (
    <div>
      <button onClick={() => setOpen((o) => !o)} aria-expanded={open} className="flex w-full flex-wrap items-center gap-x-4 gap-y-1 px-5 py-3 text-left text-sm hover:bg-surface-alt">
        <span className="w-40 flex-none text-xs text-muted-foreground">{when}</span>
        <b className="w-44 flex-none truncate">{who}</b>
        <span className="min-w-0 grow truncate"><span className="font-bold capitalize">{action}</span> <span className="text-muted-foreground">{table}{rowId ? ` · ${rowId.slice(0, 8)}` : ""}</span></span>
        {area}
        <CaretDown size={14} className={cn("text-subtle transition-transform", open && "rotate-180")} />
      </button>
      {open ? (
        <div className="bg-surface-alt px-5 pb-4 pt-1">
          {keys.length ? (
            <table className="w-full table-fixed text-xs">
              <thead className="text-left text-subtle"><tr><th className="w-40 py-1.5">Field</th><th className="py-1.5">Before</th><th className="py-1.5">After</th></tr></thead>
              <tbody className="font-mono">
                {keys.slice(0, 30).map((k) => (
                  <tr key={k} className="align-top"><td className="py-1 pr-2 font-sans font-bold">{k}</td>
                    <td className="break-words py-1 pr-2 text-error">{show(b?.[k])}</td><td className="break-words py-1 text-success">{show(a?.[k])}</td></tr>
                ))}
              </tbody>
            </table>
          ) : <p className="text-xs text-muted-foreground">No field changes recorded.</p>}
        </div>
      ) : null}
    </div>
  );
}
