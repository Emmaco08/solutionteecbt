import { parseCsv } from "@solutiontee/shared/csv";

// The CSV checks for Admin → Games (Word War words, Memory Flash cards, Comprehension Clash passages). A plain module so
// it can be tested without a browser; the server actions check every row again.

export type Issue = { row: number; message: string };
export type Subject = { id: number; name: string; code?: string };
export const norm = (h: string) => h.toLowerCase().replace(/[^a-z0-9]/g, "");

/** Finds the file's column for each of our names (any order, any case, a few common spellings). */
export function columns(headers: string[], want: Record<string, string[]>) {
  return Object.fromEntries(Object.entries(want).map(([k, names]) => [k, headers.find((h) => names.includes(norm(h)))])) as Record<string, string | undefined>;
}

export type Checked<T> = { rows: T[]; issues: Issue[]; summary?: string };

export type Difficulty = "easy" | "medium" | "hard";
export type WordRow = { kind: "synonym" | "antonym" | "spelling"; word: string; answer: string; wrong: string[]; difficulty: Difficulty };

/** "easy" / "medium" / "hard" (also 1–3, e, m, h); anything else or empty is medium. */
export function readDifficulty(v: string | undefined): Difficulty {
  const d = (v ?? "").trim().toLowerCase();
  if (d === "easy" || d === "e" || d === "1") return "easy";
  if (d === "hard" || d === "h" || d === "3") return "hard";
  return "medium";
}

export function checkWordsCsv(text: string): Checked<WordRow> {
  const p = parseCsv(text);
  const c = columns(p.headers, {
    kind: ["kind", "type"], word: ["word"], answer: ["answer", "rightanswer", "correct"],
    w1: ["wrong1", "wronganswer1", "option2"], w2: ["wrong2", "wronganswer2", "option3"], w3: ["wrong3", "wronganswer3", "option4"],
    difficulty: ["difficulty", "level"],
  });
  const issues: Issue[] = [...p.parseErrors];
  for (const k of ["kind", "answer", "w1", "w2", "w3"]) if (!c[k]) issues.push({ row: 1, message: `Missing column: ${k.startsWith("w") ? `wrong_${k[1]}` : k}` });
  if (issues.some((i) => i.row === 1)) return { rows: [], issues };
  const rows: WordRow[] = [];
  p.records.forEach((r, i) => {
    const line = i + 2;
    const raw = (r[c.kind!] ?? "").trim().toLowerCase();
    const kind = (raw.startsWith("syn") || raw === "same" ? "synonym" : raw.startsWith("ant") || raw === "opposite" ? "antonym" : raw.startsWith("spell") ? "spelling" : "") as WordRow["kind"] | "";
    const word = (c.word ? r[c.word] ?? "" : "").trim();
    const answer = (r[c.answer!] ?? "").trim();
    const wrong = [r[c.w1!], r[c.w2!], r[c.w3!]].map((x) => (x ?? "").trim());
    if (!raw && !answer) return;
    if (!kind) return void issues.push({ row: line, message: `Type must be synonym, antonym or spelling (got "${raw}")` });
    if (kind !== "spelling" && !word) return void issues.push({ row: line, message: "Add the word" });
    if (!answer || wrong.some((w) => !w)) return void issues.push({ row: line, message: "Add the right answer and 3 wrong answers" });
    if ([word, answer, ...wrong].some((x) => x.length > 40)) return void issues.push({ row: line, message: "Keep each word under 40 letters" });
    if (new Set([answer, ...wrong].map((x) => x.toLowerCase())).size < 4) return void issues.push({ row: line, message: "The 4 options must all be different" });
    rows.push({ kind, word, answer, wrong, difficulty: readDifficulty(c.difficulty ? r[c.difficulty] : undefined) });
  });
  return { rows, issues };
}

export type CardRow = { subject_id: number; front: string; back: string; difficulty: Difficulty };

export function checkCardsCsv(text: string, subjects: Subject[]): Checked<CardRow> {
  const p = parseCsv(text);
  const c = columns(p.headers, { subject: ["subject", "subjectname", "subjectcode"], front: ["front", "term", "side1"], back: ["back", "meaning", "side2"], difficulty: ["difficulty", "level"] });
  const issues: Issue[] = [...p.parseErrors];
  for (const k of ["subject", "front", "back"]) if (!c[k]) issues.push({ row: 1, message: `Missing column: ${k}` });
  if (issues.some((i) => i.row === 1)) return { rows: [], issues };
  const find = (s: string) => subjects.find((x) => norm(x.name) === norm(s) || (x.code && norm(x.code) === norm(s)));
  const rows: CardRow[] = [];
  p.records.forEach((r, i) => {
    const line = i + 2;
    const s = (r[c.subject!] ?? "").trim(), front = (r[c.front!] ?? "").trim(), back = (r[c.back!] ?? "").trim();
    if (!s && !front && !back) return;
    const sub = find(s);
    if (!sub) return void issues.push({ row: line, message: `Unknown subject "${s}" (use the subject name, e.g. Chemistry)` });
    if (!front || !back) return void issues.push({ row: line, message: "Add both sides" });
    if (front.length > 30 || back.length > 30) return void issues.push({ row: line, message: "Keep each side to 30 letters" });
    if (front.toLowerCase() === back.toLowerCase()) return void issues.push({ row: line, message: "The two sides must be different" });
    rows.push({ subject_id: sub.id, front, back, difficulty: readDifficulty(c.difficulty ? r[c.difficulty] : undefined) });
  });
  return { rows, issues };
}

