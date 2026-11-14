"use client";
import { useCallback, useEffect, useRef, useState, useTransition, type ReactNode } from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { BookOpenText, DownloadSimple, Lightbulb, UploadSimple } from "@phosphor-icons/react";
import { Button } from "@/components/ui/button";
import { Label } from "@/components/ui/label";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { MathText } from "@/components/admin/math-text";
import { inputCls } from "@/components/admin/row-form";
import { EmptyState, Panel, Pill } from "@/components/admin/ui";
import { GZ_GUIDE, type GzGameId } from "./gamezone-shared";
import { checkCardsCsv, checkPassagesCsv, checkWordsCsv, KIND_NAMES, type Checked, type Subject } from "./gz-csv-check";
import {
  deleteGzPassage, importGzCards, importGzPassages, importGzWords, listGzPassages, saveGzReading, setGzPassage, undoGzPassageBatch, type GzPassageRow,
} from "./gz-content-actions";

// Admin → Games, one tab per game (owner, 13 Nov 2026): what the game is, what content suits it, and a CSV upload in the
// game's own format, checked here before anything is saved.

function download(name: string, text: string) {
  const url = URL.createObjectURL(new Blob(["﻿" + text], { type: "text/csv;charset=utf-8" }));
  Object.assign(document.createElement("a"), { href: url, download: name }).click();
  URL.revokeObjectURL(url);
}

// ---------------------------------------------------------------- the tabs shell

export function GzAdminTabs({ tabs }: { tabs: { id: string; label: string; content: ReactNode }[] }) {
  const [tab, setTab] = useState(() => {
    if (typeof window === "undefined") return tabs[0]?.id;
    const t = new URLSearchParams(window.location.search).get("tab");
    return tabs.some((x) => x.id === t) ? t : tabs[0]?.id;
  });
  return (
    <Tabs
      value={tab}
      onValueChange={(v) => {
        setTab(String(v));
        const u = new URL(window.location.href);
        u.searchParams.set("tab", String(v));
        window.history.replaceState(null, "", u);
      }}
    >
      <TabsList className="mb-2 h-auto! w-full flex-wrap justify-start gap-1">
        {tabs.map((t) => (
          <TabsTrigger key={t.id} value={t.id} className="flex-none px-3 py-1.5">
            {t.label}
          </TabsTrigger>
        ))}
      </TabsList>
      {tabs.map((t) => (
        <TabsContent key={t.id} value={t.id} className="grid gap-4">
          {t.content}
        </TabsContent>
      ))}
    </Tabs>
  );
}

/** "How this game works" and "Best questions for it". */
export function GzGuide({ game, shared }: { game: GzGameId; shared?: string }) {
  const g = GZ_GUIDE[game];
  return (
    <div className="grid gap-3 md:grid-cols-2">
      <div className="rounded-2xl border bg-card p-4">
        <p className="mb-2 flex items-center gap-2 font-bold"><BookOpenText size={18} weight="duotone" /> How the game works</p>
        <ul className="grid list-disc gap-1 pl-5 text-sm text-muted-foreground">{g.how.map((x) => <li key={x}>{x}</li>)}</ul>
      </div>
      <div className="rounded-2xl border bg-card p-4">
        <p className="mb-2 flex items-center gap-2 font-bold"><Lightbulb size={18} weight="duotone" /> Best content for it</p>
        <ul className="grid list-disc gap-1 pl-5 text-sm text-muted-foreground">{g.best.map((x) => <li key={x}>{x}</li>)}</ul>
        {shared ? <p className="mt-2 text-xs font-bold text-muted-foreground">{shared}</p> : null}
      </div>
    </div>
  );
}

// ---------------------------------------------------------------- a CSV box

