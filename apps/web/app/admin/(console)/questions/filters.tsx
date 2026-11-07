"use client";
import { useEffect, useState, useTransition } from "react";
import { usePathname, useRouter } from "next/navigation";
import { MagnifyingGlass, SpinnerGap } from "@phosphor-icons/react";
import { ENGLISH_SECTIONS } from "@solutiontee/shared/csv";
import { cn } from "@/lib/utils";

type Opt = { id: number; name?: string; code?: string };

/** Search box, exam/subject/year selects and status tabs. Everything lives in the URL so links can be shared. */
export function Filters({ exams, subjects, current, tabs }: {
  exams: Opt[]; subjects: Opt[]; current: Record<"q" | "exam" | "subject" | "year" | "status" | "section", string>; tabs: [string, string, number][];
}) {
  const router = useRouter();
  const path = usePathname();
  const [pending, start] = useTransition();
  const [q, setQ] = useState(current.q);

  const push = (patch: Partial<typeof current>) => {
    const next = { ...current, ...patch };
    const sp = new URLSearchParams();
    for (const [k, v] of Object.entries(next)) if (v) sp.set(k, v);
    start(() => router.push(`${path}${sp.size ? `?${sp}` : ""}`));
  };
  useEffect(() => {
    if (q === current.q) return;
    const t = setTimeout(() => push({ q }), 350);
    return () => clearTimeout(t);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [q]);

  const sel = "h-10 rounded-xl border border-input bg-card px-3 text-sm outline-none focus-visible:ring-2 focus-visible:ring-ring";
  const years = Array.from({ length: new Date().getFullYear() - 1977 }, (_, i) => new Date().getFullYear() - i);
  return (
    <div className="mb-3 space-y-3">
      <div className="flex gap-1 overflow-x-auto border-b [scrollbar-width:none] [&::-webkit-scrollbar]:hidden">
        {tabs.map(([key, label, n]) => (
          <button key={label} onClick={() => push({ status: key })}
            className={cn("relative h-11 whitespace-nowrap px-3 text-sm font-bold text-muted-foreground hover:text-foreground",
              current.status === key && "text-foreground after:absolute after:inset-x-2 after:-bottom-px after:h-0.5 after:rounded after:bg-blue")}>
            {label} <span className="ml-1 rounded-full bg-muted px-1.5 py-px text-xs">{n.toLocaleString()}</span>
          </button>
        ))}
      </div>
      <div className="flex flex-wrap gap-2">
        <label className="relative min-w-[220px] flex-1">
          <MagnifyingGlass size={18} className="absolute left-3 top-1/2 -translate-y-1/2 text-subtle" />
          <input value={q} onChange={(e) => setQ(e.target.value)} placeholder="Search question text" aria-label="Search question text"
            className="h-10 w-full rounded-xl border border-input bg-card pl-10 pr-9 text-sm outline-none focus-visible:ring-2 focus-visible:ring-ring" />
          {pending ? <SpinnerGap size={16} className="absolute right-3 top-1/2 -translate-y-1/2 animate-spin text-subtle" /> : null}
        </label>
        <select aria-label="Exam" className={sel} value={current.exam} onChange={(e) => push({ exam: e.target.value })}>
          <option value="">All exams</option>{exams.map((x) => <option key={x.id} value={x.id}>{x.code}</option>)}
        </select>
        <select aria-label="Subject" className={sel} value={current.subject} onChange={(e) => push({ subject: e.target.value })}>
          <option value="">All subjects</option>{subjects.map((x) => <option key={x.id} value={x.id}>{x.name}</option>)}
        </select>
        <select aria-label="Year" className={sel} value={current.year} onChange={(e) => push({ year: e.target.value })}>
          <option value="">All years</option>{years.map((y) => <option key={y} value={y}>{y}</option>)}
        </select>
        {subjects.find((x) => String(x.id) === current.subject)?.name === "Use of English" ? (
          <select aria-label="JAMB section" className={sel} value={current.section} onChange={(e) => push({ section: e.target.value })}>
            <option value="">All sections</option>
            {ENGLISH_SECTIONS.map((x) => <option key={x.key} value={x.key}>{x.label}</option>)}
            <option value="none">Not sorted</option>
          </select>
        ) : null}
      </div>
    </div>
  );
}
