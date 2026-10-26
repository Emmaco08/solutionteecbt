/**
 * CSV import for questions (SPEC §12). Used by the admin before anything is sent to the server,
 * so editors see every problem row by row. The server re-checks in public.import_questions().
 */
import Papa from 'papaparse';

export const CSV_COLUMNS = [
  'exam', 'year', 'subject', 'number', 'passage_id', 'question',
  'option_a', 'option_b', 'option_c', 'option_d', 'option_e',
  'answer', 'explanation', 'topic', 'difficulty', 'image_url',
] as const;
export type CsvColumn = (typeof CSV_COLUMNS)[number];
export const REQUIRED_COLUMNS: CsvColumn[] = ['exam', 'year', 'subject', 'question', 'option_a', 'option_b', 'option_c', 'option_d', 'answer'];
export const MAX_ROWS = 5000;

export type ImportRow = Record<CsvColumn, string>;
export type Issue = { row: number; column?: CsvColumn; message: string };
export type ValidationResult = {
  rows: ImportRow[];
  /** Rows (1-based, as the editor sees them in a spreadsheet, header = row 1) that have errors. */
  badRows: Set<number>;
  errors: Issue[];
  warnings: Issue[];
};
export type Catalogue = {
  exams: string[];
  /** Subject codes and names, any case. */
  subjects: string[];
  minYear?: number;
  maxYear?: number;
};

/** Downloadable template with one worked example (LaTeX allowed). */
export function csvTemplate(): string {
  const example: Partial<ImportRow> = {
    exam: 'JAMB', year: '2001', subject: 'mth', number: '7', question: 'If $\\log_{10} 2 = 0.3010$, evaluate $\\log_{10} 4.5$',
    option_a: '0.6532', option_b: '0.6990', option_c: '0.6532 + 0.01', option_d: '0.9542', answer: 'A',
    explanation: '$\\log 4.5 = \\log 9 - \\log 2 = 2(0.4771) - 0.3010 = 0.6532$', topic: 'Logarithms', difficulty: 'medium',
  };
  return Papa.unparse({ fields: [...CSV_COLUMNS], data: [CSV_COLUMNS.map((c) => example[c] ?? '')] });
}

/** Header aliases editors commonly use, mapped to our columns. The admin can also map by hand. */
const ALIASES: Record<string, CsvColumn> = {
  exam_body: 'exam', body: 'exam', session: 'year', q: 'question', question_text: 'question', stem: 'question',
  a: 'option_a', b: 'option_b', c: 'option_c', d: 'option_d', e: 'option_e', optiona: 'option_a', optionb: 'option_b',
  optionc: 'option_c', optiond: 'option_d', optione: 'option_e', correct: 'answer', correct_answer: 'answer', key: 'answer',
  solution: 'explanation', level: 'difficulty', image: 'image_url', image_key: 'image_url', no: 'number', question_number: 'number',
  passage: 'passage_id',
};
const norm = (h: string) => h.trim().toLowerCase().replace(/[\s-]+/g, '_').replace(/^﻿/, '');

/** Suggest a mapping from the file's headers to our columns. */
export function suggestMapping(headers: string[]): Partial<Record<CsvColumn, string>> {
  const out: Partial<Record<CsvColumn, string>> = {};
  for (const h of headers) {
    const n = norm(h);
    const col = (CSV_COLUMNS as readonly string[]).includes(n) ? (n as CsvColumn) : ALIASES[n] ?? ALIASES[n.replace(/_/g, '')];
    if (col && !out[col]) out[col] = h;
  }
  return out;
}

export type Parsed = { headers: string[]; records: Record<string, string>[]; parseErrors: Issue[] };

/** Parse CSV text (UTF-8, quoted fields, commas and new lines inside quotes). */
export function parseCsv(text: string): Parsed {
  const res = Papa.parse<Record<string, string>>(text.replace(/^﻿/, ''), {
    header: true, skipEmptyLines: 'greedy', transform: (v) => v,
  });
  const parseErrors: Issue[] = res.errors.map((e) => ({ row: (e.row ?? 0) + 2, message: `File problem: ${e.message}` }));
  return { headers: res.meta.fields ?? [], records: res.data, parseErrors };
}

/** Apply a header mapping to parsed records. */
export function applyMapping(records: Record<string, string>[], mapping: Partial<Record<CsvColumn, string>>): ImportRow[] {
  return records.map((r) => {
    const row = {} as ImportRow;
    for (const c of CSV_COLUMNS) {
      const src = mapping[c];
      row[c] = src === undefined ? '' : String(r[src] ?? '').trim();
    }
    row.exam = row.exam.toUpperCase();
    row.answer = row.answer.toUpperCase();
    row.difficulty = row.difficulty.toLowerCase();
    return row;
  });
}

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const IMAGE_KEY = /^[a-z0-9][a-z0-9/_.-]{2,200}\.(webp|png|jpe?g|svg)$/i;
const OPTION_COLS = ['option_a', 'option_b', 'option_c', 'option_d', 'option_e'] as const;