export type PQ = { kind: "main" | "intent" | "vocab" | "inference" | "detail" | "other"; body: string; options: Record<string, string>; answer: string };
export type PassageRow = { title: string; body: string; difficulty: "easy" | "medium" | "hard"; questions: PQ[] };
const KINDS: Record<string, PQ["kind"]> = {
  main: "main", mainidea: "main", theme: "main", title: "main",
  intent: "intent", purpose: "intent", writerspurpose: "intent", tone: "intent", attitude: "intent",
  vocab: "vocab", vocabulary: "vocab", wordincontext: "vocab", meaning: "vocab",
  inference: "inference", deduction: "inference", infer: "inference",
  detail: "detail", fact: "detail",
};
export const KIND_NAMES: Record<string, string> = { main: "Main idea", intent: "Writer's purpose", vocab: "Word in context", inference: "Deduction", detail: "Detail", other: "Other" };

/** One row per question; rows with the same passage_title make one passage (the passage text can be on the first row only). */
export function checkPassagesCsv(text: string): Checked<PassageRow> {
  const p = parseCsv(text);
  const c = columns(p.headers, {
    title: ["passagetitle", "title", "passage_title"], body: ["passage", "passagetext", "text"], difficulty: ["difficulty", "level"],
    type: ["type", "kind", "questiontype"], question: ["question", "questiontext"],
    A: ["optiona", "a"], B: ["optionb", "b"], C: ["optionc", "c"], D: ["optiond", "d"], E: ["optione", "e"], answer: ["answer", "correct", "key"],
  });
  const issues: Issue[] = [...p.parseErrors];
  for (const k of ["title", "body", "question", "A", "B", "answer"]) if (!c[k]) issues.push({ row: 1, message: `Missing column: ${k === "title" ? "passage_title" : k === "body" ? "passage" : k.length === 1 ? `option_${k.toLowerCase()}` : k}` });
  if (issues.some((i) => i.row === 1)) return { rows: [], issues };
  const map = new Map<string, PassageRow & { first: number }>();
  p.records.forEach((r, i) => {
    const line = i + 2;
    const title = (r[c.title!] ?? "").trim();
    const body = (r[c.body!] ?? "").trim();
    const question = (r[c.question!] ?? "").trim();
    if (!title && !body && !question) return;
    if (!title) return void issues.push({ row: line, message: "Add passage_title (it groups the questions of one passage)" });
    const key = title.toLowerCase();
    let ps = map.get(key);
    if (!ps) {
      const d = (c.difficulty ? r[c.difficulty] ?? "" : "").trim().toLowerCase();
      ps = { title, body, difficulty: (["easy", "medium", "hard"].includes(d) ? d : "medium") as PassageRow["difficulty"], questions: [], first: line };
      map.set(key, ps);
    } else if (!ps.body && body) ps.body = body;
    if (!question) return;
    const options: Record<string, string> = {};
    for (const k of ["A", "B", "C", "D", "E"]) {
      const v = c[k] ? (r[c[k]!] ?? "").trim() : "";
      if (v) options[k] = v;
    }
    let answer = (r[c.answer!] ?? "").trim();
    if (!/^[A-Ea-e]$/.test(answer)) answer = Object.entries(options).find(([, v]) => v.toLowerCase() === answer.toLowerCase())?.[0] ?? answer;
    answer = answer.toUpperCase();
    if (Object.keys(options).length < 2) return void issues.push({ row: line, message: "Give at least options A and B" });
    if (!options[answer]) return void issues.push({ row: line, message: `The answer "${(r[c.answer!] ?? "").trim()}" is not one of the filled options` });
    const kind = KINDS[norm(c.type ? r[c.type] ?? "" : "")] ?? "other";
    ps.questions.push({ kind, body: question, options, answer });
  });
  const rows: PassageRow[] = [];
  for (const ps of map.values()) {
    const { first, ...x } = ps;
    if (x.body.length < 200) { issues.push({ row: first, message: `"${x.title}": the passage is missing or under 200 characters` }); continue; }
    if (x.body.length > 6000) { issues.push({ row: first, message: `"${x.title}": the passage is over 6,000 characters` }); continue; }
    if (x.questions.length < 3) { issues.push({ row: first, message: `"${x.title}": needs at least 3 questions (has ${x.questions.length})` }); continue; }
    if (x.questions.length > 10) { issues.push({ row: first, message: `"${x.title}": at most 10 questions (the first 10 are kept)` }); x.questions = x.questions.slice(0, 10); }
    rows.push(x);
  }
  const q = rows.reduce((n, r) => n + r.questions.length, 0);
  return { rows, issues, summary: `${rows.length} passages · ${q} questions ready` };
}

