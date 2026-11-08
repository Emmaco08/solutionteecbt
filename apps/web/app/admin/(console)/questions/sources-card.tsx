"use client";
import { useState, useTransition } from "react";
import { toast } from "sonner";
import { Books, Sparkle } from "@phosphor-icons/react";
import { Button } from "@/components/ui/button";
import { setPastQuestions } from "./actions";

export type SourceCounts = { past: number; mock: number; paused: number; own_challenge: number; on: boolean };

/**
 * Lawyer's list (D-120): "Past Questions" (official papers, owned by JAMB/WAEC/NECO) and "SolutionTee Mock Questions"
 * (our own) are labelled in the app. If a licence is refused, a super admin hides all past questions here at once.
 */
export function SourcesCard({ c, superAdmin }: { c: SourceCounts; superAdmin: boolean }) {
  const [pending, start] = useTransition();
  const [on, setOn] = useState(c.on);
  function flip() {
    const next = !on;
    const msg = next
      ? "Show all past questions to students again?"
      : "Hide ALL past questions from students now? Tests, Study and the daily question will only use SolutionTee Mock questions. You can turn them back on here.";
    if (!window.confirm(msg)) return;
    start(async () => {
      const r = await setPastQuestions(next);
      if (!r.ok) return void toast.error(r.error);
      setOn(next);
      toast.success(next ? `${(r.data ?? 0).toLocaleString()} past questions are back.` : `${(r.data ?? 0).toLocaleString()} past questions hidden.`);
    });
  }
  return (
    <section className="mb-4 grid gap-4 rounded-2xl border bg-card p-5 md:grid-cols-[1fr_auto] md:items-center">
      <div className="space-y-2 text-sm">
        <div className="flex flex-wrap gap-2">
          <span className="inline-flex items-center gap-1.5 rounded-full bg-secondary/10 px-3 py-1 font-bold text-secondary">
            <Books size={16} weight="fill" /> Past Questions: {c.past.toLocaleString()}{c.paused ? ` (${c.paused.toLocaleString()} hidden)` : ""}
          </span>
          <span className="inline-flex items-center gap-1.5 rounded-full bg-accent px-3 py-1 font-bold text-primary">
            <Sparkle size={16} weight="fill" /> SolutionTee Mock: {c.mock.toLocaleString()} in the bank · {c.own_challenge.toLocaleString()} in challenges
          </span>
        </div>
        <p className="text-muted-foreground">
          Students see one of these labels on every question. Past questions belong to the exam bodies; mock questions are your own, written
          from scratch. Set the kind on each question, or add a <code>source</code> column (past / mock) to your CSV.
        </p>
      </div>
      {superAdmin ? (
        <Button variant={on ? "outline" : "default"} onClick={flip} disabled={pending}>
          {pending ? "Saving…" : on ? "Hide all past questions" : "Show past questions again"}
        </Button>
      ) : null}
    </section>
  );
}
