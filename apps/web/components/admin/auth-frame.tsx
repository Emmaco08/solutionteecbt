/** Two-column frame for login, 2-step and invite pages: brand panel on the left, form on the right. */
export function AuthFrame({ title, subtitle, children }: { title: string; subtitle?: string; children: React.ReactNode }) {
  return (
    <main className="grid min-h-dvh lg:grid-cols-[1.05fr_1fr]">
      <section className="relative hidden overflow-hidden bg-navy-deep p-12 text-white lg:flex lg:flex-col lg:justify-between">
        <div className="pointer-events-none absolute -right-24 -top-24 size-96 rounded-full bg-[radial-gradient(circle,rgba(242,178,51,.35),transparent_70%)]" />
        <div className="relative flex items-center gap-3">
          {/* Real brand mark from /brand (never redrawn) */}
          <img src="/brand/favicon.svg" alt="" className="size-10 rounded-xl" />
          <div>
            <p className="text-base font-bold leading-5">SolutionTee</p>
            <p className="text-xs text-[#8FA2C4]">Admin CMS</p>
          </div>
        </div>
        <div className="relative max-w-md">
          <p className="text-[32px] font-bold leading-[38px] tracking-tight">Learn. Think. Solve.</p>
          <p className="mt-3 text-[15px] leading-6 text-[#BCC9DF]">
            Manage questions, exams, plans and the app for thousands of JAMB, WAEC and NECO students.
          </p>
          <div className="mt-8 flex gap-3">
            {["jamb", "waec", "neco"].map((b) => (
              <span key={b} className="grid size-14 place-items-center rounded-2xl bg-white/95 p-1.5">
                <img src={`/brand/exam-bodies/${b}.png`} alt={b.toUpperCase()} className="max-h-full max-w-full object-contain" />
              </span>
            ))}
          </div>
        </div>
        <p className="relative text-xs leading-5 text-[#8FA2C4]">
          SolutionTee CBT is an independent exam-practice platform and is not affiliated with or endorsed by JAMB, WAEC or NECO.
        </p>
      </section>
      <section className="flex items-center justify-center px-4 py-10 sm:px-8">
        <div className="w-full max-w-[400px]">
          <div className="mb-8 flex items-center gap-3 lg:hidden">
            <img src="/brand/favicon.svg" alt="" className="size-9 rounded-xl" />
            <p className="font-bold">SolutionTee Admin</p>
          </div>
          <h1 className="text-[26px] font-bold leading-8 tracking-tight">{title}</h1>
          {subtitle ? <p className="mt-2 text-sm leading-5 text-muted-foreground">{subtitle}</p> : null}
          <div className="mt-8">{children}</div>
        </div>
      </section>
    </main>
  );
}

export function FormSkeleton() {
  return (
    <div className="space-y-4" aria-busy="true" aria-label="Loading">
      {[0, 1, 2].map((i) => <div key={i} className="h-12 animate-pulse rounded-xl bg-muted" />)}
    </div>
  );
}
