"use client";
import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { ArrowsClockwise, Key, Lightning, SpinnerGap, Trash } from "@phosphor-icons/react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { Switch } from "@/components/ui/switch";
import { RowForm, inputCls } from "@/components/admin/row-form";
import { createClient } from "@/lib/supabase/client";
import type { ActionResult } from "@/lib/result";
import { activatePrompt, deleteModel, deleteProvider, saveModel, savePrompt, saveProvider, setProviderKey, testModel, testProvider } from "./actions";

export type ProviderRow = { id: string; name: string; base_url: string; enabled: boolean; key_hint: string | null; notes: string | null };
export type ModelRow = {
  id: string; provider_id: string; model: string; label: string | null; purpose: string; priority: number; enabled: boolean;
  temperature: number; max_tokens: number; dimensions: number | null; params: unknown;
};

const area = "w-full rounded-xl border border-input bg-card px-3 py-2.5 text-sm outline-none focus-visible:ring-2 focus-visible:ring-ring";

/** A button that runs one server action and shows the result as a toast. */
function ActButton({ run, children, confirmText, variant = "outline", onData }: {
  run: () => Promise<ActionResult<unknown>>; children: React.ReactNode; confirmText?: string; variant?: "outline" | "ghost"; onData?: (d: unknown) => void;
}) {
  const router = useRouter();
  const [pending, start] = useTransition();
  return (
    <Button type="button" size="sm" variant={variant} disabled={pending}
      onClick={() => (!confirmText || confirm(confirmText)) && start(async () => {
        const r = await run();
        if (r.ok) { toast.success(r.message ?? "Done"); if (r.data !== undefined) onData?.(r.data); router.refresh(); } else toast.error(r.error, { duration: 8000 });
      })}>
      {pending ? <SpinnerGap size={14} className="animate-spin" /> : null} {children}
    </Button>
  );
}

export function ProviderCard({ p, modelCount }: { p?: ProviderRow; modelCount?: number }) {
  const [editKey, setEditKey] = useState(false);
  return (
    <div className="space-y-4 rounded-2xl border bg-card p-5">
      <RowForm action={saveProvider} success="Saved" submitLabel={p ? "Save" : "Add provider"}>
        {p ? <input type="hidden" name="id" value={p.id} /> : null}
        <div className="grid gap-3 sm:grid-cols-[1fr_2fr]">
          <label className="space-y-1 text-sm"><span className="font-bold">Name</span><input name="name" defaultValue={p?.name} required className={inputCls} placeholder="e.g. NVIDIA" /></label>
          <label className="space-y-1 text-sm"><span className="font-bold">API address (OpenAI-compatible)</span><input name="base_url" defaultValue={p?.base_url} required className={inputCls} placeholder="https://integrate.api.nvidia.com/v1" /></label>
        </div>
        <label className="block space-y-1 text-sm"><span className="font-bold">Notes</span><input name="notes" defaultValue={p?.notes ?? ""} className={inputCls} /></label>
        <label className="flex items-center justify-between text-sm"><span>On (students&apos; questions may use it)</span><Switch name="enabled" defaultChecked={p?.enabled ?? true} /></label>
      </RowForm>
      {p ? (
        <div className="flex flex-wrap items-center gap-2 border-t pt-4 text-sm">
          <span className="inline-flex items-center gap-1.5"><Key size={16} /> {p.key_hint ? <>Key ending <b className="font-mono">{p.key_hint}</b></> : <b className="text-error">No API key yet</b>}</span>
          <span className="grow" />
          <Button type="button" size="sm" variant="outline" onClick={() => setEditKey((v) => !v)}>{p.key_hint ? "Change key" : "Add key"}</Button>
          <ActButton run={() => testProvider(p.id)}><Lightning size={14} /> Test</ActButton>
          <ActButton run={() => deleteProvider(p.id)} variant="ghost" confirmText={`Remove ${p.name} and its ${modelCount ?? 0} models?`}><Trash size={14} /></ActButton>
        </div>
      ) : null}
      {p && editKey ? (
        <RowForm action={async (f) => { const r = await setProviderKey(f); if (r.ok) setEditKey(false); return r; }} success="Key saved" submitLabel="Save key">
          <input type="hidden" name="id" value={p.id} />
          <input name="key" type="password" autoComplete="off" required className={`${inputCls} font-mono`} placeholder="Paste the new API key" />
          <p className="text-xs text-muted-foreground">The key is stored encrypted in Supabase Vault. Only the last 4 characters are shown after saving. Students&apos; phones never see it.</p>
        </RowForm>
      ) : null}
    </div>
  );
}