function CsvBox<T>({ title, help, template, templateName, check, preview, onImport, extra }: {
  title: string;
  help: ReactNode;
  template: string;
  templateName: string;
  check: (text: string) => Checked<T>;
  preview: (row: T, i: number) => ReactNode;
  onImport: (file: string, rows: T[]) => Promise<{ ok: boolean; error?: string; message?: string }>;
  extra?: ReactNode;
}) {
  const router = useRouter();
  const [pending, start] = useTransition();
  const [file, setFile] = useState<{ name: string } & Checked<T> | null>(null);
  const input = useRef<HTMLInputElement>(null);
  async function pick(f: File) {
    if (!/\.csv$/i.test(f.name) && f.type !== "text/csv") return toast.error("Choose a .csv file (in Excel: Save As → CSV UTF-8).");
    if (f.size > 10 * 1024 * 1024) return toast.error("The file is over 10 MB. Split it into smaller files.");
    setFile({ name: f.name, ...check(await f.text()) });
  }
  const blocking = (file?.issues ?? []).some((i) => i.row === 1);
  return (
    <Panel title={title}>
      <div className="grid gap-3 p-1">
        <div className="flex flex-wrap items-end gap-3">
          {extra}
          <Button variant="outline" onClick={() => download(templateName, template)}><DownloadSimple size={16} weight="bold" /> CSV template</Button>
          <input ref={input} type="file" accept=".csv,text/csv" className="hidden" onChange={(e) => { const f = e.target.files?.[0]; if (f) pick(f); e.target.value = ""; }} />
          <Button onClick={() => input.current?.click()}><UploadSimple size={16} weight="bold" /> Choose CSV</Button>
        </div>
        <div className="text-xs text-muted-foreground">{help}</div>
        {file ? (
          <div className="grid gap-3 rounded-xl border p-3">
            <div className="flex flex-wrap items-center gap-2">
              <p className="font-bold">{file.name}</p>
              <Pill tone={file.rows.length ? "ok" : "error"}>{file.summary ?? `${file.rows.length.toLocaleString("en-NG")} ready`}</Pill>
              {file.issues.length ? <Pill tone="warn">{file.issues.length} problems</Pill> : null}
              <div className="ml-auto flex gap-2">
                <Button variant="ghost" onClick={() => setFile(null)}>Cancel</Button>
                <Button disabled={pending || !file.rows.length || blocking} onClick={() => start(async () => {
                  const r = await onImport(file.name, file.rows);
                  if (!r.ok) return void toast.error(r.error ?? "Something went wrong");
                  toast.success(r.message ?? "Added");
                  setFile(null);
                  router.refresh();
                })}>Add them</Button>
              </div>
            </div>
            {file.issues.length ? (
              <ul className="max-h-40 overflow-y-auto text-sm text-on-warning-soft">
                {file.issues.slice(0, 100).map((i, k) => <li key={k}>Row {i.row}: {i.message}</li>)}
              </ul>
            ) : null}
            {file.rows.slice(0, 3).map((r, i) => <div key={i} className="rounded-lg bg-muted/40 p-2 text-sm">{preview(r, i)}</div>)}
            {file.rows.length > 3 ? <p className="text-xs text-muted-foreground">…and {(file.rows.length - 3).toLocaleString("en-NG")} more.</p> : null}
          </div>
        ) : null}
      </div>
    </Panel>
  );
}

// ---------------------------------------------------------------- Word War

export function GzWordsCsv() {
  return (
    <CsvBox
      title="Add Word War words by CSV"
      templateName="word-war-template.csv"
      template={"type,word,answer,wrong_1,wrong_2,wrong_3\nsynonym,Benevolent,Kind,Cruel,Lazy,Proud\nantonym,Scarce,Plentiful,Rare,Little,Small\nspelling,,Accommodate,Acommodate,Accomodate,Acomodate\n"}
      help={<>Columns: <b>type</b> (synonym, antonym or spelling), <b>word</b> (leave empty for spelling), <b>answer</b>, <b>wrong_1, wrong_2, wrong_3</b>. Up to 3,000 rows a file.</>}
      check={checkWordsCsv}
      preview={(r) => <span><b>{r.kind}</b>{r.word ? ` · ${r.word}` : ""} → <b>{r.answer}</b> <span className="text-muted-foreground">(not {r.wrong.join(", ")})</span></span>}
      onImport={(_, rows) => importGzWords(rows)}
    />
  );
}

// ---------------------------------------------------------------- Memory Flash

export function GzCardsCsv({ subjects }: { subjects: Subject[] }) {
  const name = (id: number) => subjects.find((s) => s.id === id)?.name ?? id;
  return (
    <CsvBox
      title="Add Memory Flash cards by CSV"
      templateName="memory-flash-template.csv"
      template={"subject,front,back\nChemistry,Na,Sodium\nBiology,Mitochondrion,Respiration\nEconomics,GDP,Gross Domestic Product\n"}
      help={<>Columns: <b>subject</b> (its name, e.g. Chemistry), <b>front</b>, <b>back</b>. 30 letters at most a side. Up to 3,000 rows a file.</>}
      check={(t) => checkCardsCsv(t, subjects)}
      preview={(r) => <span><b>{name(r.subject_id)}</b>: {r.front} ↔ {r.back}</span>}
      onImport={(_, rows) => importGzCards(rows)}
    />
  );
}

