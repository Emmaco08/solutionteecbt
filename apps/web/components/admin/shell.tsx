"use client";
import { useEffect, useState, useSyncExternalStore } from "react";
import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import { CaretRight, List, MagnifyingGlass, Moon, Sun, CircleHalf, X } from "@phosphor-icons/react";
import { CommandDialog, Command, CommandEmpty, CommandGroup, CommandInput, CommandItem, CommandList } from "@/components/ui/command";
import { cn } from "@/lib/utils";
import { Icon } from "./icon";
import { NAV, QUICK_ACTIONS, findNav, type NavItem } from "./nav";

type Role = NonNullable<NavItem["roles"]>[number];

/** Admin layout: grouped navy sidebar, top bar with breadcrumbs, Ctrl+K search, theme switch and account slot. */
export function Shell({ role, account, children }: { role: Role | null; account: React.ReactNode; children: React.ReactNode }) {
  const pathname = usePathname();
  const router = useRouter();
  const [sideOpen, setSideOpen] = useState(false);
  const [paletteOpen, setPaletteOpen] = useState(false);
  const here = findNav(pathname);
  const allowed = (it: NavItem) => !it.roles || (role !== null && it.roles.includes(role));

  // Close the mobile menu when the page changes (adjust state during render, no effect).
  const [lastPath, setLastPath] = useState(pathname);
  if (lastPath !== pathname) { setLastPath(pathname); setSideOpen(false); }
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === "k") { e.preventDefault(); setPaletteOpen((o) => !o); }
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, []);

  const go = (href: string) => { setPaletteOpen(false); router.push(href); };

  return (
    <div className="grid min-h-dvh lg:grid-cols-[264px_minmax(0,1fr)]">
      {/* Sidebar */}
      <aside
        className={cn(
          "fixed inset-y-0 left-0 z-40 flex w-[280px] flex-col gap-3 bg-[linear-gradient(180deg,var(--navy-950),#071530)] px-3 pb-4 pt-5 text-[#DCE4F2] transition-transform duration-300 ease-out lg:sticky lg:top-0 lg:h-dvh lg:w-auto lg:translate-x-0",
          sideOpen ? "translate-x-0 shadow-2xl" : "-translate-x-full",
        )}
        aria-label="Admin navigation"
      >
        <div className="flex items-center justify-between px-2">
          <Link href="/admin" className="flex items-center gap-3 text-white">
            <img src="/brand/favicon.svg" alt="" className="size-9 rounded-[10px]" />
            <span><b className="block text-[15px] leading-[18px]">SolutionTee</b><small className="block text-[11px] tracking-wide text-[#8FA2C4]">Admin CMS</small></span>
          </Link>
          <button className="grid size-10 place-items-center rounded-full hover:bg-white/10 lg:hidden" onClick={() => setSideOpen(false)} aria-label="Close menu"><X size={20} /></button>
        </div>
        <button
          onClick={() => setPaletteOpen(true)}
          className="flex h-10 items-center gap-2 rounded-[10px] bg-white/6 px-2.5 text-left text-[13px] text-[#9FB0CE] ring-1 ring-white/7 transition-colors hover:bg-white/10 hover:text-white"
        >
          <MagnifyingGlass size={16} /><span className="grow">Search or jump to…</span>
          <kbd className="rounded-md bg-white/10 px-1.5 py-1 text-[11px] font-bold leading-none">Ctrl K</kbd>
        </button>
        <nav className="-mx-1 flex-1 overflow-y-auto px-1 [scrollbar-width:thin]">
          {NAV.map((g) => {
            const items = g.items.filter(allowed);
            if (!items.length) return null;
            return (
              <div key={g.label} className="flex flex-col gap-px pb-3">
                <span className="px-3 pb-1.5 pt-2 text-[11px] font-bold uppercase tracking-[0.8px] text-[#6F84A9]">{g.label}</span>
                {items.map((it) => {
                  const on = !it.soon && here.item.href === it.href;
                  if (it.soon)
                    return (
                      <span key={it.href} className="flex min-h-[38px] items-center gap-2.5 rounded-[10px] px-3 text-sm text-[#BCC9DF]/45" title={`Coming in ${it.soon}`}>
                        <Icon name={it.icon} /><span className="grow">{it.label}</span>
                        <span className="rounded-full bg-white/8 px-1.5 py-0.5 text-[10px] font-bold">{it.soon}</span>
                      </span>
                    );
                  return (
                    <Link
                      key={it.href} href={it.href} aria-current={on ? "page" : undefined}
                      className={cn(
                        "relative flex min-h-[38px] items-center gap-2.5 rounded-[10px] px-3 text-sm text-[#BCC9DF] transition-colors hover:bg-white/6 hover:text-white",
                        on && "bg-white/9 font-bold text-white before:absolute before:-left-1 before:top-2.5 before:bottom-2.5 before:w-[3px] before:rounded before:bg-gold",
                      )}
                    >
                      <Icon name={it.icon} weight={on ? "fill" : "regular"} className={on ? "text-gold" : "opacity-90"} />
                      <span className="grow">{it.label}</span>
                    </Link>
                  );
                })}
              </div>
            );
          })}
        </nav>
        <div className="border-t border-white/8 pt-3">
          <span className="inline-flex items-center gap-2 rounded-full bg-white/5 px-2.5 py-1.5 text-xs text-[#9FB0CE]">
            <span className="size-2 rounded-full bg-gold shadow-[0_0_0_3px_rgba(242,178,51,.2)]" />Dev database
          </span>
        </div>
      </aside>
      {sideOpen ? <div className="fixed inset-0 z-30 bg-[rgba(6,19,43,.42)] lg:hidden" onClick={() => setSideOpen(false)} /> : null}

      {/* Main */}
      <div className="flex min-w-0 flex-col">
        <header className="sticky top-0 z-20 flex h-16 items-center gap-2 border-b bg-card px-3 sm:px-6">
          <button className="grid size-10 place-items-center rounded-full hover:bg-muted lg:hidden" onClick={() => setSideOpen(true)} aria-label="Open menu"><List size={22} /></button>
          <nav className="flex min-w-0 items-center gap-1.5 overflow-hidden whitespace-nowrap text-sm" aria-label="Breadcrumb">
            <span className="hidden text-muted-foreground sm:inline">{here.group}</span>
            <CaretRight size={13} className="hidden text-subtle sm:inline" />
            <Link href={here.item.href} className={cn(pathname === here.item.href ? "font-bold" : "text-muted-foreground hover:text-foreground")}>{here.item.label}</Link>
          </nav>
          <span className="grow" />
          <ThemeButton />
          {account}
        </header>
        <main className="mx-auto w-full max-w-[1360px] flex-1 px-4 pb-16 pt-6 sm:px-6">{children}</main>
      </div>

      <CommandDialog open={paletteOpen} onOpenChange={setPaletteOpen} title="Search the admin" description="Jump to a page or action">
        <Command>
          <CommandInput placeholder="Search pages and actions" />
          <CommandList>
            <CommandEmpty>No match.</CommandEmpty>
            <CommandGroup heading="Pages">
              {NAV.flatMap((g) => g.items.filter((it) => !it.soon && allowed(it)).map((it) => (
                <CommandItem key={it.href} value={`${it.label} ${g.label}`} onSelect={() => go(it.href)}>
                  <Icon name={it.icon} /><span className="grow">{it.label}</span><span className="text-xs text-muted-foreground">{g.label}</span>
                </CommandItem>
              )))}
            </CommandGroup>
            <CommandGroup heading="Actions">
              {QUICK_ACTIONS.map((a) => (
                <CommandItem key={a.href + a.label} value={a.label} onSelect={() => go(a.href)}>
                  <Icon name={a.icon} /><span>{a.label}</span>
                </CommandItem>
              ))}
            </CommandGroup>
          </CommandList>
        </Command>
      </CommandDialog>
    </div>
  );
}

