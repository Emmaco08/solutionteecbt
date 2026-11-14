"use client";
import { useCallback, useEffect, useMemo, useRef, useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { DownloadSimple, UploadSimple } from "@phosphor-icons/react";
import { parseCsv } from "@solutiontee/shared/csv";
import { Button } from "@/components/ui/button";
import { Label } from "@/components/ui/label";
import { MathText } from "@/components/admin/math-text";
import { inputCls } from "@/components/admin/row-form";
import { EmptyState, Panel, Pill } from "@/components/admin/ui";
import {
  deleteGzQuestion, importGzQuestions, listGzQuestions, saveGzSource, setGzQuestion, undoGzBatch, type GzQuestionRow,
} from "./gz-questions-actions";

// Game questions (owner, 12 Nov 2026): SolutionTee's own questions for the games, added by CSV per subject, and where
// game questions come from. Students are never told the source.

type Subject = { id: number; name: string };
type Source = "jamb" | "own" | "both";
const SOURCE_NAMES: Record<Source, string> = { jamb: "JAMB past questions only", own: "SolutionTee questions only", both: "Both, mixed" };

export function GzSourceForm({ subjects, source, sources, counts }: {
  subjects: Subject[]; source: Source; sources: Record<string, Source>; counts: Record<string, { all: number; live: number }>;
}) {
  const router = useRouter();
  const [pending, start] = useTransition();
  const [all, setAll] = useState<Source>(source);
  const [per, setPer] = useState<Record<string, Source | "">>(() => Object.fromEntries(subjects.map((s) => [String(s.id), sources[String(s.id)] ?? ""])));
  return (
    <div className="grid gap-4">
      <div>
        <Label htmlFor="gz-src">Questions in games (all subjects)</Label>
        <select id="gz-src" className={inputCls} value={all} onChange={(e) => setAll(e.target.value as Source)}>
          {(Object.keys(SOURCE_NAMES) as Source[]).map((k) => <option key={k} value={k}>{SOURCE_NAMES[k]}</option>)}
        </select>
        <p className="mt-1 text-xs text-muted-foreground">
          Students never see where a question came from. If a subject has fewer SolutionTee questions than a game needs, past questions fill the gap so a game always starts.
          Questions a student saw in the last 21 days come last, so the more you add, the fewer repeats.
        </p>
      </div>
      <div className="overflow-x-auto rounded-xl border">
        <table className="w-full text-sm">
          <thead className="bg-muted/50 text-left text-xs text-muted-foreground">
            <tr><th className="p-2">Subject</th><th className="p-2">SolutionTee questions (live / all)</th><th className="p-2">Questions in games</th></tr>
          </thead>
          <tbody className="divide-y">
            {subjects.map((s) => {
              const c = counts[String(s.id)];
              return (
                <tr key={s.id}>
                  <td className="p-2 font-bold">{s.name}</td>
                  <td className="p-2 tabular-nums">{c ? `${c.live.toLocaleString("en-NG")} / ${c.all.toLocaleString("en-NG")}` : "0"}</td>
                  <td className="p-2">
                    <select aria-label={`${s.name} questions in games`} className={`${inputCls} h-9`} value={per[String(s.id)]} onChange={(e) => setPer({ ...per, [String(s.id)]: e.target.value as Source | "" })}>
                      <option value="">Same as all subjects ({SOURCE_NAMES[all]})</option>
                      {(Object.keys(SOURCE_NAMES) as Source[]).map((k) => <option key={k} value={k}>{SOURCE_NAMES[k]}</option>)}
                    </select>
                  </td>
                </tr>
              );
            })}
          </tbody>
        </table>
      </div>
      <div className="flex justify-end">
        <Button disabled={pending} onClick={() => start(async () => {
          const r = await saveGzSource({ source: all, sources: per });
          if (!r.ok) return void toast.error(r.error);
          toast.success(r.message);
          router.refresh();
        })}>Save question source</Button>
      </div>
    </div>
  );
}

// ---------------------------------------------------------------- CSV

type Row = { body: string; options: Record<string, string>; answer: string; difficulty: "easy" | "medium" | "hard" };
type Issue = { row: number; message: string };

const TEMPLATE =
  "question,option_a,option_b,option_c,option_d,option_e,answer,difficulty\n" +
  "\"What is 15% of 200?\",20,25,30,35,,C,easy\n" +
  "\"Solve for x: $2x + 3 = 11$\",3,4,5,6,,B,medium\n";

const norm = (h: string) => h.toLowerCase().replace(/[^a-z]/g, "");
const COLS: Record<string, string[]> = {
  body: ["question", "questiontext", "body", "text", "stem"],
  A: ["optiona", "a", "opta", "choicea"],
  B: ["optionb", "b", "optb", "choiceb"],
  C: ["optionc", "c", "optc", "choicec"],
  D: ["optiond", "d", "optd", "choiced"],
  E: ["optione", "e", "opte", "choicee"],
  answer: ["answer", "correct", "correctanswer", "key", "correctoption"],
  difficulty: ["difficulty", "level"],
};

/** Reads and checks a game-questions CSV (columns in any order; the answer can be a letter or the option's text). */
export function checkGzCsv(text: string): { rows: Row[]; issues: Issue[]; headers: string[] } {
  const parsed = parseCsv(text);
  const find = (k: string) => parsed.headers.find((h) => COLS[k].includes(norm(h)));
  const col = Object.fromEntries(Object.keys(COLS).map((k) => [k, find(k)])) as Record<string, string | undefined>;
  const issues: Issue[] = [...parsed.parseErrors];
  for (const k of ["body", "A", "B", "answer"]) {
    if (!col[k]) issues.push({ row: 1, message: `Missing column: ${k === "body" ? "question" : k === "answer" ? "answer" : `option_${k.toLowerCase()}`}` });
  }
  if (issues.some((i) => i.row === 1)) return { rows: [], issues, headers: parsed.headers };
  const rows: Row[] = [];
  const seen = new Set<string>();
  parsed.records.forEach((r, i) => {
    const line = i + 2;
    const body = (r[col.body!] ?? "").trim();
    const options: Record<string, string> = {};
    for (const k of ["A", "B", "C", "D", "E"]) {
      const v = col[k] ? (r[col[k]!] ?? "").trim() : "";
      if (v) options[k] = v;
    }
    let answer = (r[col.answer!] ?? "").trim();
    if (!/^[A-Ea-e]$/.test(answer)) {
      const byText = Object.entries(options).find(([, v]) => v.toLowerCase() === answer.toLowerCase());
      answer = byText ? byText[0] : answer;
    }
    answer = answer.toUpperCase();
    const d = (col.difficulty ? (r[col.difficulty] ?? "") : "").trim().toLowerCase();
    const difficulty = (["easy", "medium", "hard"].includes(d) ? d : "medium") as Row["difficulty"];
    if (!body && !Object.keys(options).length) return;
    if (body.length < 3) return void issues.push({ row: line, message: "The question is empty or too short" });
    if (body.length > 2000) return void issues.push({ row: line, message: "The question is over 2,000 characters" });
    if (Object.keys(options).length < 2) return void issues.push({ row: line, message: "Give at least options A and B" });
    if (Object.values(options).some((v) => v.length > 400)) return void issues.push({ row: line, message: "An option is over 400 characters" });
    if (!options[answer]) return void issues.push({ row: line, message: `The answer "${(r[col.answer!] ?? "").trim()}" is not one of the filled options` });
    if (new Set(Object.values(options).map((v) => v.toLowerCase())).size < Object.keys(options).length) issues.push({ row: line, message: "Two options are the same (added anyway)" });
    const key = body.toLowerCase();
    if (seen.has(key)) return void issues.push({ row: line, message: "Same question twice in this file (skipped)" });
    seen.add(key);
    rows.push({ body, options, answer, difficulty });
  });
  return { rows, issues, headers: parsed.headers };
}

const GAME_NAMES: Record<string, string> = { duel: "JAMB Duel", rush: "Speed Rush", survival: "Knowledge Survival", relay: "Team Relay" };

/** [game]: the quiz game tab this panel is in (its list shows what that game can use, and new uploads can be for it only). */
export function GzQuestions({ subjects, game }: { subjects: Subject[]; game?: string }) {
  const router = useRouter();
  const [pending, start] = useTransition();
  const [subject, setSubject] = useState<number>(subjects[0]?.id ?? 2);
  const [file, setFile] = useState<{ name: string; rows: Row[]; issues: Issue[] } | null>(null);
  const input = useRef<HTMLInputElement>(null);
  const [list, setList] = useState<{ rows: GzQuestionRow[]; total: number; batches: { batch: string; n: number }[] } | null>(null);
  const [q, setQ] = useState("");
  const [page, setPage] = useState(0);
  const [scope, setScope] = useState<"game" | "all">("all");
  const name = (id: number) => subjects.find((s) => s.id === id)?.name ?? `Subject ${id}`;

  const load = useCallback(async () => {
    const r = await listGzQuestions(subject, q, page, game);
    if (r.ok) setList(r.data ?? null);
    else toast.error(r.error);
  }, [subject, q, page, game]);
  useEffect(() => {
    const t = setTimeout(load, 250);
    return () => clearTimeout(t);
  }, [load]);

  async function pick(f: File) {
    if (!/\.csv$/i.test(f.name) && f.type !== "text/csv") return toast.error("Choose a .csv file (in Excel: Save As → CSV UTF-8).");
    if (f.size > 8 * 1024 * 1024) return toast.error("The file is over 8 MB. Split it into smaller files.");
    const r = checkGzCsv(await f.text());
    setFile({ name: f.name, rows: r.rows, issues: r.issues });
  }
  const template = () => {
    const url = URL.createObjectURL(new Blob(["﻿" + TEMPLATE], { type: "text/csv;charset=utf-8" }));
    Object.assign(document.createElement("a"), { href: url, download: "solutiontee-game-questions-template.csv" }).click();
    URL.revokeObjectURL(url);
  };
  const blocking = useMemo(() => (file?.issues ?? []).filter((i) => i.row === 1), [file]);
  const act = (fn: () => Promise<{ ok: boolean; error?: string; message?: string }>) => start(async () => {
    const r = await fn();
    if (!r.ok) return void toast.error(r.error ?? "Something went wrong");
    toast.success(r.message ?? "Done");
    await load();
    router.refresh();
  });

  return (
    <Panel title="Game questions (SolutionTee's own)">
      <div className="grid gap-4 p-1">
        <div className="flex flex-wrap items-end gap-3">
          <div className="min-w-48">
            <Label htmlFor="gzq-subject">Subject</Label>
            <select id="gzq-subject" className={inputCls} value={subject} onChange={(e) => { setSubject(Number(e.target.value)); setPage(0); setFile(null); }}>
              {subjects.map((s) => <option key={s.id} value={s.id}>{s.name}</option>)}
            </select>
          </div>
          {game ? (
            <div className="min-w-56">
              <Label htmlFor="gzq-scope">New questions are for</Label>
              <select id="gzq-scope" className={inputCls} value={scope} onChange={(e) => setScope(e.target.value as "game" | "all")}>
                <option value="all">All 4 quiz games (Duel, Rush, Survival, Relay)</option>
                <option value="game">{GAME_NAMES[game] ?? game} only</option>
              </select>
            </div>
          ) : null}
          <Button variant="outline" onClick={template}><DownloadSimple size={16} weight="bold" /> CSV template</Button>
          <input ref={input} type="file" accept=".csv,text/csv" className="hidden" onChange={(e) => { const f = e.target.files?.[0]; if (f) pick(f); e.target.value = ""; }} />
          <Button onClick={() => input.current?.click()}><UploadSimple size={16} weight="bold" /> Choose CSV for {name(subject)}</Button>
        </div>
        <p className="text-xs text-muted-foreground">
          Columns: <b>question, option_a, option_b, option_c, option_d</b> (option_e optional), <b>answer</b> (A–E or the option&apos;s text), difficulty (easy, medium, hard; optional).
          Maths works with $...$ like the question bank. Every row goes into the subject chosen above, up to 5,000 per file.
        </p>

        {file ? (
          <div className="grid gap-3 rounded-xl border p-3">
            <div className="flex flex-wrap items-center gap-2">
              <p className="font-bold">{file.name}</p>
              <Pill tone={file.rows.length ? "ok" : "error"}>{file.rows.length.toLocaleString("en-NG")} ready for {name(subject)}</Pill>
              {file.issues.length ? <Pill tone="warn">{file.issues.length} problems</Pill> : null}
              <div className="ml-auto flex gap-2">
                <Button variant="ghost" onClick={() => setFile(null)}>Cancel</Button>
                <Button disabled={pending || !file.rows.length || blocking.length > 0}
                  onClick={() => act(async () => { const r = await importGzQuestions(subject, file.name, file.rows, game && scope === "game" ? [game] : null); if (r.ok) setFile(null); return r; })}>
                  Add {file.rows.length.toLocaleString("en-NG")} questions
                </Button>
              </div>
            </div>
            {file.issues.length ? (
              <ul className="max-h-40 overflow-y-auto text-sm text-on-warn-soft">
                {file.issues.slice(0, 100).map((i, k) => <li key={k}>Row {i.row}: {i.message}</li>)}
              </ul>
            ) : null}
            {file.rows.slice(0, 3).map((r, k) => (
              <div key={k} className="rounded-lg bg-muted/40 p-2 text-sm">
                <MathText text={r.body} />
                <p className="mt-1 text-xs text-muted-foreground">
                  {Object.entries(r.options).map(([o, v]) => `${o}. ${v}`).join("   ")} · Answer {r.answer} · {r.difficulty}
                </p>
              </div>
            ))}
            {file.rows.length > 3 ? <p className="text-xs text-muted-foreground">…and {(file.rows.length - 3).toLocaleString("en-NG")} more.</p> : null}
          </div>
        ) : null}

        <div className="flex flex-wrap items-center gap-2">
          <input aria-label="Search game questions" className={`${inputCls} h-9 max-w-sm`} placeholder={`Search ${name(subject)} game questions`} value={q} onChange={(e) => { setQ(e.target.value); setPage(0); }} />
          <span className="text-sm text-muted-foreground">{(list?.total ?? 0).toLocaleString("en-NG")} questions</span>
        </div>
        {list?.batches.length ? (
          <div className="flex flex-wrap gap-2 text-xs">
            <span className="text-muted-foreground">Recent files:</span>
            {list.batches.map((b) => (
              <span key={b.batch} className="inline-flex items-center gap-1 rounded-full border px-2 py-1">
                {b.batch} ({b.n})
                <button type="button" className="font-bold text-error" disabled={pending}
                  onClick={() => { if (confirm(`Remove all ${b.n} questions from "${b.batch}"?`)) act(() => undoGzBatch(b.batch)); }}>Undo</button>
              </span>
            ))}
          </div>
        ) : null}
        {list && list.rows.length ? (
          <ul className="divide-y rounded-xl border">
            {list.rows.map((r) => (
              <li key={r.id} className="flex flex-wrap items-start gap-3 p-3">
                <div className="min-w-0 flex-1 text-sm">
                  <MathText text={r.body} />
                  <p className="mt-1 text-xs text-muted-foreground">
                    {Object.entries(r.options).map(([o, v]) => (o === r.answer ? `✓ ${o}. ${v}` : `${o}. ${v}`)).join("   ")} · {r.difficulty}
                  </p>
                </div>
                <Pill tone={r.difficulty === "hard" ? "error" : r.difficulty === "easy" ? "ok" : "info"}>{r.difficulty}</Pill>
                <Pill tone="neutral">{r.games?.length ? r.games.map((g) => GAME_NAMES[g] ?? g).join(", ") : "All quiz games"}</Pill>
                <Pill tone={r.active ? "ok" : "neutral"}>{r.active ? "Live" : "Hidden"}</Pill>
                <Button size="sm" variant="outline" disabled={pending} onClick={() => act(() => setGzQuestion(r.id, !r.active))}>{r.active ? "Hide" : "Show"}</Button>
                <Button size="sm" variant="ghost" disabled={pending} onClick={() => { if (confirm("Delete this question?")) act(() => deleteGzQuestion(r.id)); }}>Delete</Button>
              </li>
            ))}
          </ul>
        ) : list ? (
          <EmptyState title={q ? "No questions match" : `No SolutionTee questions for ${name(subject)} yet`}>
            Download the template, fill it in Excel or Google Sheets, save as CSV and add it here.
          </EmptyState>
        ) : null}
        {list && list.total > 50 ? (
          <div className="flex items-center justify-end gap-2">
            <Button size="sm" variant="outline" disabled={page === 0} onClick={() => setPage(page - 1)}>Previous</Button>
            <span className="text-sm">Page {page + 1} of {Math.ceil(list.total / 50)}</span>
            <Button size="sm" variant="outline" disabled={(page + 1) * 50 >= list.total} onClick={() => setPage(page + 1)}>Next</Button>
          </div>
        ) : null}
      </div>
    </Panel>
  );
}