// ---------------------------------------------------------------- Comprehension Clash

const PASSAGE_TEMPLATE = [
  "passage_title,passage,difficulty,type,question,option_a,option_b,option_c,option_d,answer",
  `"The Harmattan","Every year, between November and February, a dry wind blows from the Sahara Desert across West Africa. Nigerians call it the harmattan. The sky turns a pale, milky grey and the air becomes dry and dusty. Mornings are cold while afternoons can still be hot. The haze reduces visibility, so flights are sometimes delayed, yet farmers use the dry weather to harvest and store grain.",easy,main idea,"What is the passage mainly about?","Farming in the Sahara","The harmattan and its effects","How to fly planes","Hot afternoons",B`,
  `"The Harmattan",,,word in context,"As used in the passage, 'haze' means","heavy rain","bright sunshine","dust in the air that makes it hard to see","a storm",C`,
  `"The Harmattan",,,deduction,"Who is most likely to welcome the harmattan?","Pilots","Farmers harvesting grain","Drivers","Nobody",B`,
  `"The Harmattan",,,detail,"When does the harmattan usually blow?","June to August","November to February","All year","Only at night",B`,
  `"The Harmattan",,,writer's purpose,"The writer's main purpose is to","complain about the weather","describe the harmattan and how it affects people","sell grain","praise pilots",B`,
].join("\n") + "\n";

export function GzPassagesCsv() {
  return (
    <CsvBox
      title="Add Comprehension Clash passages by CSV"
      templateName="comprehension-clash-template.csv"
      template={PASSAGE_TEMPLATE}
      help={
        <>
          One row per question. Columns: <b>passage_title</b> (the same title on every question of a passage), <b>passage</b> (the full text, on the first row of
          the passage is enough), difficulty (easy, medium, hard), <b>type</b> (main idea, writer&apos;s purpose, word in context, deduction, detail),{" "}
          <b>question</b>, <b>option_a … option_d</b> (option_e optional), <b>answer</b> (A–E or the option&apos;s text). 3 to 10 questions a passage; 150–350 words a passage reads best.
        </>
      }
      check={checkPassagesCsv}
      preview={(r) => (
        <div>
          <p className="font-bold">{r.title} <span className="font-normal text-muted-foreground">· {r.difficulty} · {r.body.split(/\s+/).length} words · {r.questions.length} questions</span></p>
          <p className="line-clamp-2 text-xs text-muted-foreground">{r.body}</p>
        </div>
      )}
      onImport={(file, rows) => importGzPassages(file, rows)}
    />
  );
}

export function GzReadingForm({ wpm }: { wpm: number }) {
  const router = useRouter();
  const [pending, start] = useTransition();
  const [v, setV] = useState(String(wpm));
  const n = Number(v) || 240;
  return (
    <Panel title="Reading speed">
      <div className="grid gap-3 p-1 md:grid-cols-[220px_1fr_auto] md:items-end">
        <div>
          <Label htmlFor="gz-wpm">Words per minute</Label>
          <input id="gz-wpm" type="number" min={120} max={600} className={inputCls} value={v} onChange={(e) => setV(e.target.value)} />
        </div>
        <p className="text-xs text-muted-foreground">
          The passage shows for (words ÷ this speed), between 20 seconds and 3 minutes. At {n} words a minute, a 200-word passage shows for {Math.round((200 / n) * 60)} seconds.
          JAMB candidates should aim for 200–250. Higher is harder.
        </p>
        <Button disabled={pending} onClick={() => start(async () => {
          const r = await saveGzReading({ wpm: v });
          if (!r.ok) return void toast.error(r.error);
          toast.success(r.message);
          router.refresh();
        })}>Save</Button>
      </div>
    </Panel>
  );
}

