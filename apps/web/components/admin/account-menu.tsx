"use client";
import Link from "next/link";
import { CaretDown, ListChecks, ShieldCheck, SignOut } from "@phosphor-icons/react";
import {
  DropdownMenu, DropdownMenuContent, DropdownMenuGroup, DropdownMenuItem, DropdownMenuLabel, DropdownMenuSeparator, DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import { signOut } from "@/app/admin/actions";

const ROLE: Record<string, string> = { super_admin: "Super admin", admin: "Admin", editor: "Editor", teacher: "Teacher" };

export function AccountMenu({ name, email, role }: { name: string; email: string; role: string }) {
  const initials = name.split(/\s+/).map((p) => p[0]).join("").slice(0, 2).toUpperCase();
  return (
    <DropdownMenu>
      <DropdownMenuTrigger className="ml-1 flex items-center gap-2.5 rounded-full py-1 pl-1 pr-2 text-left hover:bg-muted" aria-label="Account">
        <span className="grid size-[34px] place-items-center rounded-full bg-gold text-xs font-bold text-navy">{initials}</span>
        <span className="hidden sm:block"><b className="block text-[13px] leading-4">{name}</b><small className="block text-[11px] text-muted-foreground">{ROLE[role] ?? role}</small></span>
        <CaretDown size={14} className="hidden text-muted-foreground sm:block" />
      </DropdownMenuTrigger>
      <DropdownMenuContent align="end" className="w-72">
        <DropdownMenuGroup>
          <DropdownMenuLabel className="py-2">
            <b className="block text-sm text-foreground">{name}</b>
            <span className="block truncate text-xs font-normal">{email} · {ROLE[role] ?? role}</span>
          </DropdownMenuLabel>
        </DropdownMenuGroup>
        <DropdownMenuSeparator />
        <DropdownMenuItem render={<Link href="/admin/audit" />}><ListChecks size={18} /> Activity log</DropdownMenuItem>
        <DropdownMenuItem disabled><ShieldCheck size={18} /> 2-step login is on</DropdownMenuItem>
        <DropdownMenuSeparator />
        <DropdownMenuItem onClick={() => signOut()} variant="destructive"><SignOut size={18} /> Sign out</DropdownMenuItem>
      </DropdownMenuContent>
    </DropdownMenu>
  );
}
