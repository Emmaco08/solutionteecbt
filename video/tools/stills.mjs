// Render stills at given seconds into out/stills (review aid). Usage: node tools/stills.mjs 1.2 2.4 ...
import { bundle } from "@remotion/bundler";
import { renderStill, selectComposition } from "@remotion/renderer";
import path from "node:path";

const secs = process.argv.slice(2).map(Number);
const serveUrl = await bundle({ entryPoint: path.resolve("src/index.ts") });
const browserExecutable = process.env.REMOTION_CHROME ?? "/opt/pw-browsers/chromium_headless_shell-1243/chrome-headless-shell-linux64/chrome-headless-shell";
const composition = await selectComposition({ serveUrl, id: process.env.COMP ?? "Intro916", browserExecutable });
for (const s of secs) {
  const frame = Math.min(composition.durationInFrames - 1, Math.round(s * 30));
  await renderStill({ composition, serveUrl, frame, output: `out/stills/${String(s).padStart(5, "0")}.jpg`, imageFormat: "jpeg", jpegQuality: 85, scale: 0.5, browserExecutable });
  process.stdout.write(`${s} `);
}
console.log("done");