const THEMES = [
  { key: "system", label: "Theme follows your device", Icon: CircleHalf },
  { key: "light", label: "Light theme", Icon: Sun },
  { key: "dark", label: "Dark theme", Icon: Moon },
] as const;

function ThemeButton() {
  type Mode = (typeof THEMES)[number]["key"];
  const mode = useSyncExternalStore<Mode>(
    (cb) => { window.addEventListener("st-theme", cb); window.addEventListener("storage", cb); return () => { window.removeEventListener("st-theme", cb); window.removeEventListener("storage", cb); }; },
    () => { try { return (localStorage.getItem("st-theme") as Mode) || "system"; } catch { return "system"; } },
    () => "system",
  );
  const apply = (m: Mode) => {
    try { localStorage.setItem("st-theme", m); } catch {}
    window.dispatchEvent(new Event("st-theme"));
    const dark = m === "dark" || (m === "system" && matchMedia("(prefers-color-scheme: dark)").matches);
    document.documentElement.classList.toggle("dark", dark);
    document.documentElement.classList.toggle("light", !dark);
  };
  const cur = THEMES.find((t) => t.key === mode) ?? THEMES[0];
  const next = THEMES[(THEMES.indexOf(cur) + 1) % THEMES.length]!;
  return (
    <button onClick={() => apply(next.key)} aria-label={`${cur.label}. Switch to: ${next.label}`} title={cur.label}
      className="grid size-10 place-items-center rounded-full hover:bg-muted">
      <cur.Icon size={20} />
    </button>
  );
}
