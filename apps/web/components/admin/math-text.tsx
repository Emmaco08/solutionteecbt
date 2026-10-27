import { renderMath } from "@/lib/math";
import { cn } from "@/lib/utils";

/** Shows question text with LaTeX. Safe: text is escaped, only KaTeX output is HTML. */
export function MathText({ text, className }: { text: string; className?: string }) {
  return <span className={cn("math-text", className)} dangerouslySetInnerHTML={{ __html: renderMath(text) }} />;
}
