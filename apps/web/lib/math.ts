import katex from "katex";

const escapeHtml = (s: string) =>
  s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;").replace(/'/g, "&#39;");

/**
 * Turns text with $...$ (inline) and $$...$$ (display) maths into safe HTML.
 * Plain text is escaped (never trusted as HTML); a formula that fails shows as highlighted source instead of breaking.
 */
export function renderMath(text: string): string {
  if (!text) return "";
  const out: string[] = [];
  const re = /(\$\$[\s\S]+?\$\$|(?<!\\)\$[^$\n]+?(?<!\\)\$)/g;
  let last = 0;
  for (const m of text.matchAll(re)) {
    const i = m.index ?? 0;
    out.push(escapeHtml(text.slice(last, i)).replace(/\\\$/g, "$").replace(/\n/g, "<br>"));
    const raw = m[0];
    const display = raw.startsWith("$$");
    const tex = raw.slice(display ? 2 : 1, display ? -2 : -1);
    try {
      out.push(katex.renderToString(tex, { displayMode: display, throwOnError: true, strict: "ignore", trust: false }));
    } catch {
      out.push(`<code class="math-error" title="This formula has a mistake">${escapeHtml(raw)}</code>`);
    }
    last = i + raw.length;
  }
  out.push(escapeHtml(text.slice(last)).replace(/\\\$/g, "$").replace(/\n/g, "<br>"));
  return out.join("");
}
