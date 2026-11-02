import { Suspense } from "react";
import Link from "next/link";
import type { Metadata } from "next";
import { requireStaff } from "@/lib/auth";
import { env } from "@/lib/env";
import { createClient } from "@/lib/supabase/server";
import { ErrorState, PageHeader, PageSkeleton, Panel, Pill, when } from "@/components/admin/ui";
import { KnowledgeBox, ModelForm, PromptEditor, ProviderCard, type ModelRow, type ProviderRow } from "./forms";

export const metadata: Metadata = { title: "AI tutor" };

export default function Page() {
  return <Suspense fallback={<PageSkeleton rows={8} />}><AiAdmin /></Suspense>;
}

type Health = {
  models: { provider: string; model: string; purpose: string; calls: number; ok: number; avg_ms: number | null; last_at: string; last_error: string | null }[];
  prompts_today: number; students_today: number; chunks: number; flagged: number;
};

const PURPOSES = [
  ["chat", "Text questions", "Tried in this order. When one is busy, slow or fails, the next one answers."],
  ["vision", "Photo questions", "Only models that can read pictures. Text-only models (like Dahl) must not be here."],
  ["embed", "Knowledge (embedding)", "Turns notes into numbers so the tutor can find the right ones. One is enough."],
] as const;

async function AiAdmin() {
  await requireStaff(["super_admin", "admin"]);
  const supabase = await createClient();
  const [providers, models, prompts, health, flagged, rules] = await Promise.all([
    supabase.from("ai_providers").select("id, name, base_url, enabled, key_hint, notes").order("created_at"),
    supabase.from("ai_models").select("id, provider_id, model, label, purpose, priority, enabled, temperature, max_tokens, dimensions, params").order("priority"),
    supabase.from("ai_prompts").select("id, version, active, notes, created_at, body").order("version", { ascending: false }).limit(20),
    supabase.rpc("admin_ai_health"),
    supabase.from("ai_messages").select("id, content, flag_reason, flagged_at, model").not("flagged_at", "is", null).order("flagged_at", { ascending: false }).limit(15),
    supabase.from("access_rules").select("tier, rules"),
  ]);
  if (providers.error) return <ErrorState message={providers.error.message} />;
  const ps = (providers.data ?? []) as ProviderRow[];
  const ms = (models.data ?? []) as ModelRow[];
  const h = (health.data ?? { models: [], prompts_today: 0, students_today: 0, chunks: 0, flagged: 0 }) as Health;
  const active = (prompts.data ?? []).find((p) => p.active);
  const limit = (tier: string) => ((rules.data ?? []).find((r) => r.tier === tier)?.rules as Record<string, unknown> | undefined)?.ai ?? "?";
  const name = (id: string) => ps.find((p) => p.id === id)?.name ?? "?";

  return (
    <>
      <PageHeader title="AI tutor" description="Providers, models, the tutor's instructions and its knowledge. Changes reach students within a minute." />
      <div className="mb-4 grid gap-3 sm:grid-cols-4">
        {[
          ["Prompts today", h.prompts_today.toLocaleString()],
          ["Students today", h.students_today.toLocaleString()],
          ["Daily limit", `Free ${limit("free")} · Premium ${limit("premium")}`],
          ["Marked wrong", h.flagged.toLocaleString()],
        ].map(([k, v]) => (
          <div key={k} className="rounded-2xl border bg-card px-4 py-3"><p className="text-xs text-muted-foreground">{k}</p><p className="text-lg font-bold">{v}</p></div>
        ))}
      </div>
      <p className="mb-6 text-sm text-muted-foreground">Change the daily limits in <Link href="/admin/access" className="font-bold text-link">Free vs Premium</Link> (the &quot;AI tutor prompts&quot; row). Prompts reset at midnight, Lagos time.</p>

      <div className="space-y-6">
        <Panel title="Providers">
          <div className="grid gap-4 xl:grid-cols-2">
            {ps.map((p) => <ProviderCard key={p.id} p={p} modelCount={ms.filter((m) => m.provider_id === p.id).length} />)}
            <div><p className="mb-2 text-sm font-bold">Add another provider</p><ProviderCard /></div>
          </div>
        </Panel>

        {PURPOSES.map(([purpose, title, hint]) => (
          <Panel key={purpose} title={title}>
            <p className="mb-4 text-sm text-muted-foreground">{hint} Lower order number = tried first.</p>
            <div className="space-y-3">
              {ms.filter((m) => m.purpose === purpose).map((m) => (
                <div key={m.id} className={`rounded-xl border p-3 ${m.enabled ? "" : "opacity-60"}`}>
                  <p className="mb-2 text-xs text-muted-foreground"><b className="text-foreground">{m.label ?? m.model}</b> · {name(m.provider_id)}</p>
                  <ModelForm m={m} providers={ps} />
                </div>
              ))}
            </div>
          </Panel>
        ))}

        <Panel title="Add a model">
          <p className="mb-3 text-sm text-muted-foreground">Pick the provider, press <b>Load model list</b> to choose from its models, set what it is used for, then press <b>Test</b> on the new row to check it really answers.</p>
          {ps.length ? <ModelForm providers={ps} /> : <p className="text-sm">Add a provider first.</p>}
        </Panel>

        <Panel title="Health in the last 24 hours">
          {h.models.length ? (
            <div className="overflow-x-auto">
              <table className="w-full text-sm">
                <thead><tr className="text-left text-xs text-muted-foreground"><th className="py-2 pr-3">Model</th><th className="pr-3">Use</th><th className="pr-3">Calls</th><th className="pr-3">Worked</th><th className="pr-3">Average</th><th>Last problem</th></tr></thead>
                <tbody>
                  {h.models.map((x) => (
                    <tr key={x.provider + x.model + x.purpose} className="border-t">
                      <td className="py-2 pr-3"><b>{x.model}</b><br /><span className="text-xs text-muted-foreground">{x.provider} · {when(x.last_at)}</span></td>
                      <td className="pr-3">{x.purpose}</td>
                      <td className="pr-3">{x.calls}</td>
                      <td className="pr-3">{x.ok === x.calls ? <Pill tone="ok">{x.ok}</Pill> : <Pill tone={x.ok ? "warn" : "error"}>{x.ok} of {x.calls}</Pill>}</td>
                      <td className="pr-3">{x.avg_ms ? `${(x.avg_ms / 1000).toFixed(1)} s` : "—"}</td>
                      <td className="max-w-[320px] truncate text-xs text-muted-foreground" title={x.last_error ?? ""}>{x.last_error ?? "—"}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          ) : <p className="text-sm text-muted-foreground">No AI calls yet in the last 24 hours.</p>}
        </Panel>

        <Panel title="The tutor's instructions (system prompt)">
          <PromptEditor body={active?.body ?? ""} versions={(prompts.data ?? []).map(({ body: _b, ...v }) => v)} />
        </Panel>

        <Panel title="Knowledge from your notes">
          <KnowledgeBox chunks={h.chunks} supabaseUrl={env.supabaseUrl} />
        </Panel>

        <Panel title="Answers students marked wrong">
          {flagged.data?.length ? (
            <div className="divide-y">
              {flagged.data.map((f) => (
                <div key={f.id} className="py-3 text-sm">
                  <p className="text-xs text-muted-foreground">{when(f.flagged_at)} · {f.model ?? "?"}{f.flag_reason ? ` · "${f.flag_reason}"` : ""}</p>
                  <p className="mt-1 line-clamp-3 whitespace-pre-line">{f.content}</p>
                </div>
              ))}
            </div>
          ) : <p className="text-sm text-muted-foreground">Nothing reported yet.</p>}
        </Panel>
      </div>
    </>
  );
}
