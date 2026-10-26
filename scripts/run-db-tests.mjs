// Runs supabase/tests/*.test.sql against the dev database and prints pass/fail.
// Each file runs in one transaction that ends with ROLLBACK, so nothing is kept.
// Needs SUPABASE_DB_URL in supabase/.env (Session pooler connection string). Never commit that file.
import { readFileSync, readdirSync, existsSync } from 'node:fs';
import { join } from 'node:path';
import pg from 'pg';

const envFile = join('supabase', '.env');
if (existsSync(envFile)) {
  for (const line of readFileSync(envFile, 'utf8').split(/\r?\n/)) {
    const m = line.match(/^\s*([A-Z0-9_]+)\s*=\s*(.*)\s*$/);
    if (m && !process.env[m[1]]) process.env[m[1]] = m[2].replace(/^["']|["']$/g, '');
  }
}
const url = process.env.SUPABASE_DB_URL;
if (!url) {
  console.error('SUPABASE_DB_URL is not set. Copy supabase/.env.example to supabase/.env and fill it in (docs/SETUP.md §7.3).');
  process.exit(2);
}
if (/prod/i.test(url) && !process.env.ALLOW_PROD_TESTS) {
  console.error('Refusing to run tests against what looks like a production database.');
  process.exit(2);
}

const dir = join('supabase', 'tests');
const files = readdirSync(dir).filter((f) => f.endsWith('.test.sql')).sort();
const client = new pg.Client({ connectionString: url, ssl: { rejectUnauthorized: false } });
await client.connect();
let failed = 0;
let total = 0;
try {
  for (const f of files) {
    console.log(`\n# ${f}`);
    const res = await client.query(readFileSync(join(dir, f), 'utf8'));
    const all = Array.isArray(res) ? res : [res];
    const rows = all.filter((r) => r.fields?.some((x) => x.name === 'ok')).flatMap((r) => r.rows);
    for (const r of rows) {
      total++;
      if (!r.ok) failed++;
      console.log(`${r.ok ? 'ok    ' : 'NOT OK'} ${String(r.n).padStart(3)} ${r.name}${r.ok ? '' : `  ->  ${r.detail}`}`);
    }
  }
} catch (e) {
  console.error('\nTest file crashed:', e.message);
  try { await client.query('rollback'); } catch {}
  failed++;
} finally {
  await client.end();
}
console.log(`\n${total - Math.min(failed, total)}/${total} passed${failed ? `, ${failed} FAILED` : ''}`);
process.exit(failed ? 1 : 0);
