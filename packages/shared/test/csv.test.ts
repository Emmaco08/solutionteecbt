import { describe, expect, it } from 'vitest';
import { checkCsv, csvTemplate, latexProblem, parseCsv, suggestMapping, MAX_ROWS, CSV_COLUMNS } from '../src/csv/index';

const cat = { exams: ['JAMB', 'WAEC', 'NECO'], subjects: ['mth', 'eng', 'chm', 'Mathematics'], minYear: 1978, maxYear: 2027 };
const header = CSV_COLUMNS.join(',');
const line = (o: Partial<Record<(typeof CSV_COLUMNS)[number], string>>) =>
  CSV_COLUMNS.map((c) => {
    const v = o[c] ?? '';
    return /[",\n]/.test(v) ? `"${v.replace(/"/g, '""')}"` : v;
  }).join(',');
const good = { exam: 'JAMB', year: '2001', subject: 'mth', question: 'What is $2+2$?', option_a: '3', option_b: '4', option_c: '5', option_d: '6', answer: 'B', explanation: 'Add.', topic: 'Arithmetic', difficulty: 'easy' };

describe('template', () => {
  it('round-trips through the checker with no errors', () => {
    const r = checkCsv(csvTemplate(), cat);
    expect(r.errors).toEqual([]);
    expect(r.rows).toHaveLength(1);
  });
});

describe('parsing', () => {
  it('handles quoted commas, quotes and new lines inside a field', () => {
    const csv = `${header}\n${line({ ...good, question: 'Which is right: "a, b"\nor c?' })}`;
    const r = checkCsv(csv, cat);
    expect(r.errors).toEqual([]);
    expect(r.rows[0]!.question).toBe('Which is right: "a, b"\nor c?');
  });

  it('strips a UTF-8 BOM and keeps naira signs and accents', () => {
    const csv = `﻿${header}\n${line({ ...good, question: 'A trader sells at ₦1,500. Café?' })}`;
    const r = checkCsv(csv, cat);
    expect(r.headers[0]).toBe('exam');
    expect(r.rows[0]!.question).toContain('₦1,500');
    expect(r.errors).toEqual([]);
  });

  it('skips blank lines', () => {
    expect(parseCsv(`${header}\n\n${line(good)}\n\n`).records).toHaveLength(1);
  });
});

describe('mapping', () => {
  it('maps common header names', () => {
    const m = suggestMapping(['Exam Body', 'Year', 'Subject', 'Question Text', 'A', 'B', 'C', 'D', 'Correct Answer', 'Solution']);
    expect(m).toMatchObject({ exam: 'Exam Body', question: 'Question Text', option_a: 'A', answer: 'Correct Answer', explanation: 'Solution' });
  });

  it('reports required columns that are missing', () => {
    const r = checkCsv('exam,year,subject\nJAMB,2001,mth', cat);
    expect(r.missing).toContain('question');
    expect(r.errors.some((e) => e.message.includes('no column for "answer"'))).toBe(true);
  });
});

describe('validation', () => {
  const one = (o: Record<string, string>) => checkCsv(`${header}\n${line({ ...good, ...o })}`, cat);

  it('accepts a good row', () => expect(one({}).errors).toEqual([]));
  it('normalises case of exam, answer and difficulty', () => {
    const r = one({ exam: 'jamb', answer: 'b', difficulty: 'EASY' });
    expect(r.errors).toEqual([]);
    expect(r.rows[0]).toMatchObject({ exam: 'JAMB', answer: 'B', difficulty: 'easy' });
  });
  it('accepts a subject by name', () => expect(one({ subject: 'mathematics' }).errors).toEqual([]));
  it('rejects an unknown exam', () => expect(one({ exam: 'GCE' }).errors[0]!.column).toBe('exam'));
  it('rejects an unknown subject', () => expect(one({ subject: 'xyz' }).errors[0]!.column).toBe('subject'));
  it('rejects a bad year', () => {
    expect(one({ year: '01' }).errors[0]!.column).toBe('year');
    expect(one({ year: '2099' }).errors[0]!.column).toBe('year');
  });
  it('rejects an answer that is not A to E', () => expect(one({ answer: 'F' }).errors[0]!.column).toBe('answer'));
  it('rejects answer E when option E is empty', () => expect(one({ answer: 'E' }).errors[0]!.message).toMatch(/option E is empty/));
  it('accepts answer E when option E is filled', () => expect(one({ answer: 'E', option_e: '7' }).errors).toEqual([]));
  it('requires options A to D', () => expect(one({ option_c: '' }).errors[0]!.column).toBe('option_c'));
  it('rejects a bad difficulty', () => expect(one({ difficulty: 'tough' }).errors[0]!.column).toBe('difficulty'));
  it('rejects a bad passage id and image key', () => {
    expect(one({ passage_id: '12' }).errors[0]!.column).toBe('passage_id');
    expect(one({ image_url: 'http://x.com/a.gif' }).errors[0]!.column).toBe('image_url');
    expect(one({ image_url: 'q/jamb/2001/mth/7.webp' }).errors).toEqual([]);
  });
  it('flags broken LaTeX', () => {
    expect(one({ question: 'Find $x^2' }).errors[0]!.message).toMatch(/odd number of \$/);
    expect(one({ explanation: '$\\frac{1}{2$' }).errors[0]!.message).toMatch(/\{ without/);
  });
  it('warns (does not block) on missing explanation/topic and duplicate options', () => {
    const r = one({ explanation: '', topic: '', option_b: '3' });
    expect(r.errors).toEqual([]);
    expect(r.warnings.map((w) => w.message).join(' ')).toMatch(/no explanation.*no topic|two options/);
    expect(r.warnings).toHaveLength(3);
  });
  it('warns about duplicate questions inside the file, ignoring case and spaces', () => {
    const r = checkCsv(`${header}\n${line(good)}\n${line({ ...good, question: '  what IS   $2+2$? ' })}`, cat);
    expect(r.warnings.some((w) => w.row === 3 && /row 2/.test(w.message))).toBe(true);
  });
  it('reports the spreadsheet row number (header is row 1)', () => {
    const r = checkCsv(`${header}\n${line(good)}\n${line({ ...good, answer: 'Z' })}`, cat);
    expect(r.errors[0]!.row).toBe(3);
    expect([...r.badRows]).toEqual([3]);
  });
  it('rejects an empty file and files over the row limit', () => {
    expect(checkCsv(header, cat).errors[0]!.message).toMatch(/no question rows/);
    const big = [header, ...Array.from({ length: MAX_ROWS + 1 }, (_, i) => line({ ...good, question: `Q${i} $x$` }))].join('\n');
    expect(checkCsv(big, cat).errors.some((e) => /limit is 5000/.test(e.message))).toBe(true);
  });
  it('validates 5,000 rows quickly', () => {
    const big = [header, ...Array.from({ length: MAX_ROWS }, (_, i) => line({ ...good, question: `Question ${i}: $x_${i}$` }))].join('\n');
    const t = performance.now();
    const r = checkCsv(big, cat);
    expect(r.errors).toEqual([]);
    expect(performance.now() - t).toBeLessThan(3000);
  });
});

describe('latexProblem', () => {
  it('ignores escaped dollar signs and escaped braces', () => {
    expect(latexProblem('It costs \\$5 and $\\{1,2\\}$')).toBeNull();
    expect(latexProblem('$$\\int_0^1 x\\,dx$$')).toBeNull();
  });
});
