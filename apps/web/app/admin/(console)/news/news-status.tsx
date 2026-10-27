"use client";
import { useSyncExternalStore } from "react";
import { Pill } from "@/components/admin/ui";

// A once-a-minute clock read through useSyncExternalStore (keeps render pure).
const subscribe = (cb: () => void) => { const t = setInterval(cb, 60_000); return () => clearInterval(t); };
const minuteNow = () => Math.floor(Date.now() / 60_000) * 60_000;

/** Draft / Scheduled / Published, worked out against the current time in the browser. */
export function NewsStatus({ status, publishAt }: { status: string; publishAt: string }) {
  const now = useSyncExternalStore(subscribe, minuteNow, () => 0);
  if (status === "draft") return <Pill>Draft</Pill>;
  return now && new Date(publishAt).getTime() > now ? <Pill tone="info">Scheduled</Pill> : <Pill tone="ok">Published</Pill>;
}
