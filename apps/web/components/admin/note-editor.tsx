"use client";
import { useMemo, useRef, useState } from "react";
import { ImageSquare, ListBullets, ListNumbers, Quotes, Sigma, SpinnerGap, Table, TextB, TextHOne, TextHTwo, TextItalic } from "@phosphor-icons/react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import { renderMarkdown } from "@/lib/markdown";

type Tool = "h2" | "h3" | "b" | "i" | "ul" | "ol" | "tip" | "table" | "math";
const TOOLS: [Tool, string, typeof TextB][] = [
  ["h2", "Heading", TextHOne], ["h3", "Small heading", TextHTwo], ["b", "Bold", TextB], ["i", "Italic", TextItalic],
  ["ul", "List", ListBullets], ["ol", "Numbered list", ListNumbers], ["tip", "Exam tip box", Quotes], ["table", "Table", Table], ["math", "Formula", Sigma],
];

const imageUrl = (key: string) => `/admin/api/image?key=${encodeURIComponent(key)}`;

/**
 * Markdown editor for lesson notes: toolbar, picture upload (stored privately under n/… and shown to students
 * only through a signed link), and a live preview that looks like the app. Value is posted as `name`.
 */
export function NoteEditor({ name, defaultValue, rows = 18 }: { name: string; defaultValue?: string | null; rows?: number }) {
  const [text, setText] = useState(defaultValue ?? "");
  const [tab, setTab] = useState<"write" | "preview" | "both">("both");
  const [busy, setBusy] = useState(false);
  const area = useRef<HTMLTextAreaElement>(null);
  const file = useRef<HTMLInputElement>(null);
  const html = useMemo(() => renderMarkdown(text, imageUrl), [text]);

  /** Wraps the selection (or inserts at the cursor) and keeps focus in the box. */
  function edit(before: string, after = "", placeholder = "") {
    const el = area.current;
    if (!el) return;
    const { selectionStart: s, selectionEnd: e } = el;
    const sel = text.slice(s, e) || placeholder;
    const next = text.slice(0, s) + before + sel + after + text.slice(e);
    setText(next);
    requestAnimationFrame(() => {
      el.focus();
      el.setSelectionRange(s + before.length, s + before.length + sel.length);
    });
  }
  /** Starts a block on a new line. */
  const block = (prefix: string, placeholder: string) => {
    const el = area.current;
    const atLineStart = !el || el.selectionStart === 0 || text[el.selectionStart - 1] === "\n";
    edit(`${atLineStart ? "" : "\n\n"}${prefix}`, "", placeholder);
  };

  async function upload(f: File) {
    setBusy(true);
    try {
      const r = await fetch("/admin/api/upload", { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify({ kind: "note_image", contentType: f.type, size: f.size }) });
      const j = await r.json();
      if (!r.ok) throw new Error(j.error ?? "Upload failed");
      const put = await fetch(j.url, { method: "PUT", headers: { "content-type": f.type }, body: f });
      if (!put.ok) throw new Error("Upload to storage failed. Check the R2 CORS settings (SETUP §10.1).");
      block(`![${f.name.replace(/\.[a-z]+$/i, "").replace(/[[\]]/g, "")}](${j.key})\n\n`, "");
      toast.success("Picture added to the note.");
    } catch (e) {
      toast.error(e instanceof Error ? e.message : "Upload failed");
    } finally {
      setBusy(false);
    }
  }

  function apply(tool: Tool) {
    switch (tool) {
      case "h2": return block("## ", "Heading");
      case "h3": return block("### ", "Small heading");
      case "b": return edit("**", "**", "bold text");
      case "i": return edit("*", "*", "italic text");
      case "ul": return block("- ", "Item");
      case "ol": return block("1. ", "First step");
      case "tip": return block("> **Exam tip.** ", "Write the tip here.");
      case "table": return block("| Column 1 | Column 2 |\n| --- | --- |\n| ", " | |\n");
      case "math": return edit("$", "$", "x^2 + 1");
    }
  }

  return (
    <div className="overflow-hidden rounded-xl border">
      <input type="hidden" name={name} value={text} />
      <input ref={file} type="file" accept="image/webp,image/png,image/jpeg,image/svg+xml" className="hidden"
        onChange={(e) => { const f = e.target.files?.[0]; if (f) upload(f); e.target.value = ""; }} />
      <div className="flex flex-wrap items-center gap-1 border-b bg-surface-alt px-2 py-1.5">
        {TOOLS.map(([tool, label, Icon]) => (
          <button key={tool} type="button" title={label} aria-label={label} onClick={() => apply(tool)}
            className="grid size-9 place-items-center rounded-lg text-muted-foreground hover:bg-card hover:text-foreground"><Icon size={18} /></button>
        ))}
        <Button type="button" variant="ghost" size="sm" disabled={busy} onClick={() => file.current?.click()}>
          {busy ? <SpinnerGap size={16} className="animate-spin" /> : <ImageSquare size={16} />} Picture
        </Button>
        <span className="grow" />
        {(["write", "both", "preview"] as const).map((t) => (
          <button key={t} type="button" onClick={() => setTab(t)}
            className={`h-8 rounded-lg px-2.5 text-xs font-bold ${tab === t ? "bg-primary text-primary-foreground" : "text-muted-foreground hover:bg-card"}`}>
            {t === "write" ? "Write" : t === "both" ? "Side by side" : "Preview"}
          </button>
        ))}
      </div>
      <div className={tab === "both" ? "grid lg:grid-cols-2" : ""}>
        {tab !== "preview" ? (
          <textarea ref={area} id={name} value={text} onChange={(e) => setText(e.target.value)} rows={rows} spellCheck
            className="block w-full resize-y border-0 bg-card px-3 py-2.5 font-mono text-[13px] leading-6 outline-none" />
        ) : null}
        {tab !== "write" ? (
          <div className={`note-preview max-h-[640px] overflow-auto bg-card px-4 py-3 ${tab === "both" ? "border-t lg:border-l lg:border-t-0" : ""}`}>
            {text ? <div dangerouslySetInnerHTML={{ __html: html }} /> : <p className="text-sm text-muted-foreground">The note shows here as students will see it.</p>}
          </div>
        ) : null}
      </div>
      <p className="border-t bg-surface-alt px-3 py-2 text-xs text-muted-foreground">
        Markdown: <code>## Heading</code>, <code>**bold**</code>, <code>- list</code>, <code>1. steps</code>, <code>&gt; tip</code>, tables, <code>$x^2$</code> and <code>$$…$$</code> for maths. Pictures: use the Picture button (max 2 MB, WebP is smallest).
      </p>
    </div>
  );
}
