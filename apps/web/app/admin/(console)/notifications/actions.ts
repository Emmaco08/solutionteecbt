"use server";
import { revalidatePath } from "next/cache";
import { z } from "zod";
import { requireStaff } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";
import { friendlyError, type ActionResult } from "@/lib/result";

const editors = () => requireStaff(["super_admin", "admin", "editor"]);

const Msg = z.object({
  title: z.string().trim().min(2, "Title is too short").max(80),
  body: z.string().trim().min(2, "Message is too short").max(240),
  topic: z.enum(["announcements", "new_questions", "streak", "classes", "challenges"]),
  audience: z.enum(["all", "free", "premium", "staff"]),
  link_type: z.enum(["none", "screen", "news", "url"]),
  link_target: z.string().trim().max(300),
  when: z.enum(["now", "later"]),
  at: z.string().optional(),
}).superRefine((m, ctx) => {
  if (m.link_type === "url" && !/^https:\/\/\S+$/.test(m.link_target)) ctx.addIssue({ code: "custom", message: "The link must start with https://" });
  if (m.link_type === "screen" && !m.link_target.startsWith("/")) ctx.addIssue({ code: "custom", message: "Pick a screen" });
  if (m.link_type === "news" && !/^[0-9a-f-]{36}$/.test(m.link_target)) ctx.addIssue({ code: "custom", message: "Pick a news post" });
  if (m.when === "later" && !m.at) ctx.addIssue({ code: "custom", message: "Choose when to send it" });
});

/** Calls the push Edge Function as the signed-in staff member, so a "send now" message goes out at once. */
async function runPush() {
  const supabase = await createClient();
  await supabase.functions.invoke("push", { body: { run: "due" } }).catch(() => null);
}

export async function createNotification(form: FormData): Promise<ActionResult> {
  await editors();
  const p = Msg.safeParse(Object.fromEntries(form));
  if (!p.success) return { ok: false, error: p.error.issues[0]?.message ?? "Check the message" };
  const m = p.data;
  // The form time is Lagos time (WAT, UTC+1 all year).
  const at = m.when === "now" ? new Date() : new Date(`${m.at}:00+01:00`);
  if (Number.isNaN(at.getTime())) return { ok: false, error: "Choose a valid time" };
  if (m.when === "later" && at.getTime() < Date.now() - 60_000) return { ok: false, error: "That time has passed. Choose a later time or send now." };
  const supabase = await createClient();
  const { error } = await supabase.from("notifications").insert({
    title: m.title, body: m.body, topic: m.topic, audience: m.audience,
    link: m.link_type === "none" ? {} : { type: m.link_type, target: m.link_target },
    scheduled_at: at.toISOString(), status: "scheduled", source: "admin",
  });
  if (error) return { ok: false, error: friendlyError(error) };
  if (m.when === "now") await runPush();
  revalidatePath("/admin/notifications");
  return { ok: true, message: m.when === "now" ? (m.audience === "staff" ? "Sent to your test phones." : "Sent.") : "Scheduled." };
}

export async function cancelNotification(id: string): Promise<ActionResult> {
  await editors();
  const supabase = await createClient();
  const { data, error } = await supabase.from("notifications").update({ status: "cancelled" }).eq("id", id).eq("status", "scheduled").select("id");
  if (error) return { ok: false, error: friendlyError(error) };
  if (!data?.length) return { ok: false, error: "It has already been sent." };
  revalidatePath("/admin/notifications");
  return { ok: true, message: "Cancelled." };
}