export function GzPassages() {
  const router = useRouter();
  const [pending, start] = useTransition();
  const [list, setList] = useState<{ rows: GzPassageRow[]; total: number; batches: { batch: string; n: number }[] } | null>(null);
  const [q, setQ] = useState("");
  const [page, setPage] = useState(0);
  const [open, setOpen] = useState<number | null>(null);
  const load = useCallback(async () => {
    const r = await listGzPassages(q, page);
    if (r.ok) setList(r.data ?? null);
    else toast.error(r.error);
  }, [q, page]);
  useEffect(() => {
    const t = setTimeout(load, 250);
    return () => clearTimeout(t);
  }, [load]);
  const act = (fn: () => Promise<{ ok: boolean; error?: string; message?: string }>) => start(async () => {
    const r = await fn();
    if (!r.ok) return void toast.error(r.error ?? "Something went wrong");
    toast.success(r.message ?? "Done");
    await load();
    router.refresh();
  });
  return (
    <Panel title="SolutionTee passages">
      <div className="grid gap-3 p-1">
        <div className="flex flex-wrap items-center gap-2">
          <input aria-label="Search passages" className={`${inputCls} h-9 max-w-sm`} placeholder="Search passages" value={q} onChange={(e) => { setQ(e.target.value); setPage(0); }} />
          <span className="text-sm text-muted-foreground">{(list?.total ?? 0).toLocaleString("en-NG")} passages</span>
        </div>
        {list?.batches.length ? (
          <div className="flex flex-wrap gap-2 text-xs">
            <span className="text-muted-foreground">Files:</span>
            {list.batches.map((b) => (
              <span key={b.batch} className="inline-flex items-center gap-1 rounded-full border px-2 py-1">
                {b.batch} ({b.n})
                <button type="button" className="font-bold text-error" disabled={pending}
                  onClick={() => { if (confirm(`Remove all ${b.n} passages from "${b.batch}"?`)) act(() => undoGzPassageBatch(b.batch)); }}>Undo</button>
              </span>
            ))}
          </div>
        ) : null}
        {list && list.rows.length ? (
          <ul className="divide-y rounded-xl border">
            {list.rows.map((p) => (
              <li key={p.id} className="grid gap-2 p-3">
                <div className="flex flex-wrap items-start gap-3">
                  <button type="button" className="min-w-0 flex-1 text-left" onClick={() => setOpen(open === p.id ? null : p.id)}>
                    <p className="font-bold">{p.title || "Untitled passage"}</p>
                    <p className="text-xs text-muted-foreground">{p.difficulty} · {p.body.split(/\s+/).length} words · {p.questions.length} questions · {open === p.id ? "hide" : "show"}</p>
                  </button>
                  <Pill tone={p.active ? "ok" : "neutral"}>{p.active ? "Live" : "Hidden"}</Pill>
                  <Button size="sm" variant="outline" disabled={pending} onClick={() => act(() => setGzPassage(p.id, !p.active))}>{p.active ? "Hide" : "Show"}</Button>
                  <Button size="sm" variant="ghost" disabled={pending} onClick={() => { if (confirm("Delete this passage and its questions?")) act(() => deleteGzPassage(p.id)); }}>Delete</Button>
                </div>
                {open === p.id ? (
                  <div className="grid gap-2 rounded-lg bg-muted/40 p-3 text-sm">
                    <p className="whitespace-pre-line">{p.body}</p>
                    <ol className="grid list-decimal gap-2 pl-5">
                      {p.questions.map((x, i) => (
                        <li key={i}>
                          <span className="mr-1 text-xs font-bold uppercase text-muted-foreground">{KIND_NAMES[x.kind] ?? x.kind}</span>
                          <MathText text={x.body} />
                          <p className="text-xs text-muted-foreground">{Object.entries(x.options).map(([o, v]) => (o === x.answer ? `✓ ${o}. ${v}` : `${o}. ${v}`)).join("   ")}</p>
                        </li>
                      ))}
                    </ol>
                  </div>
                ) : null}
              </li>
            ))}
          </ul>
        ) : list ? (
          <EmptyState title={q ? "No passages match" : "No SolutionTee passages yet"}>Download the template above, fill it in and add it. JAMB comprehension passages are used too (see Overview → question source).</EmptyState>
        ) : null}
        {list && list.total > 20 ? (
          <div className="flex items-center justify-end gap-2">
            <Button size="sm" variant="outline" disabled={page === 0} onClick={() => setPage(page - 1)}>Previous</Button>
            <span className="text-sm">Page {page + 1} of {Math.ceil(list.total / 20)}</span>
            <Button size="sm" variant="outline" disabled={(page + 1) * 20 >= list.total} onClick={() => setPage(page + 1)}>Next</Button>
          </div>
        ) : null}
      </div>
    </Panel>
  );
}
