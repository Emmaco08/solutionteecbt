"use client";
import { useMemo, useRef, useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { CheckCircle, DownloadSimple, FileCsv, SpinnerGap, UploadSimple, WarningCircle, XCircle } from "@phosphor-icons/react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { MathText } from "@/components/admin/math-text";
import { cn } from "@/lib/utils";
import {
  CSV_COLUMNS, REQUIRED_COLUMNS, MAX_ROWS, applyMapping, csvTemplate, parseCsv, suggestMapping, validateRows,
  type CsvColumn, type Parsed,
} from "@solutiontee/shared/csv";
import { runImport, type ImportSummary } from "./actions";

type Mapping = Partial<Record<CsvColumn, string>>;

export function Importer({ exams, subjects, subjectHint }: { exams: string[]; subjects: string[]; subjectHint: string }) {
  const router = useRouter();
  const [file, setFile] = useState<{ name: string; parsed: Parsed } | null>(null);
  const [mapping, setMapping] = useState<Mapping>({});
  const [onlyProblems, setOnlyProblems] = useState(false);
  const [dry, setDry] = useState<ImportSummary | null>(null);
  const [pending, start] = useTransition();
  const [drag, setDrag] = useState(false);
  const input = useRef<HTMLInputElement>(null);

  const rows = useMemo(() => (file ? applyMapping(file.parsed.records, mapping) : []), [file, mapping]);
  const result = useMemo(() => (file ? validateRows(rows, { exams, subjects }) : null), [file, rows, exams, subjects]);
  const missing = REQUIRED_COLUMNS.filter((c) => !mapping[c]);
  const errors = [...(file?.parsed.parseErrors ?? []), ...(result?.errors ?? [])];
  const canImport = Boolean(file && result && !missing.length && !errors.length && rows.length);
  const step = !file ? 1 : missing.length ? 2 : errors.length || !dry ? 3 : 4;

  async function load(f: File) {
    if (!/\.csv$/i.test(f.name) && f.type !== "text/csv") return toast.error("Choose a .csv file (save Excel sheets as CSV UTF-8).");
    if (f.size > 8 * 1024 * 1024) return toast.error("The file is over 8 MB. Split it into smaller files.");
    const parsed = parseCsv(await f.text());
    if (!parsed.headers.length) return toast.error("The file looks empty.");
    setFile({ name: f.name, parsed });
    setMapping(suggestMapping(parsed.headers));
    setDry(null);
  }
  const downloadTemplate = () => {
    const url = URL.createObjectURL(new Blob(["﻿" + csvTemplate()], { type: "text/csv;charset=utf-8" }));
    Object.assign(document.createElement("a"), { href: url, download: "solutiontee-questions-template.csv" }).click();
    URL.revokeObjectURL(url);
  };
  const go = (dryRun: boolean) => start(async () => {
    const r = await runImport(file!.name, rows, dryRun);
    if (!r.ok) return void toast.error(r.error);
    if (dryRun) { setDry(r.data!); toast.success("Check passed. Nothing was saved yet."); }
    else {
      toast.success(`${r.data!.inserted} questions imported as drafts.`);
      setFile(null); setDry(null); router.refresh();
    }
  });

  const issuesByRow = useMemo(() => {
    const m = new Map<number, { errors: string[]; warnings: string[] }>();
    for (const e of result?.errors ?? []) { const x = m.get(e.row) ?? { errors: [], warnings: [] }; x.errors.push(e.message); m.set(e.row, x); }
    for (const w of result?.warnings ?? []) { const x = m.get(w.row) ?? { errors: [], warnings: [] }; x.warnings.push(w.message); m.set(w.row, x); }
    return m;
  }, [result]);
  const shown = rows.map((r, i) => ({ r, row: i + 2 })).filter(({ row }) => !onlyProblems || issuesByRow.has(row)).slice(0, 200);

  return (
    <div className="space-y-4">
      <ol className="grid gap-2 sm:grid-cols-4">
        {["Upload file", "Match columns", "Check rows", "Import"].map((label, i) => (
          <li key={label} className={cn("flex items-center gap-2.5 rounded-xl border bg-card px-3.5 py-3 text-[13px] font-bold text-muted-foreground",
            step === i + 1 && "border-blue text-foreground ring-3 ring-info-soft", step > i + 1 && "text-foreground")}>
            <span className={cn("grid size-[26px] place-items-center rounded-full bg-muted text-xs", step === i + 1 && "bg-blue text-white", step > i + 1 && "bg-success text-white")}>
              {step > i + 1 ? <CheckCircle size={16} weight="bold" /> : i + 1}
            </span>{label}
          </li>
        ))}
      </ol>

      {!file ? (
        <div
          onDragOver={(e) => { e.preventDefault(); setDrag(true); }} onDragLeave={() => setDrag(false)}
          onDrop={(e) => { e.preventDefault(); setDrag(false); const f = e.dataTransfer.files[0]; if (f) load(f); }}
          className={cn("flex flex-col items-center gap-4 rounded-2xl border-2 border-dashed bg-card px-6 py-12 text-center sm:flex-row sm:text-left", drag && "border-blue bg-info-soft")}
        >
          <span className="grid size-14 flex-none place-items-center rounded-2xl bg-info-soft text-on-info-soft"><FileCsv size={28} /></span>
          <div className="grow">
            <b className="block">Drop a CSV file here, or choose one</b>
            <p className="mt-1 text-sm text-muted-foreground">UTF-8, up to {MAX_ROWS.toLocaleString()} rows. Maths can be written as LaTeX between $ signs. Not sure about the columns? Download the template.</p>
          </div>
          <div className="flex gap-2">
            <Button variant="outline" onClick={downloadTemplate}><DownloadSimple size={18} /> Template</Button>
            <Button onClick={() => input.current?.click()}><UploadSimple size={18} /> Choose file</Button>
          </div>
          <input ref={input} type="file" accept=".csv,text/csv" className="hidden" onChange={(e) => { const f = e.target.files?.[0]; if (f) load(f); e.target.value = ""; }} />
        </div>
      ) : (
        <>
          <section className="rounded-2xl border bg-card p-5">
            <div className="flex flex-wrap items-center justify-between gap-3">
              <div><b>{file.name}</b><p className="text-sm text-muted-foreground">{rows.length.toLocaleString()} rows · {file.parsed.headers.length} columns</p></div>
              <Button variant="ghost" onClick={() => { setFile(null); setDry(null); }}>Choose another file</Button>
            </div>
            <div className="mt-4 grid gap-2 sm:grid-cols-2 lg:grid-cols-4">
              {CSV_COLUMNS.map((c) => (
                <label key={c} className="flex items-center gap-2 text-sm">
                  <span className={cn("w-24 flex-none font-bold", REQUIRED_COLUMNS.includes(c) && !mapping[c] && "text-error")}>
                    {c}{REQUIRED_COLUMNS.includes(c) ? " *" : ""}
                  </span>
                  <select value={mapping[c] ?? ""} onChange={(e) => { setMapping((m) => ({ ...m, [c]: e.target.value || undefined })); setDry(null); }}
                    className="h-9 min-w-0 grow rounded-lg border border-input bg-card px-2 text-sm">
                    <option value="">Not in file</option>
                    {file.parsed.headers.map((h) => <option key={h} value={h}>{h}</option>)}
                  </select>
                </label>
              ))}
            </div>
            <p className="mt-3 text-xs text-muted-foreground">Optional <b>section</b> (Use of English only): comprehension, cloze, novel, interpretation, antonyms, synonyms, grammar or oral. Leave it empty and the question is sorted automatically.</p>
            <p className="mt-1 text-xs text-muted-foreground">Exams: {exams.join(", ")}. Subjects (code or name): {subjectHint}.</p>
          </section>

          <section className="flex flex-wrap items-center gap-3 rounded-2xl border bg-card p-4">
            <Stat tone={errors.length || missing.length ? "error" : "ok"} label={missing.length ? `${missing.length} required column(s) not matched` : errors.length ? `${result?.badRows.size ?? 0} row(s) with problems` : "No problems"} />
            <Stat tone="warn" label={`${result?.warnings.length ?? 0} warning(s)`} />
            {dry ? <Stat tone="ok" label={`Server check: ${dry.inserted} ready · ${dry.possible_duplicates} possible duplicate(s) · ${dry.new_years} new year(s)`} /> : null}
            <span className="grow" />
            <label className="flex items-center gap-2 text-sm"><input type="checkbox" checked={onlyProblems} onChange={(e) => setOnlyProblems(e.target.checked)} /> Only rows with problems</label>
            <Button variant="outline" disabled={!canImport || pending} onClick={() => go(true)}>
              {pending && !dry ? <SpinnerGap size={16} className="animate-spin" /> : null} Check on server
            </Button>
            <Button disabled={!canImport || !dry || pending} onClick={() => go(false)} title={!dry ? "Run the server check first" : undefined}>
              {pending && dry ? <SpinnerGap size={16} className="animate-spin" /> : null} Import {rows.length.toLocaleString()} questions
            </Button>
          </section>

          {file.parsed.parseErrors.length ? (
            <div className="rounded-2xl bg-error-soft p-4 text-sm text-on-error-soft">{file.parsed.parseErrors.slice(0, 5).map((e, i) => <p key={i}>Row {e.row}: {e.message}</p>)}</div>
          ) : null}

          <div className="overflow-hidden rounded-2xl border bg-card">
            <div className="max-h-[560px] overflow-auto">
              <table className="w-full text-sm">
                <thead className="sticky top-0 bg-surface-alt text-left text-[11px] uppercase tracking-[0.6px] text-subtle">
                  <tr><th className="px-4 py-2.5">Row</th><th className="px-3 py-2.5">Exam · year · subject</th><th className="px-3 py-2.5">Question (preview)</th><th className="px-3 py-2.5">Ans</th><th className="px-3 py-2.5">Problems</th></tr>
                </thead>
                <tbody className="divide-y">
                  {shown.map(({ r, row }) => {
                    const iss = issuesByRow.get(row);
                    return (
                      <tr key={row} className={cn(iss?.errors.length ? "bg-error-soft/60" : iss?.warnings.length ? "bg-warning-soft/40" : "")}>
                        <td className="tnum px-4 py-2.5 align-top text-muted-foreground">{row}</td>
                        <td className="whitespace-nowrap px-3 py-2.5 align-top"><b>{r.exam || "?"}</b> {r.year} · {r.subject}</td>
                        <td className="max-w-[460px] px-3 py-2.5 align-top"><span className="line-clamp-2"><MathText text={r.question} /></span></td>
                        <td className="px-3 py-2.5 align-top font-bold">{r.answer}</td>
                        <td className="px-3 py-2.5 align-top text-xs">
                          {iss?.errors.map((m) => <p key={m} className="flex gap-1 font-bold text-error"><XCircle size={14} className="mt-px flex-none" />{m}</p>)}
                          {iss?.warnings.map((m) => <p key={m} className="flex gap-1 text-on-warning-soft"><WarningCircle size={14} className="mt-px flex-none" />{m}</p>)}
                          {!iss ? <span className="text-success">OK</span> : null}
                        </td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            </div>
            {rows.length > 200 ? <p className="border-t px-4 py-2 text-xs text-muted-foreground">Showing the first 200 rows{onlyProblems ? " with problems" : ""}. All rows are checked.</p> : null}
          </div>
        </>
      )}
    </div>
  );
}

function Stat({ tone, label }: { tone: "ok" | "warn" | "error"; label: string }) {
  const Icon = tone === "ok" ? CheckCircle : tone === "warn" ? WarningCircle : XCircle;
  return (
    <span className={cn("inline-flex items-center gap-1.5 rounded-full px-3 py-1.5 text-sm font-bold",
      tone === "ok" && "bg-success-soft text-on-success-soft", tone === "warn" && "bg-warning-soft text-on-warning-soft", tone === "error" && "bg-error-soft text-on-error-soft")}>
      <Icon size={16} weight="fill" />{label}
    </span>
  );
}
