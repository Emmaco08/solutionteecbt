import { Suspense } from "react";
import { requireStaff } from "@/lib/auth";
import { Shell } from "@/components/admin/shell";
import { AccountMenu } from "@/components/admin/account-menu";

export default function ConsoleLayout({ children }: LayoutProps<"/admin">) {
  return (
    <Suspense fallback={<ShellSkeleton />}>
      <Console>{children}</Console>
    </Suspense>
  );
}

async function Console({ children }: { children: React.ReactNode }) {
  const staff = await requireStaff();
  return (
    <Shell role={staff.role} account={<AccountMenu name={staff.name} email={staff.email} role={staff.role} />}>
      {children}
    </Shell>
  );
}

function ShellSkeleton() {
  return (
    <div className="grid min-h-dvh lg:grid-cols-[264px_minmax(0,1fr)]" aria-busy="true" aria-label="Loading the admin">
      <div className="hidden bg-navy-deep lg:block" />
      <div>
        <div className="h-16 border-b bg-card" />
        <div className="mx-auto max-w-[1360px] space-y-4 p-6">
          <div className="h-9 w-64 animate-pulse rounded-lg bg-muted" />
          <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
            {[0, 1, 2, 3].map((i) => <div key={i} className="h-28 animate-pulse rounded-2xl bg-muted" />)}
          </div>
          <div className="h-80 animate-pulse rounded-2xl bg-muted" />
        </div>
      </div>
    </div>
  );
}