export function ModelForm({ m, providers }: { m?: ModelRow; providers: ProviderRow[] }) {
  const [ids, setIds] = useState<string[]>([]);
  const [provider, setProvider] = useState(m?.provider_id ?? providers[0]?.id ?? "");
  const listId = `models-${m?.id ?? "new"}`;
  return (
    <RowForm action={saveModel} success="Saved" submitLabel={m ? "Save" : "Add model"}
      extra={m ? <>
        <ActButton run={() => testModel(m.id)}><Lightning size={14} /> Test</ActButton>
        <ActButton run={() => deleteModel(m.id)} variant="ghost" confirmText={`Remove ${m.model}?`}><Trash size={14} /></ActButton>
      </> : <ActButton run={() => testProvider(provider)} onData={(d) => setIds((d as { ids: string[] }).ids)}><ArrowsClockwise size={14} /> Load model list</ActButton>}>
      {m ? <input type="hidden" name="id" value={m.id} /> : null}
      <div className="grid gap-3 md:grid-cols-[150px_minmax(0,2fr)_minmax(0,1fr)_120px]">
        <label className="space-y-1 text-xs"><span className="font-bold">Provider</span>
          <select name="provider_id" value={provider} onChange={(e) => setProvider(e.target.value)} className={inputCls}>
            {providers.map((p) => <option key={p.id} value={p.id}>{p.name}</option>)}
          </select></label>
        <label className="space-y-1 text-xs"><span className="font-bold">Model id</span>
          <input name="model" defaultValue={m?.model} required list={listId} className={`${inputCls} font-mono text-xs`} placeholder="e.g. nvidia/nemotron-3.5-super-vl-120b-a12b" />
          <datalist id={listId}>{ids.map((i) => <option key={i} value={i} />)}</datalist></label>
        <label className="space-y-1 text-xs"><span className="font-bold">Label</span><input name="label" defaultValue={m?.label ?? ""} className={inputCls} /></label>
        <label className="space-y-1 text-xs"><span className="font-bold">Used for</span>
          <select name="purpose" defaultValue={m?.purpose ?? "chat"} className={inputCls}>
            <option value="chat">Text questions</option><option value="vision">Photo questions</option><option value="embed">Knowledge (embed)</option>
          </select></label>
      </div>
      <div className="grid grid-cols-2 gap-3 md:grid-cols-[90px_110px_120px_110px_minmax(0,1fr)_auto]">
        <label className="space-y-1 text-xs"><span className="font-bold">Order</span><input name="priority" type="number" min={1} max={99} defaultValue={m?.priority ?? 10} className={inputCls} /></label>
        <label className="space-y-1 text-xs"><span className="font-bold">Temperature</span><input name="temperature" type="number" step="0.05" min={0} max={2} defaultValue={m?.temperature ?? 0.3} className={inputCls} /></label>
        <label className="space-y-1 text-xs"><span className="font-bold">Max tokens</span><input name="max_tokens" type="number" min={64} max={16000} defaultValue={m?.max_tokens ?? 3000} className={inputCls} /></label>
        <label className="space-y-1 text-xs"><span className="font-bold">Dimensions</span><input name="dimensions" type="number" min={64} max={4096} defaultValue={m?.dimensions ?? ""} placeholder="embed only" className={inputCls} /></label>
        <label className="space-y-1 text-xs"><span className="font-bold">Extra settings (JSON, optional)</span>
          <input name="params" defaultValue={m && m.params && Object.keys(m.params as object).length ? JSON.stringify(m.params) : ""} className={`${inputCls} font-mono text-xs`} placeholder='{"chat_template_kwargs":{"thinking":false}}' /></label>
        <label className="flex items-end gap-2 pb-2 text-xs font-bold">On <Switch name="enabled" defaultChecked={m?.enabled ?? true} /></label>
      </div>
    </RowForm>
  );
}

