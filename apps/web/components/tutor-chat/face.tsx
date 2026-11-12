"use client";
import type { SupabaseClient } from "@supabase/supabase-js";
import { cn } from "@/lib/utils";
import { initials, useAvatar } from "./lib";

/** A person's photo (signed, private R2) or their initials, with a green dot when online (D-154). */
export function Face({ sb, path, name, size = 48, className, online, dotRing = "border-card" }: {
  sb: SupabaseClient; path?: string | null; name: string; size?: number; className?: string; online?: boolean; dotRing?: string;
}) {
  const url = useAvatar(sb, path);
  return (
    <span className={cn("relative grid shrink-0 place-items-center rounded-full font-bold", className)} style={{ width: size, height: size, fontSize: size * 0.34 }}>
      {url ? (
        // eslint-disable-next-line @next/next/no-img-element
        <img src={url} alt={name} className="absolute inset-0 size-full rounded-full object-cover" />
      ) : initials(name)}
      {online ? <span className={cn("absolute bottom-0 right-0 rounded-full border-2 bg-emerald-500", dotRing)} style={{ width: Math.max(10, size * 0.26), height: Math.max(10, size * 0.26) }} /> : null}
    </span>
  );
}
