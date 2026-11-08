import fs from "node:fs";
import path from "node:path";
import Link from "next/link";
import { Marked } from "marked";
import { applyCashBlocks, cashState } from "@/lib/site";

/**
 * A published legal page from content/legal/<name>.md (our own text, D-118). Paragraphs marked `<!-- if cash=… -->`
 * follow the admin's cash prize switches (off / 18+ / 13+ with parent email), D-122.
 */
export async function LegalPage({ name }: { name: "privacy" | "terms" | "refunds" }) {
  const raw = fs.readFileSync(path.join(process.cwd(), "content", "legal", `${name}.md`), "utf8");
  const md = applyCashBlocks(raw, await cashState());
  const html = new Marked({ gfm: true }).parse(md, { async: false }) as string;
  return (
    <div className="min-h-dvh bg-background">
      <header className="border-b bg-[#06132B] text-white">
        <div className="mx-auto flex h-16 max-w-3xl items-center justify-between px-4 sm:px-6">
          <Link href="/" className="flex items-center gap-2.5" aria-label="SolutionTee CBT home">
            {/* Real brand mark from /brand (never redrawn) */}
            {/* eslint-disable-next-line @next/next/no-img-element */}
            <img src="/brand/favicon.svg" alt="" className="size-8 rounded-lg" />
            <span className="font-bold">SolutionTee <span className="text-[#F2B233]">CBT</span></span>
          </Link>
          <nav className="flex gap-4 text-sm text-[#C9D5EA]">
            <Link href="/privacy" className="hover:text-white">Privacy</Link>
            <Link href="/terms" className="hover:text-white">Terms</Link>
            <Link href="/refunds" className="hover:text-white">Refunds</Link>
          </nav>
        </div>
      </header>
      <main className="mx-auto max-w-3xl px-4 py-10 sm:px-6">
        <article className="legal" dangerouslySetInnerHTML={{ __html: html }} />
        <p className="mt-12 border-t pt-6 text-xs leading-5 text-muted-foreground">
          SolutionTee CBT is an independent exam-practice platform and is not affiliated with or endorsed by JAMB, WAEC or NECO.
          {" "}<Link href="/delete-account" className="underline">Delete your account</Link>
        </p>
      </main>
    </div>
  );
}
