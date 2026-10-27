import { cn } from "@/lib/utils";

/** Page title row with optional description and actions (one primary action per page). */
export function PageHeader({ title, description, actions }: { title: string; description?: string; actions?: React.ReactNode }) {
  return (
    <div className="mb-6 flex flex-wrap items-end justify-between gap-4">
      <div className="min-w-0">
        <h1 className="text-[28px] font-bold leading-[34px] tracking-[-0.4px]">{title}</h1>
        {description ? <p className="mt-1.5 max-w-3xl text-sm leading-5 text-muted-foreground">{description}</p> : null}
      </div>
      {actions ? <div className="flex flex-wrap items-center gap-2">{actions}</div> : null}
    </div>
  );
}

/** Card with a title row, used for every panel. */
export function Panel({ title, actions, children, className, bodyClassName }: {
  title?: React.ReactNode; actions?: React.ReactNode; children: React.ReactNode; className?: string; bodyClassName?: string;
}) {
  return (
    <section className={cn("min-w-0 rounded-2xl border bg-card shadow-[var(--shadow-1)]", className)}>
      {title ? (
        <div className="flex min-h-[60px] items-center justify-between gap-3 border-b px-5 py-3">
          <h2 className="text-[17px] font-bold leading-6">{title}</h2>
          {actions ? <div className="flex items-center gap-2">{actions}</div> : null}
        </div>
      ) : null}
      <div className={cn("p-5", bodyClassName)}>{children}</div>
    </section>
  );
}

const TONES = {
  ok: "bg-success-soft text-on-success-soft",
  warn: "bg-warning-soft text-on-warning-soft",
  error: "bg-error-soft text-on-error-soft",
  info: "bg-info-soft text-on-info-soft",
  gold: "bg-gold-soft text-on-gold-soft",
  neutral: "bg-sunken text-muted-foreground",
} as const;
export type Tone = keyof typeof TONES;

/** Status pill with a dot (draft, published, banned, …). */
export function Pill({ tone = "neutral", children }: { tone?: Tone; children: React.ReactNode }) {
  return (
    <span className={cn("inline-flex h-6 items-center gap-1.5 whitespace-nowrap rounded-full px-2.5 text-xs font-bold", TONES[tone])}>
      <span className="size-1.5 rounded-full bg-current opacity-80" />{children}
    </span>
  );
}

/** Friendly empty state (every list has one). */
export function EmptyState({ icon, title, children, action }: { icon?: React.ReactNode; title: string; children?: React.ReactNode; action?: React.ReactNode }) {
  return (
    <div className="flex flex-col items-center px-6 py-14 text-center">
      {icon ? <div className="mb-4 grid size-16 place-items-center rounded-full bg-info-soft text-[28px] text-on-info-soft">{icon}</div> : null}
      <h3 className="text-[17px] font-bold">{title}</h3>
      {children ? <p className="mt-1.5 max-w-md text-sm text-muted-foreground">{children}</p> : null}
      {action ? <div className="mt-5">{action}</div> : null}
    </div>
  );
}

/** Error state shown when a query fails (never a blank page). */
export function ErrorState({ message }: { message: string }) {
  return (
    <div role="alert" className="rounded-2xl border border-error/30 bg-error-soft px-5 py-4 text-sm text-on-error-soft">
      <b>Something went wrong.</b> {message} Refresh the page; if it keeps happening, check that the database is running.
    </div>
  );
}

/** Generic page skeleton (loading state). */
export function PageSkeleton({ rows = 6 }: { rows?: number }) {
  return (
    <div aria-busy="true" aria-label="Loading">
      <div className="mb-6 h-9 w-72 animate-pulse rounded-lg bg-muted" />
      <div className="space-y-2 rounded-2xl border bg-card p-5">
        {Array.from({ length: rows }, (_, i) => <div key={i} className="h-11 animate-pulse rounded-lg bg-muted" />)}
      </div>
    </div>
  );
}

export const naira = (kobo: number) => "₦" + (kobo / 100).toLocaleString("en-NG", { maximumFractionDigits: 0 });
export const when = (iso: string | null) =>
  iso ? new Date(iso).toLocaleString("en-GB", { day: "numeric", month: "short", year: "numeric", hour: "2-digit", minute: "2-digit" }) : "—";