/** Problems with LaTeX that would show as broken maths: odd number of $ or unbalanced braces. */
export function latexProblem(text: string): string | null {
  if (!text) return null;
  const withoutEscaped = text.replace(/\\\$/g, '');
  const dollars = (withoutEscaped.match(/\$/g) ?? []).length;
  if (dollars % 2 !== 0) return 'has an odd number of $ signs (maths must be inside $...$ or $$...$$)';
  let depth = 0;
  for (let i = 0; i < withoutEscaped.length; i++) {
    const ch = withoutEscaped[i];
    if (ch === '\\') { i++; continue; }
    if (ch === '{') depth++;
    if (ch === '}') depth--;
    if (depth < 0) return 'has a } without a matching {';
  }
  return depth === 0 ? null : 'has a { without a matching }';
}

const hashText = (s: string) => s.trim().toLowerCase().replace(/\s+/g, ' ');

/** Validate mapped rows. Never throws: every problem becomes an Issue the editor can fix. */
export function validateRows(rows: ImportRow[], cat: Catalogue): ValidationResult {
  const errors: Issue[] = [];
  const warnings: Issue[] = [];
  const badRows = new Set<number>();
  const exams = new Set(cat.exams.map((e) => e.toUpperCase()));
  const subjects = new Set(cat.subjects.map((s) => s.toLowerCase()));
  const minYear = cat.minYear ?? 1978;
  const maxYear = cat.maxYear ?? new Date().getFullYear() + 1;
  const seen = new Map<string, number>();
  const err = (row: number, column: CsvColumn | undefined, message: string) => { errors.push({ row, column, message }); badRows.add(row); };

  if (rows.length === 0) errors.push({ row: 0, message: 'The file has no question rows.' });
  if (rows.length > MAX_ROWS) errors.push({ row: 0, message: `The file has ${rows.length} rows. The limit is ${MAX_ROWS} per import; split the file.` });

  rows.forEach((r, i) => {
    const row = i + 2; // header is row 1
    for (const c of REQUIRED_COLUMNS) if (!r[c]) err(row, c, `${c} is empty`);

    if (r.exam && !exams.has(r.exam)) err(row, 'exam', `exam "${r.exam}" is not set up (use ${[...exams].join(', ')})`);
    if (r.subject && !subjects.has(r.subject.toLowerCase())) err(row, 'subject', `subject "${r.subject}" is not set up`);

    if (r.year) {
      const y = Number(r.year);
      if (!/^\d{4}$/.test(r.year) || y < minYear || y > maxYear) err(row, 'year', `year "${r.year}" must be a 4-digit year between ${minYear} and ${maxYear}`);
    }
    if (r.number && (!/^\d{1,3}$/.test(r.number) || Number(r.number) < 1)) err(row, 'number', `number "${r.number}" must be 1 to 500`);

    if (r.answer) {
      if (!/^[A-E]$/.test(r.answer)) err(row, 'answer', `answer "${r.answer}" must be one letter from A to E`);
      else {
        const col = `option_${r.answer.toLowerCase()}` as CsvColumn;
        if (!r[col]) err(row, 'answer', `answer is ${r.answer} but option ${r.answer} is empty`);
      }
    }

    if (r.difficulty && !['easy', 'medium', 'hard'].includes(r.difficulty)) err(row, 'difficulty', `difficulty "${r.difficulty}" must be easy, medium or hard`);
    if (r.passage_id && !UUID.test(r.passage_id)) err(row, 'passage_id', 'passage_id must be the passage ID copied from the admin');
    if (r.image_url && !IMAGE_KEY.test(r.image_url)) err(row, 'image_url', 'image_url must be an uploaded image key like q/jamb/2001/mth/7.webp');
    if (r.question.length > 20000) err(row, 'question', 'question is longer than 20,000 characters');
    if (r.explanation.length > 40000) err(row, 'explanation', 'explanation is longer than 40,000 characters');
    if (r.topic.length > 120) err(row, 'topic', 'topic is longer than 120 characters');

    for (const c of ['question', 'explanation', ...OPTION_COLS] as CsvColumn[]) {
      const p = latexProblem(r[c]);
      if (p) err(row, c, `${c} ${p}`);
    }

    const opts = OPTION_COLS.map((c) => r[c]).filter(Boolean).map(hashText);
    if (new Set(opts).size !== opts.length) warnings.push({ row, message: 'two options have the same text' });
    if (!r.explanation) warnings.push({ row, column: 'explanation', message: 'no explanation (students see only the answer)' });
    if (!r.topic) warnings.push({ row, column: 'topic', message: 'no topic (weak-topic reports will skip it)' });

    if (r.question) {
      const key = `${r.exam}|${r.subject.toLowerCase()}|${hashText(r.question)}`;
      const first = seen.get(key);
      if (first) warnings.push({ row, column: 'question', message: `same question as row ${first} (possible duplicate)` });
      else seen.set(key, row);
    }
  });

  return { rows, badRows, errors, warnings };
}

/** Parse + map + validate in one call (handy for tests and the dry run). */
export function checkCsv(text: string, cat: Catalogue, mapping?: Partial<Record<CsvColumn, string>>) {
  const parsed = parseCsv(text);
  const map = mapping ?? suggestMapping(parsed.headers);
  const missing = REQUIRED_COLUMNS.filter((c) => !map[c]);
  const rows = applyMapping(parsed.records, map);
  const result = validateRows(rows, cat);
  result.errors.unshift(...parsed.parseErrors, ...missing.map((c) => ({ row: 1, column: c, message: `no column for "${c}" (map it or add it to the file)` })));
  return { ...result, headers: parsed.headers, mapping: map, missing };
}
