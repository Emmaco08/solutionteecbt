import { Marked } from "marked";
import katex from "katex";

const escapeHtml = (s: string) =>
  s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;").replace(/'/g, "&#39;");

// $$…$$ and $…$ are taken out before Markdown runs (so _ and * inside formulas are not read as italics/bold),
// then put back as KaTeX HTML. Same rule as the app (apps/mobile/lib/widgets/note_markdown.dart).
const MATH = /(\$\$[\s\S]+?\$\$|(?<!\\)\$[^$\n]+?(?<!\\)\$)/g;
const TOKEN = (i: number) => `@@MATH${i}@@`;

/**
 * Lesson-note Markdown → safe HTML for the admin preview. Raw HTML in the text is shown as text, never run.
 * `imageUrl` turns a stored key (n/…) into a link the browser can load.
 */
export function renderMarkdown(text: string, imageUrl: (key: string) => string): string {
  if (!text) return "";
  const maths: string[] = [];
  // AI models often write \[ … \] and \( … \) instead of $$ … $$ and $ … $; both are accepted (same as the app).
  const normal = text
    .replace(/(?<!\\)\\\[([\s\S]+?)(?<!\\)\\\]/g, (_, m: string) => "$$" + m + "$$")
    .replace(/(?<!\\)\\\(([\s\S]+?)(?<!\\)\\\)/g, (_, m: string) => "$" + m.trim() + "$");
  const src = normal.replace(MATH, (raw) => {
    const display = raw.startsWith("$$");
    const tex = raw.slice(display ? 2 : 1, display ? -2 : -1);
    let html: string;
    try {
      html = katex.renderToString(tex, { displayMode: display, throwOnError: true, strict: "ignore", trust: false });
    } catch {
      html = `<code class="math-error" title="This formula has a mistake">${escapeHtml(raw)}</code>`;
    }
    maths.push(html);
    return TOKEN(maths.length - 1);
  });

  const md = new Marked({ gfm: true, breaks: true });
  md.use({
    renderer: {
      html: ({ text: t }) => escapeHtml(t),
      image: ({ href, text: alt }) => {
        const url = /^n\//.test(href) ? imageUrl(href) : /^https:\/\//.test(href) ? href : "";
        return url ? `<img src="${escapeHtml(url)}" alt="${escapeHtml(alt)}" loading="lazy" />` : `<span class="text-error">[picture not found: ${escapeHtml(href)}]</span>`;
      },
      link: ({ href, text: t }) => (/^https?:\/\//.test(href) ? `<a href="${escapeHtml(href)}" target="_blank" rel="noreferrer">${escapeHtml(t)}</a>` : escapeHtml(t)),
    },
  });
  const html = md.parse(src, { async: false }) as string;
  return html.replace(/@@MATH(\d+)@@/g, (_, i) => maths[Number(i)] ?? "");
}
