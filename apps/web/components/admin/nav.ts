// Admin navigation (same groups as the approved prototype, design-spec §7).
// `soon` items belong to later phases and are shown greyed out so the map is honest about what exists.
export type NavItem = { href: string; label: string; icon: string; soon?: string; roles?: ("super_admin" | "admin" | "editor" | "teacher")[] };
export type NavGroup = { label: string; items: NavItem[] };

const ADMINS = ["super_admin", "admin"] as NavItem["roles"];

export const NAV: NavGroup[] = [
  { label: "Overview", items: [{ href: "/admin", label: "Dashboard", icon: "SquaresFour" }] },
  {
    label: "Content",
    items: [
      { href: "/admin/questions", label: "Question bank", icon: "Database" },
      { href: "/admin/import", label: "CSV import", icon: "FileCsv" },
      { href: "/admin/passages", label: "Passages", icon: "Article" },
      { href: "/admin/exams", label: "Exams & years", icon: "Exam" },
      { href: "/admin/news", label: "News", icon: "Newspaper" },
      { href: "/admin/study", label: "Study content", icon: "Books" },
      { href: "/admin/challenges", label: "Challenges & events", icon: "Trophy", soon: "Phase 4b" },
    ],
  },
  {
    label: "Students",
    items: [
      { href: "/admin/users", label: "Users", icon: "Users", roles: ADMINS },
      { href: "/admin/referrals", label: "Referrals", icon: "Gift", soon: "Phase 4b" },
      { href: "/admin/fraud", label: "Fraud & bans", icon: "ShieldWarning", soon: "Phase 4b" },
    ],
  },
  {
    label: "Money",
    items: [
      { href: "/admin/plans", label: "Plans & prices", icon: "SlidersHorizontal", roles: ADMINS },
      { href: "/admin/payments", label: "Payments", icon: "Receipt", soon: "Phase 4" },
      { href: "/admin/codes", label: "Redeem codes", icon: "Ticket", soon: "Phase 4" },
    ],
  },
  {
    label: "App control",
    items: [
      { href: "/admin/access", label: "Free vs Premium", icon: "Scales", roles: ADMINS },
      { href: "/admin/onboarding", label: "Onboarding", icon: "DeviceMobile", roles: ADMINS },
      { href: "/admin/tabs", label: "Tabs manager", icon: "Layout", roles: ADMINS },
      { href: "/admin/ai", label: "AI tutor", icon: "Sparkle", roles: ADMINS },
      { href: "/admin/settings", label: "Flags & settings", icon: "ToggleRight", roles: ADMINS },
      { href: "/admin/leaderboard", label: "Leaderboard", icon: "Ranking", soon: "Phase 4" },
    ],
  },
  {
    label: "System",
    items: [
      { href: "/admin/staff", label: "Staff", icon: "IdentificationBadge", roles: ADMINS },
      { href: "/admin/emails", label: "Emails", icon: "EnvelopeSimple", roles: ADMINS },
      { href: "/admin/audit", label: "Audit log", icon: "ListChecks", roles: ADMINS },
    ],
  },
];

export const QUICK_ACTIONS = [
  { href: "/admin/questions/new", label: "New question", icon: "PlusCircle" },
  { href: "/admin/import", label: "Import questions from CSV", icon: "FileCsv" },
  { href: "/admin/news/new", label: "Post news", icon: "Newspaper" },
  { href: "/admin/exams", label: "Publish a year", icon: "Exam" },
  { href: "/admin/users", label: "Find a student", icon: "MagnifyingGlass" },
  { href: "/admin/settings", label: "Maintenance mode", icon: "Wrench" },
];

export function findNav(pathname: string) {
  let best: { group: string; item: NavItem } | null = null;
  for (const g of NAV)
    for (const it of g.items)
      if (!it.soon && (pathname === it.href || (it.href !== "/admin" && pathname.startsWith(it.href + "/")) || pathname === it.href))
        if (!best || it.href.length > best.item.href.length) best = { group: g.label, item: it };
  return best ?? { group: "Overview", item: NAV[0]!.items[0]! };
}