export function PromptEditor({ body, versions }: { body: string; versions: { id: number; version: number; active: boolean; notes: string | null; created_at: string }[] }) {
  return (
    <div className="grid gap-4 lg:grid-cols-[minmax(0,1fr)_260px]">
      <RowForm action={savePrompt} success="Saved" submitLabel="Save as new version">
        <textarea name="body" defaultValue={body} rows={18} className={`${area} font-mono text-[13px] leading-6`} />
        <input name="notes" className={inputCls} placeholder="What changed (optional)" />
      </RowForm>
      <div className="space-y-2">
        <p className="text-xs font-bold uppercase text-muted-foreground">Versions</p>
        {versions.map((v) => (
          <div key={v.id} className="flex items-center gap-2 rounded-xl border px-3 py-2 text-sm">
            <span className="grow"><b>v{v.version}</b> <span className="text-xs text-muted-foreground">{new Date(v.created_at).toLocaleDateString("en-NG", { day: "numeric", month: "short" })}{v.notes ? ` · ${v.notes}` : ""}</span></span>
            {v.active ? <span className="text-xs font-bold text-success">In use</span> : <ActButton run={() => activatePrompt(v.id)} variant="ghost">Use</ActButton>}
          </div>
        ))}
      </div>
    </div>
  );
}

/** Rebuilds the AI's knowledge from published notes, 8 notes per call, until nothing is left. */
export function KnowledgeBox({ chunks, supabaseUrl }: { chunks: number; supabaseUrl: string }) {
  const router = useRouter();
  const [busy, setBusy] = useState(false);
  const [msg, setMsg] = useState("");
  async function run(restart: boolean) {
    if (restart && !confirm("Start over? All knowledge is rebuilt from the notes (takes a few minutes).")) return;
    setBusy(true);
    try {
      const { data } = await createClient().auth.getSession();
      const token = data.session?.access_token;
      if (!token) throw new Error("Log in again.");
      let first = true, total = 0;
      for (let i = 0; i < 80; i++) {
        const r = await fetch(`${supabaseUrl}/functions/v1/ai-index`, {
          method: "POST",
          headers: { authorization: `Bearer ${token}`, "content-type": "application/json" },
          body: JSON.stringify({ mode: restart ? "all" : "missing", restart: restart && first, limit: 8 }),
        });
        const j = await r.json();
        if (!r.ok) throw new Error(j.error ?? `HTTP ${r.status}`);
        first = false;
        total += j.done;
        setMsg(`${total} notes added · ${j.remaining} left · ${j.chunks} pieces of knowledge`);
        if (!j.remaining || !j.done) break;
      }
      toast.success("Knowledge is up to date.");
      router.refresh();
    } catch (e) {
      toast.error(e instanceof Error ? e.message : "Could not rebuild the knowledge.");
    } finally {
      setBusy(false);
    }
  }
  return (
    <div className="space-y-3 text-sm">
      <p>The tutor reads matching parts of your <b>published lesson notes</b> before it answers, so its answers follow your teaching. Right now it knows <b>{chunks.toLocaleString()}</b> pieces.</p>
      <div className="flex flex-wrap gap-2">
        <Button type="button" size="sm" disabled={busy} onClick={() => run(false)}>{busy ? <SpinnerGap size={14} className="animate-spin" /> : <ArrowsClockwise size={14} />} Add new and edited notes</Button>
        <Button type="button" size="sm" variant="outline" disabled={busy} onClick={() => run(true)}>Rebuild everything</Button>
      </div>
      {msg ? <p className="text-xs text-muted-foreground">{msg}</p> : null}
    </div>
  );
}
