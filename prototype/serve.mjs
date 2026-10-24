// Zero-dependency static server for the Phase 1 prototype.
// Serves only /prototype, /design and /brand from the repo root.
// Usage:  node prototype/serve.mjs  [port]   (default 5173)
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const PORT = Number(process.argv[2] || process.env.PORT || 5173);
const ALLOWED = ['prototype', 'design', 'brand'];
const TYPES = {
  '.html': 'text/html; charset=utf-8', '.css': 'text/css; charset=utf-8', '.js': 'text/javascript; charset=utf-8',
  '.mjs': 'text/javascript; charset=utf-8', '.json': 'application/json; charset=utf-8', '.svg': 'image/svg+xml',
  '.png': 'image/png', '.jpg': 'image/jpeg', '.webp': 'image/webp', '.woff2': 'font/woff2', '.woff': 'font/woff',
  '.ttf': 'font/ttf', '.lottie': 'application/zip', '.ico': 'image/x-icon', '.pdf': 'application/pdf'
};

const server = http.createServer((req, res) => {
  let urlPath = decodeURIComponent(new URL(req.url, 'http://x').pathname);
  // Redirect short paths so relative asset URLs resolve under /prototype/
  const short = { '/': '/prototype/', '/prototype': '/prototype/', '/admin': '/prototype/admin.html', '/app': '/prototype/app.html' };
  if (short[urlPath]) { res.writeHead(302, { Location: short[urlPath] }).end(); return; }
  const file = path.normalize(path.join(ROOT, urlPath));
  const top = path.relative(ROOT, file).split(path.sep)[0];
  if (!file.startsWith(ROOT) || !ALLOWED.includes(top)) { res.writeHead(404).end('Not found'); return; }
  let target = file;
  if (fs.existsSync(target) && fs.statSync(target).isDirectory()) target = path.join(target, 'index.html');
  fs.readFile(target, (err, data) => {
    if (err) { res.writeHead(404, { 'Content-Type': 'text/plain' }).end('Not found'); return; }
    res.writeHead(200, {
      'Content-Type': TYPES[path.extname(target).toLowerCase()] || 'application/octet-stream',
      'Cache-Control': 'no-cache'
    });
    res.end(data);
  });
});

server.listen(PORT, '0.0.0.0', () => {
  const lan = Object.values(os.networkInterfaces()).flat()
    .filter(i => i && i.family === 'IPv4' && !i.internal && !i.address.startsWith('169.254'))
    .map(i => i.address);
  console.log(`SolutionTee prototype running`);
  console.log(`  Laptop: http://localhost:${PORT}/`);
  for (const ip of lan) console.log(`  Phone:  http://${ip}:${PORT}/   (same Wi-Fi)`);
  console.log(`Press Ctrl+C to stop.`);
});
